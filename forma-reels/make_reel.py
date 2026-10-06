#!/usr/bin/env python3
"""Turn a selfie / talking-head clip into a finished Forma ad reel (1080x1920).

Adds: a hook banner for the first seconds, bold word-chunk captions synced to the
script, and a branded CTA end card. Without a clip it renders a placeholder preview
so you can check pacing and text before filming.

    python3 make_reel.py ads/01_failed_every_habit.json                 # preview
    python3 make_reel.py ads/01_failed_every_habit.json --clip me.mp4   # real ad

Caption timing is spread across the clip by word count, so read the script at a
steady pace with no long gaps at the start/end (trim those first). For exact
timing, give a line a "t": [start, end] in seconds (see README).
"""
import argparse, json, os, re, subprocess, sys, tempfile

W, H, FPS = 1080, 1920, 30
END_CARD = 2.5
WORDS_PER_SEC = 2.7
FONT = "Inter Display"
ACCENT = "&H0035C2FF"  # ASS is &HAABBGGRR -> #FFC235 amber highlight


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"ffmpeg failed:\n{r.stderr[-2000:]}")
    return r.stdout


def duration(path):
    return float(sh(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                     "-of", "csv=p=0", path]).strip())


def ts(t):
    cs = int(round(t * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def esc(s):
    return s.replace("\\", "\\\\").replace("{", "(").replace("}", ")").replace("\n", "\\N")


def chunks(line, n=3):
    words = line.split()
    out, cur = [], []
    for w in words:
        cur.append(w)
        if len(cur) == n or re.search(r"[.,!?:;]$", w):
            out.append(cur); cur = []
    if cur:
        out.append(cur)
    return out


def weight(words):
    # pauses after punctuation read longer than the word count suggests
    return len(words) + sum(0.6 for w in words if re.search(r"[.!?]$", w)) + \
        sum(0.3 for w in words if re.search(r"[,:;]$", w))


def build_events(lines, talk_len):
    events = []
    fixed = [l for l in lines if isinstance(l, dict) and "t" in l]
    if fixed and len(fixed) != len(lines):
        sys.exit('Give every line a "t", or none of them.')
    if fixed:
        spans = [(l["t"][0], l["t"][1], l["text"]) for l in lines]
    else:
        texts = [l["text"] if isinstance(l, dict) else l for l in lines]
        total = sum(weight(w) for t in texts for w in chunks(t))
        spans, t = [], 0.0
        for text in texts:
            d = talk_len * sum(weight(c) for c in chunks(text)) / total
            spans.append((t, t + d, text)); t += d
    for start, end, text in spans:
        cs = chunks(text)
        tot = sum(weight(c) for c in cs)
        t = start
        for c in cs:
            d = (end - start) * weight(c) / tot
            # emphasise the longest word in each chunk, TikTok-caption style
            key = max(range(len(c)), key=lambda i: len(re.sub(r"\W", "", c[i])))
            txt = " ".join(
                f"{{\\c{ACCENT}}}{esc(w.upper())}{{\\c&H00FFFFFF}}" if i == key and len(c) > 1 else esc(w.upper())
                for i, w in enumerate(c))
            pop = "{\\fscx80\\fscy80\\t(0,90,\\fscx100\\fscy100)}"
            events.append(f"Dialogue: 1,{ts(t)},{ts(t + d)},Cap,,0,0,0,,{pop}{txt}")
            t += d
    return events


def write_ass(path, ad, talk_len):
    hook_end = min(3.2, talk_len)
    total = talk_len + END_CARD
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,{FONT},86,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,7,3,2,80,80,560,1
Style: Hook,{FONT},68,&H00111111,&H00111111,&H00FFFFFF,&H00FFFFFF,-1,0,0,0,100,100,0,0,3,22,0,8,90,90,300,1
Style: CTA,{FONT},96,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,0,0,5,90,90,0,1
Style: Brand,{FONT},150,{ACCENT},{ACCENT},&H00000000,&H00000000,-1,0,0,0,100,100,-2,0,1,0,0,5,90,90,0,1
Style: Small,{FONT},44,&H00B0B0B0,&H00B0B0B0,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,5,90,90,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    ev = [f"Dialogue: 2,{ts(0)},{ts(hook_end)},Hook,,0,0,0,,"
          f"{{\\fad(0,200)\\fscx90\\fscy90\\t(0,120,\\fscx100\\fscy100)}}{esc(ad['hook'])}"]
    ev += build_events(ad["lines"], talk_len)
    e0 = ts(talk_len)
    ev += [f"Dialogue: 2,{e0},{ts(total)},Brand,,0,0,0,,{{\\pos({W//2},{H//2 - 260})\\fad(200,0)}}Forma",
           f"Dialogue: 2,{e0},{ts(total)},CTA,,0,0,0,,{{\\pos({W//2},{H//2 + 20})\\fad(300,0)}}{esc(ad['cta'])}",
           f"Dialogue: 2,{e0},{ts(total)},Small,,0,0,0,,{{\\pos({W//2},{H//2 + 300})\\fad(500,0)}}link in bio"]
    with open(path, "w") as f:
        f.write(head + "\n".join(ev) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("script")
    ap.add_argument("--clip", help="your talking-head video (any aspect; center-cropped to 9:16)")
    ap.add_argument("--out")
    ap.add_argument("--music", help="optional background track, mixed quietly under your voice")
    a = ap.parse_args()

    ad = json.load(open(a.script))
    name = os.path.splitext(os.path.basename(a.script))[0]
    here = os.path.dirname(os.path.abspath(__file__))
    out = a.out or os.path.join(here, "renders", f"{name}{'' if a.clip else '_preview'}.mp4")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = tempfile.mkdtemp()

    fit = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},fps={FPS},setsar=1,format=yuv420p"
    talk = os.path.join(tmp, "talk.mp4")
    if a.clip:
        sh(["ffmpeg", "-y", "-i", a.clip, "-vf", fit, "-af", "loudnorm=I=-14:TP=-1.5,aresample=48000",
            "-ac", "2", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-c:a", "aac", talk])
    else:
        words = sum(len((l["text"] if isinstance(l, dict) else l).split()) for l in ad["lines"])
        d = words / WORDS_PER_SEC + 0.2 * len(ad["lines"])
        ph = (f"gradients=s={W}x{H}:c0=0x2a2f45:c1=0x15171f:x0=0:y0=0:x1={W}:y1={H}:d={d}:r={FPS},"
              f"drawtext=font='{FONT}':text='your talking-head clip goes here':fontsize=40:"
              f"fontcolor=white@0.35:x=(w-tw)/2:y=h*0.42,{fit}")
        sh(["ffmpeg", "-y", "-f", "lavfi", "-i", ph, "-f", "lavfi", "-i",
            "anullsrc=r=48000:cl=stereo", "-t", f"{d}", "-c:v", "libx264", "-preset", "fast",
            "-c:a", "aac", talk])
    talk_len = duration(talk)

    card = os.path.join(tmp, "card.mp4")
    sh(["ffmpeg", "-y", "-f", "lavfi", "-i", f"color=c=0x111318:s={W}x{H}:r={FPS}:d={END_CARD}",
        "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", f"{END_CARD}",
        "-vf", "format=yuv420p", "-c:v", "libx264", "-preset", "fast", "-c:a", "aac", card])

    ass = os.path.join(tmp, "subs.ass")
    write_ass(ass, ad, talk_len)

    inputs = ["-i", talk, "-i", card]
    fc = f"[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a];[v]ass={ass}[vo]"
    amap = "[a]"
    if a.music:
        inputs += ["-stream_loop", "-1", "-i", a.music]
        fc += (f";[2:a]volume=0.12,afade=t=out:st={talk_len + END_CARD - 1}:d=1[m];"
               f"[a][m]amix=inputs=2:duration=first:normalize=0[am]")
        amap = "[am]"
    sh(["ffmpeg", "-y", *inputs, "-filter_complex", fc, "-map", "[vo]", "-map", amap,
        "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-profile:v", "high",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out])
    print(f"{out}  ({talk_len + END_CARD:.1f}s)")


if __name__ == "__main__":
    main()
