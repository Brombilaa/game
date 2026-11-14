// node col_cripta.js [px] -> out/colj_cripta.png e .json: mapa de colisão da cripta (modelo C) para o jogo, em dois níveis
// (colisao2.js). `retangulos` já vem como o sólido do plano único do jogo; `pontos` leva níveis, inimigos e gatilhos.
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const px=+(process.argv[2]||.1);const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
 const p=await b.newPage({viewport:{width:1280,height:720}});p.on('console',x=>{if(x.type()==='error')console.log('ERR',x.text().slice(0,400))});p.on('pageerror',e=>console.log('PAGEERR',e.message));
 await p.goto('http://localhost:8123/cena.html?s=cripta&m=C&t=geral&semag=1&exp=1');await p.waitForFunction('window.READY',{timeout:240000});
 const r=await p.evaluate(`(async()=>{const {colisao}=await import('./colisao2.js');const mo=await import('./cripta.js');return {...colisao(K,{...mo.COLISAO.dentro,px:${px}}),pontos:mo.PONTOS}})()`);
 fs.writeFileSync('out/colj_cripta.png',Buffer.from(r.png.split(',')[1],'base64'));delete r.png;r.retangulos=r.solidos;delete r.solidos;fs.writeFileSync('out/colj_cripta.json',JSON.stringify(r));
 console.log('cripta chão',r.chao_m2,'alto',r.alto_m2,'retângulos',r.retangulos.length,'visão',r.visao.length);await b.close()})();
