#!/usr/bin/env python3
"""Build a Forma motion-graphics ad reel from a scene script.

    python3 build.py scripts/01_quit_every_app.json            # full render -> renders/
    python3 build.py scripts/01_quit_every_app.json --stills   # a few PNG frames to check layout
    python3 build.py scripts/01_quit_every_app.json --voice-file my_voice.wav --cues 0,2.1,4.8,...

The presenter is voiced with Kokoro TTS (set KOKORO_DIR to the folder holding kokoro.onnx and
voices.bin). To use your own recorded voice instead, pass --voice-file plus --cues: the start time
(seconds) of each scene's line in your recording.
"""
import argparse, json, os, re, subprocess, sys, tempfile
import numpy as np
import soundfile as sf

FPS, SR = 30, 24000
HERE = os.path.dirname(os.path.abspath(__file__))


def parse_words(text):
    """'I quit *every single* one' -> [{'text','cls'}]; *x* = serif accent, [x] = highlight."""
    out, cls = [], None
    for tok in re.findall(r"\*|\[|\]|[^\s*\[\]]+", text):
        if tok == "*":
            cls = None if cls == "acc" else "acc"
        elif tok == "[":
            cls = "hi"
        elif tok == "]":
            cls = None
        else:
            out.append({"text": tok, "cls": cls})
    # glue punctuation-only tokens onto the previous word
    merged = []
    for w in out:
        if merged and re.fullmatch(r"[.,!?;:…'\"]+", w["text"]):
            merged[-1]["text"] += w["text"]
        else:
            merged.append(w)
    return merged


def plain(text):
    return re.sub(r"[*\[\]]", "", text)


def trim(audio, thr=0.01):
    idx = np.where(np.abs(audio) > thr)[0]
    if not len(idx):
        return audio
    return audio[max(0, idx[0] - int(.02 * SR)): idx[-1] + int(.06 * SR)]


def word_times(words, start, length, audio=None):
    """Spread words over the clip. Sentence/comma breaks are snapped to real pauses in the audio."""
    def wt(w):
        return len(re.sub(r"\W", "", w["text"])) + 2

    segs, cur = [], []
    for w in words:
        cur.append(w)
        if re.search(r"[.!?…,;:]$", w["text"]):
            segs.append(cur); cur = []
    if cur:
        segs.append(cur)
    tot = sum(wt(w) for w in words)
    est, acc = [], 0.0
    for seg in segs[:-1]:
        acc += sum(wt(w) for w in seg)
        est.append(length * acc / tot)
    cuts = [(e, e) for e in est]  # (end of previous segment, start of next)
    if audio is not None and est:
        hop = SR // 100
        env = np.array([np.sqrt(np.mean(audio[i:i + hop] ** 2)) for i in range(0, len(audio) - hop, hop)])
        quiet = env < max(.008, env.max() * .06)
        gaps, i = [], 0
        while i < len(quiet):
            j = i
            while j < len(quiet) and quiet[j]:
                j += 1
            if j - i >= 4 and i > 3:
                gaps.append((i / 100, j / 100))
            i = max(j, i + 1)
        for k, e in enumerate(est):
            near = [g for g in gaps if abs((g[0] + g[1]) / 2 - e) < .45]
            if near:
                g = max(near, key=lambda g: (g[1] - g[0]) - abs((g[0] + g[1]) / 2 - e) * .3)
                cuts[k] = g
    edges = [0.0] + [c for pair in cuts for c in pair] + [length]
    seg_spans = [(edges[2 * k], edges[2 * k + 1] - edges[2 * k]) for k in range(len(segs))]
    for seg, (s0, d) in zip(segs, seg_spans):
        tot, t = sum(wt(w) for w in seg), s0
        for w in seg:
            w["t"] = round(start + t, 3)
            t += d * wt(w) / tot


def mouth_curve(audio, n_frames):
    hop = SR // FPS
    env = np.array([np.sqrt(np.mean(audio[i * hop:(i + 1) * hop] ** 2)) if i * hop < len(audio) else 0 for i in range(n_frames)])
    if env.max() > 0:
        env = env / np.percentile(env[env > 0], 95)
    env = np.clip((env - .08) * 1.25, 0, 1)
    # quick attack, slower release so the mouth doesn't flicker
    out, v = [], 0.0
    for x in env:
        v = x if x > v else v * .55 + x * .45
        out.append(round(float(v), 3))
    return out


