/**
 * Screenshots the demo at key timestamps so you can eyeball the design
 * without scrubbing the video.  ->  out/frames/NNs.png
 *
 *   node preview.mjs
 */
import { chromium } from 'playwright';
import { mkdir, rm } from 'node:fs/promises';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
/** Login → Home → Practice → Progress → Play → Club → Profile → end */
const SHOTS = [2, 6, 10, 16, 24, 32, 36, 40, 42, 46, 54, 60, 68, 74, 80];

const browser = await chromium.launch({
  args: ['--disable-background-timer-throttling', '--disable-renderer-backgrounding'],
});
const page = await browser.newPage({
  viewport: { width: 430, height: 932 },
  deviceScaleFactor: 2,
});

await page.goto(pathToFileURL(path.join(here, 'index.html')).href + '?manual=1');
await page.waitForTimeout(1500);

const dir = path.join(here, 'out', 'frames');
await rm(dir, { recursive: true, force: true });
await mkdir(dir, { recursive: true });

await page.evaluate('window.__start()');
const t0 = Date.now();
for (const s of SHOTS) {
  const wait = s * 1000 - (Date.now() - t0);
  if (wait > 0) await page.waitForTimeout(wait);
  await page.screenshot({ path: path.join(dir, `${String(s).padStart(2, '0')}s.png`) });
  console.log(`captured ${s}s`);
}

await browser.close();
console.log('\nFrames in ' + dir);
