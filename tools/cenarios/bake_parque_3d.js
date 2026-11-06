const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const W=1928,H=900,X0=-84,Y0=0;
const p=await b.newPage({viewport:{width:W,height:H}});p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>{if(m.type()==='error')console.log('C',m.text())});
await p.goto('http://localhost:8123/bake.html');await p.waitForFunction('window.done',null,{timeout:500000});await p.waitForTimeout(800);
const rects=JSON.parse(fs.readFileSync('rects.json'));
const r=await p.evaluate(([W,H,X0,Y0,rects])=>window.bake(W,H,X0,Y0,rects),[W,H,X0,Y0,rects]);
fs.mkdirSync('out/oc',{recursive:true});
const wr=(f,d)=>fs.writeFileSync(f,Buffer.from(d.split(',')[1],'base64'));
wr('out/full.png',r.fundo);const meta=[];
for(const o of r.occ){if(o.empty){console.log('vazio',o.id);continue}wr('out/oc/'+o.id+'.png',o.png);meta.push({id:o.id,x:o.x,y:o.y,w:o.w,h:o.h})}
fs.writeFileSync('out/occ.json',JSON.stringify(meta));console.log(JSON.stringify(meta));await b.close()})();
