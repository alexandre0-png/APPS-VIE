// Génère l'icône (512x512) et 3 miniatures (1920x1080) du jeu avec Chromium (Playwright).
const { chromium } = require('playwright');
const path = require('path');
const out = path.join(__dirname, '..', 'publication', 'images');
const font = `font-family:'Impact','Arial Black',sans-serif;`;
const base = `*{box-sizing:border-box;margin:0}body{${font}color:#fff;overflow:hidden}
.bg{position:absolute;inset:0;background:radial-gradient(circle at 50% 45%,#ff8a3d55,transparent 55%),linear-gradient(#1b2236,#3a2a3a 60%,#2a1c14)}
.floor{position:absolute;left:0;right:0;bottom:0;height:32%;background:repeating-linear-gradient(90deg,#4c463f 0 80px,#59524a 80px 160px)}
.lava{position:absolute;bottom:0;height:12%;background:linear-gradient(#ff5c14,#c92a00);box-shadow:0 0 80px #ff5c14}
.sword{position:absolute;background:linear-gradient(90deg,#aeb6c2,#f2f5f9,#aeb6c2);border-radius:6px 6px 0 0;clip-path:polygon(50% 0,100% 8%,100% 100%,0 100%,0 8%)}
.guard{position:absolute;background:#ffc428;border-radius:8px;box-shadow:0 8px 0 #b88a10}
.hilt{position:absolute;background:#6b4a2b;border-radius:6px}
h1{letter-spacing:.04em;text-shadow:0 8px 0 #000a,0 0 40px #ff8a3d88;line-height:.95}
h1 em{font-style:normal;color:#ffc428}`;
function sword(x,y,h,rot,sc=1){return `<div style="position:absolute;left:${x}px;top:${y}px;transform:rotate(${rot}deg) scale(${sc});transform-origin:50% 100%"><div class="sword" style="left:-22px;top:${-h}px;width:44px;height:${h}px"></div><div class="guard" style="left:-80px;top:0;width:160px;height:26px"></div><div class="hilt" style="left:-14px;top:26px;width:28px;height:90px"></div></div>`}
const scenes = {
 'icone-512': {w:512,h:512,html:`<div class="bg"></div><div class="floor" style="height:22%"></div>${sword(256,290,230,0,1)}<div style="position:absolute;bottom:26px;width:100%;text-align:center;font-size:58px;${font}text-shadow:0 5px 0 #000">ARÈNE</div>`},
 'miniature-1-titre': {w:1920,h:1080,html:`<div class="bg"></div><div class="floor"></div><div class="lava" style="left:0;width:22%"></div><div class="lava" style="right:0;width:22%"></div>${sword(560,640,520,-24)}${sword(1360,640,520,24)}
  <div style="position:absolute;top:120px;width:100%;text-align:center"><h1 style="font-size:210px">ARÈNE<br><em>DES LÉGENDES</em></h1></div>
  <div style="position:absolute;bottom:60px;width:100%;text-align:center;font-size:54px;letter-spacing:.1em">10 ARMES · 2 MODES · COMBATS DE 3 MIN</div>`},
 'miniature-2-modes': {w:1920,h:1080,html:`<div class="bg" style="background:linear-gradient(90deg,#8f1d1d,#1b2236 50%,#1d3f8f)"></div><div class="floor"></div>
  <div style="position:absolute;left:0;top:90px;width:50%;text-align:center;font-size:130px;color:#ff6b5b;text-shadow:0 8px 0 #000">ROUGES</div><div style="position:absolute;right:0;top:90px;width:50%;text-align:center;font-size:130px;color:#5bb0ff;text-shadow:0 8px 0 #000">BLEUS</div>
  ${sword(520,720,460,-20)}${sword(1400,720,460,20)}<div style="position:absolute;top:430px;width:100%;text-align:center;font-size:240px;text-shadow:0 10px 0 #000">VS</div>
  <div style="position:absolute;bottom:50px;width:100%;text-align:center;font-size:62px">GUERRE DES COULEURS</div>`},
 'miniature-3-armes': {w:1920,h:1080,html:`<div class="bg"></div><div class="floor" style="height:20%"></div>
  <div style="position:absolute;top:70px;width:100%;text-align:center;font-size:140px;color:#ffc428;text-shadow:0 8px 0 #000">DÉBLOQUE 10 ARMES</div>
  ${[[-1,'#d0d6de'],[0,'#ff6b81'],[1,'#35e0ff'],[2,'#ffa94d'],[3,'#b05cff']].map(([i,c])=>sword(260+(i+1)*350,820,320+Math.abs(i)*10,(i-1)*7,1)+`<div style="position:absolute;left:${200+(i+1)*350}px;top:880px;width:120px;height:12px;background:${c};box-shadow:0 0 30px ${c}"></div>`).join('')}
  <div style="position:absolute;bottom:40px;width:100%;text-align:center;font-size:56px">ÉPÉE · ARC · KATANA · PISTOLET · MARTEAU · DAGUE · BÂTON · FUSIL · RAIL</div>`},
};
(async()=>{
  const b = await chromium.launch(); 
  for (const [name,s] of Object.entries(scenes)) {
    const p = await b.newPage({viewport:{width:s.w,height:s.h}});
    await p.setContent(`<style>${base}</style><div style="position:relative;width:${s.w}px;height:${s.h}px;overflow:hidden">${s.html}</div>`);
    await p.screenshot({path:path.join(out,name+'.png')});
    await p.close();
  }
  await b.close();
})();
