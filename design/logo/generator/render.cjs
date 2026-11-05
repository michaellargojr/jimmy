// Screenshot a round's contact sheet with the pre-installed Playwright Chromium.
// usage: node render.cjs <index.html> <out.png> [deviceScaleFactor=2]
const { chromium } = require("playwright");
const { resolve } = require("node:path");

const [html, out, scale = "2"] = process.argv.slice(2);
if (!html || !out) {
  console.error("usage: node render.cjs <index.html> <out.png> [scale]");
  process.exit(2);
}
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1480, height: 900 }, deviceScaleFactor: Number(scale) });
  await page.goto("file://" + resolve(html));
  await page.waitForTimeout(300);
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
  console.log("wrote", out);
})().catch((e) => { console.error(e); process.exit(1); });
