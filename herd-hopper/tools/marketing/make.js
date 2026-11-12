// Génère les images de publication dans marketing/ (Chromium + Playwright).  Usage : node tools/marketing/make.js
const path = require('path');
const { chromium } = require('playwright');
const jobs = [
  ['icon', 'icone-experience-512.png', 512, 512],
  ['hero', 'vignette-1-presentation-1920x1080.png', 1920, 1080],
  ['zoo', 'vignette-2-zoo-1920x1080.png', 1920, 1080],
  ['boss', 'vignette-3-boss-1920x1080.png', 1920, 1080],
  ['pass-zoo', 'pass-zoo-premium-512.png', 512, 512],
  ['pass-gold', 'pass-or-x2-512.png', 512, 512],
  ['pass-life', 'pass-vie-supplementaire-512.png', 512, 512],
  ['pass-lasso', 'pass-lasso-dore-512.png', 512, 512],
  ['gold-s', 'produit-or-2000-512.png', 512, 512],
  ['gold-m', 'produit-or-7000-512.png', 512, 512],
  ['gold-l', 'produit-or-25000-512.png', 512, 512],
  ['bones-s', 'produit-os-40-512.png', 512, 512],
  ['bones-m', 'produit-os-150-512.png', 512, 512],
  ['boost', 'produit-boost-zoo-512.png', 512, 512],
  ['revive', 'produit-continuer-512.png', 512, 512],
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
