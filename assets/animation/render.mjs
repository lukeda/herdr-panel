// Steps index.html's renderAt(t) frame by frame in headless Chromium, then
// encodes the README animation (assets/herdr-panel.webp) with ffmpeg.
//
//   npm install && npm run render
//
// Needs ffmpeg on PATH and a Chromium: set CHROMIUM_PATH, or run
// `npx playwright install chromium-headless-shell`.
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const assets = join(here, "..");
const fps = 25;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const page = await browser.newPage({ viewport: { width: 720, height: 720 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(join(here, "index.html")).href + "?render");
await page.evaluate(() => document.fonts.ready);

const duration = await page.evaluate(() => window.DURATION);
const frames = Math.round(duration * fps);
const dir = mkdtempSync(join(tmpdir(), "herdr-panel-frames-"));

for (let i = 0; i < frames; i++) {
    await page.evaluate(t => window.renderAt(t), i / fps);
    await page.screenshot({ path: join(dir, `f${String(i).padStart(4, "0")}.png`) });
    if (i % 50 === 0) console.log(`frame ${i}/${frames}`);
}
await browser.close();

const input = ["-y", "-loglevel", "error", "-framerate", String(fps), "-i", join(dir, "f%04d.png")];
execFileSync("ffmpeg", [...input, "-vf", "fps=15", "-c:v", "libwebp_anim", "-lossless", "0", "-quality", "80",
    "-compression_level", "6", "-loop", "0", join(assets, "herdr-panel.webp")], { stdio: "inherit" });

rmSync(dir, { recursive: true, force: true });
console.log("wrote assets/herdr-panel.webp");
