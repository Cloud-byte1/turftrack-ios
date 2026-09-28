/**
 * Records the fairLie demo reel to an MP4 you can drop straight into CapCut.
 *
 *   npm run setup     (once)
 *   npm run record
 *
 * Output: out/fairlie-demo.mp4  — 860x1864, H.264, plus a poster frame.
 */
import { chromium } from 'playwright';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdir, readdir, rm, rename } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';

const run = promisify(execFile);
const here = path.dirname(fileURLToPath(import.meta.url));

/**
 * ffmpeg-static has no Windows-on-ARM64 build, so we use whatever ffmpeg is on
 * PATH (or $env:FFMPEG). Without it we still emit the .webm, which CapCut reads.
 */
async function findFfmpeg() {
  const candidates = [
    process.env.FFMPEG,
    'ffmpeg',
    'C:\\ffmpeg\\bin\\ffmpeg.exe',
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      await run(c, ['-version']);
      return c;
    } catch { /* keep looking */ }
  }
  return null;
}

// Logical iPhone size; 2x gives a crisp 860x1864 capture.
const W = 430, H = 932, DSF = 2;
const OUT = path.join(here, 'out');

async function main() {
  // Unique raw dir per run so a leftover locked webm from a crashed recorder
  // can't block the next capture on Windows.
  const RAW = path.join(OUT, `raw-${Date.now()}`);
  await mkdir(RAW, { recursive: true });
  await mkdir(OUT, { recursive: true });

  // Chromium throttles timers in unfocused pages, which would stretch the
  // scripted timeline; these flags keep it running at real speed.
  const browser = await chromium.launch({
    args: [
      '--force-color-profile=srgb',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
    ],
  });
  const context = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: DSF,
    recordVideo: { dir: RAW, size: { width: W * DSF, height: H * DSF } },
  });
  const page = await context.newPage();

  const url = pathToFileURL(path.join(here, 'index.html')).href + '?manual=1';
  await page.goto(url);

  // Let the webfont land before the first frame so text doesn't reflow on camera.
  await page.waitForTimeout(1500);
  try {
    await page.waitForFunction('document.fonts.status === "loaded"', undefined, { timeout: 5000 });
  } catch {
    console.warn('! Webfont did not load (offline?). Falling back to system font.');
  }

  const duration = await page.evaluate('window.__demoDuration');
  console.log(`Recording ~${Math.round(duration / 1000)}s ...`);

  await page.evaluate('window.__start()');
  await page.waitForFunction('window.__demoDone === true', undefined, { timeout: duration + 30000 });
  await page.waitForTimeout(400);

  await context.close();
  await browser.close();

  const webm = (await readdir(RAW)).find(f => f.endsWith('.webm'));
  if (!webm) throw new Error('Playwright produced no video file.');
  const webmOut = path.join(OUT, 'fairlie-demo.webm');
  try {
    if (existsSync(webmOut)) await rm(webmOut, { force: true });
  } catch { /* locked old file — write beside it */ }
  const dest = existsSync(webmOut)
    ? path.join(OUT, `fairlie-demo-${Date.now()}.webm`)
    : webmOut;
  await rename(path.join(RAW, webm), dest);
  await rm(RAW, { recursive: true, force: true }).catch(() => {});

  const ffmpeg = await findFfmpeg();
  if (!ffmpeg) {
    console.log('\nDone (webm only — no ffmpeg found):');
    console.log('  ' + dest);
    console.log('\nCapCut imports .webm. For an .mp4, install ffmpeg and re-run:');
    console.log('  winget install Gyan.FFmpeg');
    return;
  }

  const mp4 = path.join(OUT, 'fairlie-demo.mp4');
  console.log('Transcoding to H.264 ...');
  await run(ffmpeg, [
    '-y', '-i', dest,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '17',
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    '-r', '30',
    mp4,
  ]);

  const poster = path.join(OUT, 'poster.png');
  await run(ffmpeg, ['-y', '-ss', '00:00:20', '-i', mp4, '-vframes', '1', poster]);

  console.log('\nDone:');
  console.log('  ' + mp4);
  console.log('  ' + poster);
}

main().catch(err => { console.error(err); process.exit(1); });
