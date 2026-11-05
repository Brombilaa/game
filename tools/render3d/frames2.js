const {chromium}=require('playwright');const fs=require('fs');
// uso: node frames.js "<query>" <anim> <nframes> <dirs csv> <saida> [t0] [dur]
(async()=>{const [q,anim,nf,dirs,out,t0s,durs]=process.argv.slice(2);
const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage({viewport:{width:1200,height:1200}});p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>console.log(m.text()));
await p.goto('http://localhost:8125/'+(process.env.PAGE||'render.html')+'?'+q);await p.waitForFunction('window.done',{timeout:600000});
const info=await p.evaluate(a=>window.loadAnim(a),anim);const dur=durs?+durs:info.dur;const t0=t0s?+t0s:0;
fs.mkdirSync(out,{recursive:true});
for(const d of dirs.split(',').map(Number))for(let i=0;i<+nf;i++){
  const t=t0+dur*i/(+nf);
  for(const mode of (process.env.MODES||'cn').split('')){const u=await p.evaluate(([a,t,d,m])=>window.shot(a,t,d,m),[anim,t,d,mode]);
   fs.writeFileSync(`${out}/d${d}_f${String(i).padStart(2,'0')}_${mode}.png`,Buffer.from(u.split(',')[1],'base64'))}}
console.log('ok',info.dur);await b.close()})();
