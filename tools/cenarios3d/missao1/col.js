const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
for(const [s,t,nome,h] of[['delegacia','dentro','delegacia_17h',17],['delegacia','dentro','delegacia_21h',21],['delegacia','subsolo','subsolo',21],['biblioteca','dentro','biblioteca',19],['fazenda','dentro','fazenda',23]]){if(process.argv[2]&&!nome.startsWith(process.argv[2]))continue;
 const p=await b.newPage({viewport:{width:1280,height:720}});p.on('console',x=>{if(x.type()==='error')console.log('ERR',x.text().slice(0,400))});p.on('pageerror',e=>console.log('PAGEERR',e.message));
 await p.goto(`http://localhost:8123/cena.html?s=${s}&t=${t}&h=${h}&semag=1`);await p.waitForFunction('window.READY',{timeout:240000});const r=await p.evaluate(`(async()=>{const {colisao}=await import('./colisao.js');const m=await import('./${s}.js');const c={...(m.COLISAO['${t}']||m.COLISAO.dentro),baixo:.35};return colisao(K,c)})()`);
 fs.writeFileSync(`out/colj_${nome}.png`,Buffer.from(r.png.split(',')[1],'base64'));delete r.png;fs.writeFileSync(`out/colj_${nome}.json`,JSON.stringify(r));
 console.log(nome,'livre',r.livre_m2,'alcançável',r.alcancavel_m2,'ilhas',JSON.stringify(r.ilhas),'ret',r.retangulos.length);await p.close()}
await b.close()})();
