// Génère les images de publication dans marketing/ (Chromium + Playwright).  Usage : node tools/marketing/make.js
const path = require('path');
const { chromium } = require('playwright');
const jobs = [
  ['icon', 'icone-experience-512.png', 512, 512],
  ['hero', 'vignette-1-presentation-1920x1080.png', 1920, 1080],
  ['combo', 'vignette-2-combo-1920x1080.png', 1920, 1080],
  ['lava', 'vignette-3-mur-de-lave-1920x1080.png', 1920, 1080],
  ['pass-double', 'pass-pieces-x2-512.png', 512, 512],
  ['pass-rope', 'pass-corde-longue-512.png', 512, 512],
  ['pass-vip', 'pass-vip-512.png', 512, 512],
  ['coins-s', 'produit-500-pieces-512.png', 512, 512],
  ['coins-m', 'produit-1500-pieces-512.png', 512, 512],
  ['coins-l', 'produit-5000-pieces-512.png', 512, 512],
];
(async () => {
  const browser = await chromium.launch();
  for (const [scene, file, w, h] of jobs) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.goto('file://' + path.join(__dirname, 'art.html') + '?s=' + scene);
    await page.evaluate(() => document.fonts && document.fonts.ready);
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(__dirname, '..', '..', 'marketing', file) });
    console.log('OK', file);
    await page.close();
  }
  await browser.close();
})();
