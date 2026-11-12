// Génère dist/store/*.png avec Chromium (Playwright). Usage : node tools/store_assets/render.js
const { chromium } = require('playwright');
const path = require('path');
const url = 'file://' + path.join(__dirname, 'art.html');
const out = path.join(__dirname, '..', '..', 'dist', 'store');
const jobs = [
  ['thumb1', 1920, 1080], ['thumb2', 1920, 1080], ['thumb3', 1920, 1080],
  ['icon', 512, 512],
  ['pass_vip', 512, 512], ['pass_nest', 512, 512], ['pass_aim', 512, 512],
  ['prod_coins_s', 512, 512], ['prod_coins_l', 512, 512], ['prod_eggs', 512, 512],
];
(async () => {
  const browser = await chromium.launch();
  for (const [name, w, h] of jobs) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.goto(url + '#' + name);
    // Les scènes sont conçues en 1920x1080 : on les met à l'échelle pour les icônes carrées.
    await page.evaluate(([w, h]) => {
      const s = document.getElementById('s');
      const k = Math.min(w / 1920, h / 1080);
      if (w === h) {
        s.style.width = '1080px'; s.style.height = '1080px';
        s.style.transform = `scale(${w / 1080})`;
      } else {
        s.style.transform = `scale(${k})`;
      }
    }, [w, h]);
    await page.screenshot({ path: path.join(out, name + '.png') });
    await page.close();
  }
  await browser.close();
  console.log('OK', jobs.length, 'images ->', out);
})();