def tts(scenes, voice, speed):
    from kokoro_onnx import Kokoro
    d = os.environ.get("KOKORO_DIR", os.path.join(HERE, ".kokoro"))
    k = Kokoro(os.path.join(d, "kokoro.onnx"), os.path.join(d, "voices.bin"))
    clips = []
    for s in scenes:
        a, sr = k.create(plain(s["say"]), voice=s.get("voice", voice), speed=s.get("speed", speed), lang="en-us")
        assert sr == SR
        clips.append(trim(np.asarray(a, dtype=np.float32)))
    return clips


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("script")
    ap.add_argument("--out")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--voice-file")
    ap.add_argument("--cues", help="comma separated scene start times in --voice-file")
    ap.add_argument("--music", help="optional music bed, mixed quietly")
    a = ap.parse_args()

    spec = json.load(open(a.script))
    name = os.path.splitext(os.path.basename(a.script))[0]
    out = a.out or os.path.join(HERE, "renders", name + ".mp4")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scenes = spec["scenes"]
    gap, tail = spec.get("gap", .12), spec.get("tail", 1.6)

    if a.voice_file:
        voice, sr = sf.read(a.voice_file, dtype="float32", always_2d=True)
        voice = voice.mean(axis=1)
        if sr != SR:
            sys.exit(f"resample {a.voice_file} to {SR} Hz first (ffmpeg -i in -ar {SR} -ac 1 out.wav)")
        cues = [float(x) for x in a.cues.split(",")]
        assert len(cues) == len(scenes), "need one cue per scene"
        bounds = cues + [len(voice) / SR]
        spans = [(bounds[i], bounds[i + 1] - bounds[i] - gap) for i in range(len(scenes))]
        total = len(voice) / SR + tail
    else:
        clips = tts(scenes, spec.get("voice", "af_heart"), spec.get("speed", 1.05))
        parts, spans, t = [], [], .25
        parts.append(np.zeros(int(.25 * SR), np.float32))
        for c, s in zip(clips, scenes):
            spans.append((t, len(c) / SR))
            pause = s.get("pause", gap)
            parts += [c, np.zeros(int(pause * SR), np.float32)]
            t += len(c) / SR + pause
        parts.append(np.zeros(int(tail * SR), np.float32))
        voice = np.concatenate(parts)
        total = len(voice) / SR

    tl_scenes, visuals = [], []
    for i, (s, (st, ln)) in enumerate(zip(scenes, spans)):
        start = 0 if i == 0 else st - .05
        end = spans[i + 1][0] - .05 if i + 1 < len(scenes) else total
        words = parse_words(s.get("show", s["say"]))
        word_times(words, st, ln, clips[i] if not a.voice_file else voice[int(st * SR):int((st + ln) * SR)])
        tl_scenes.append({"start": start, "end": end, "label": s.get("label", ""), "theme": s.get("theme", "light"),
                          "mood": s.get("mood", "neutral"), "counter": s.get("counter"), "words": words})
        v = s.get("visual")
        if v == "same" and visuals:
            visuals[-1]["end"] = end
        elif v:
            visuals.append({**v, "start": start, "end": end})

    n_frames = int(np.ceil(total * FPS))
    timeline = {"fps": FPS, "duration": total, "scenes": tl_scenes, "visuals": visuals,
                "mouth": mouth_curve(voice, n_frames), "avatarIntro": True}

    tmp = tempfile.mkdtemp()
    tl_path, wav = os.path.join(tmp, "timeline.json"), os.path.join(tmp, "voice.wav")
    json.dump(timeline, open(tl_path, "w"))
    sf.write(wav, voice, SR)
    mixed = os.path.join(tmp, "mix.wav")
    if a.music:
        mix = (["-i", wav, "-stream_loop", "-1", "-i", a.music, "-filter_complex",
                f"[1:a]volume=0.10,afade=t=out:st={total - 1.2}:d=1.2[m];[0:a][m]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5"])
    else:
        mix = ["-i", wav, "-af", "loudnorm=I=-14:TP=-1.5"]
    subprocess.run(["ffmpeg", "-y", "-v", "error", *mix, "-ar", "48000", mixed], check=True)
    wav = mixed

    node = ["node", os.path.join(HERE, "render.mjs"), tl_path, wav]
    if a.stills:
        times = [s["start"] + (s["end"] - s["start"]) * .8 for s in tl_scenes]
        png = os.path.join(HERE, "renders", "stills", name + ".png")
        os.makedirs(os.path.dirname(png), exist_ok=True)
        subprocess.run(node + [png, "--still", ",".join(f"{x:.2f}" for x in times)], check=True)
        print(f"stills -> {os.path.dirname(png)}")
    else:
        subprocess.run(node + [out], check=True)
        print(f"{out}  ({total:.1f}s)")


if __name__ == "__main__":
    main()
