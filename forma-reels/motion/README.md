# Forma motion reels

Explainer-style ad reels in the format of the reference: a cartoon presenter talks at the
bottom, the line being spoken appears word by word up top (red serif for accents, lime
highlights on the dark outro), mono section labels with a live counter, and animated Forma UI
cards for each beat (app screen, streak, heatmap, widget, stats, reminders, end card).

```
./setup.sh                                    # once (needs ffmpeg + Chromium)
python3 build.py scripts/01_quit_every_app.json          # -> renders/01_quit_every_app.mp4
python3 build.py scripts/01_quit_every_app.json --stills # quick PNG check of every scene
python3 build.py scripts/01_quit_every_app.json --music bed.mp3
```

## Writing a script
Each scene in `scripts/*.json` is one spoken line:

| key | what it does |
|---|---|
| `say` | the line the presenter speaks. `*word*` = red serif accent, `[word]` = highlight |
| `show` | optional on-screen version if it differs (e.g. `day 43` vs spoken `day forty-three`) |
| `label` | top-left section tag, e.g. `// 02 — the problem` |
| `counter` | top-right stat: `{"name": "streak", "from": 0, "to": 43}` or a fixed `"to": "2s"` |
| `visual` | `apps`, `phone`, `streak`, `heatmap`, `widget`, `stats`, `calendar`, `clock`, `checklist`, `sticker`, `notify`, `chain`, `add`, `privacy`, `compare`, `shot`, `cta`, or `"same"` to keep the previous one |
| `mood` | presenter face: `neutral`, `happy`, `excited`, `smug`, `serious`, `worried` |
| `theme` | `"dark"` for the neon outro section |

Voice: Kokoro TTS, `"voice": "af_heart"` (try `af_bella`, `am_michael`, `am_puck`, `bf_emma`) and `"speed"`.
To use your own recording instead: `--voice-file me.wav --cues 0,2.4,5.1,...` (one start time per
scene, 24 kHz mono).

Brand bits to swap in `page.html`: `LOGO` (the app icon), `--accent` colour, and the presenter
colours (`SKIN`, `HAIR`, `HOOD`).

## Using real app screenshots
Drop PNGs into `assets/screens/` and use the `shot` visual in place of the drawn `phone`:
`"visual": {"type": "shot", "src": "today.png", "zoom": 1.08, "focus": "50% 30%"}`.
It shows the screenshot in a phone frame, sliding in with a slow push-in toward `focus`.
