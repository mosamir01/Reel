// Renders page.html frame by frame with a given timeline and pipes the frames to ffmpeg.
// usage: node render.mjs timeline.json audio.wav out.mp4 [--frames a-b] [--still t1,t2 out.png]
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const [tlPath, audio, out, ...rest] = process.argv.slice(2);
const tl = JSON.parse(readFileSync(tlPath, 'utf8'));
const here = path.dirname(fileURLToPath(import.meta.url));
const stills = rest[0] === '--still' ? rest[1].split(',').map(Number) : null;

const browser = await chromium.launch(fs_exec());
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.addInitScript(t => { window.TIMELINE = t; }, tl);
await page.goto(pathToFileURL(path.join(here, 'page.html')).href);
await page.evaluate(() => document.fonts.ready);

if (stills) {
  for (const [i, t] of stills.entries()) {
    await page.evaluate(t => window.renderAt(t), t);
    await page.screenshot({ path: out.replace(/\.png$/, `_${i}.png`), type: 'png' });
  }
  await browser.close();
  process.exit(0);
}

const n = Math.ceil(tl.duration * tl.fps);
const ff = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(tl.fps), '-c:v', 'mjpeg', '-i', '-',
  '-i', audio, '-map', '0:v', '-map', '1:a', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
  '-profile:v', 'high', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });

for (let f = 0; f < n; f++) {
  await page.evaluate(t => window.renderAt(t), f / tl.fps);
  const buf = await page.screenshot({ type: 'jpeg', quality: 93 });
  if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
  if (f % 150 === 0) process.stderr.write(`  frame ${f}/${n}\n`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close();

function fs_exec() {
  // use the preinstalled chromium if the bundled one isn't there
  return { executablePath: process.env.CHROMIUM_PATH || undefined };
}
