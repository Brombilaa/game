// node exp.js <cena> <vista> <hora> <nome>  -> exp/<nome>.glb (+ _<estado>.glb) e exp/<nome>.json
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const [s,v,h,nome]=process.argv.slice(2);fs.mkdirSync('exp',{recursive:true});
const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage({viewport:{width:1280,height:720}});p.on('console',x=>{if(x.type()==='error')console.log('ERR',x.text().slice(0,700))});p.on('pageerror',e=>console.log('PAGEERR',e.message));
await p.goto(`http://localhost:8123/cena.html?s=${s}&v=${v}&h=${h}&exp=1`);await p.waitForFunction('window.READY',{timeout:240000});
const r=await p.evaluate(()=>window.EXPORT());
for(const k in r.glb){const f=`exp/${nome}${k==='base'?'':'_'+k}.glb`;fs.writeFileSync(f,Buffer.from(r.glb[k],'base64'));console.log(f,(fs.statSync(f).size/1e6).toFixed(1)+' MB')}
fs.writeFileSync(`exp/${nome}.json`,JSON.stringify(r.info,null,1));console.log('luzes',r.info.luzes.length,'brilhos',r.info.brilhos.length,'sombras',r.info.sombras.length);await b.close()})();
