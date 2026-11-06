const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage({viewport:{width:1920,height:1080}});p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>{if(m.type()==='error')console.log('C',m.text())});
await p.goto('http://localhost:8124/bake.html');await p.waitForFunction('window.done',null,{timeout:300000});await p.waitForTimeout(800);
const r=await p.evaluate(()=>window.exportScene());
fs.writeFileSync('parque_cenario.glb',Buffer.from(r.glb,'base64'));delete r.glb;fs.writeFileSync('parque_info.json',JSON.stringify(r,null,1));console.log(JSON.stringify(r).slice(0,1500));await b.close()})();
