// Trecho a inserir no HTML do protótipo (parque3d_bake_caminho_c.html), antes de window.bake, junto com
// import {GLTFExporter} from "three/addons/exporters/GLTFExporter.js";
// Marca os materiais com flatShading (extras.flat), mantém o lago (textura window.WT) e converte as texturas
// sem espaço de cor (lineares no protótipo) para sRGB antes de exportar.
window.exportScene=async function(){
 const info=[];sc.traverse(o=>{if(o.isLight)info.push({t:o.type,c:o.color.getHexString(),i:o.intensity,p:o.getWorldPosition(new THREE.Vector3()).toArray(),d:o.distance||0,sh:o.castShadow})});
 const root=new THREE.Scene();const keep=[];
 sc.children.forEach(o=>{if(chars.includes(o)||o.isLight)return;keep.push(o)});
 const hid=[];sc.traverse(o=>{if(o.isSprite||o.isPoints){hid.push([o,o.visible]);o.visible=false}});
 const grp=new THREE.Group();keep.forEach(o=>{if(o.visible!==false)grp.add(o.clone(true))});
 grp.traverse(o=>{if(o.isSprite||o.isPoints||o.isLine)o.visible=false});
 grp.traverse(o=>{if(o.isMesh){for(const m of (Array.isArray(o.material)?o.material:[o.material]))if(m.flatShading)m.userData.flat=1}});
 root.add(grp);root.updateMatrixWorld(true);
 {const cache=new Map();const fix=t=>{if(cache.has(t.uuid))return cache.get(t.uuid);const im=t.image;let r=t;if(im&&im.width){const c=document.createElement('canvas');c.width=im.width;c.height=im.height;const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(im,0,0);const d=g.getImageData(0,0,c.width,c.height);const lut=new Uint8Array(256);for(let i=0;i<256;i++){const v=i/255;lut[i]=Math.round(255*(v<=0.0031308?v*12.92:1.055*Math.pow(v,1/2.4)-0.055))}for(let i=0;i<d.data.length;i+=4){d.data[i]=lut[d.data[i]];d.data[i+1]=lut[d.data[i+1]];d.data[i+2]=lut[d.data[i+2]]}g.putImageData(d,0,0);r=new THREE.CanvasTexture(c);r.colorSpace=THREE.SRGBColorSpace;r.wrapS=t.wrapS;r.wrapT=t.wrapT;r.flipY=t.flipY;r.repeat.copy(t.repeat);r.offset.copy(t.offset);r.magFilter=t.magFilter;r.minFilter=t.minFilter}cache.set(t.uuid,r);return r};
 const mc=new Map();grp.traverse(o=>{if(!o.isMesh)return;const ms=Array.isArray(o.material)?o.material:[o.material];const nm=ms.map(m=>{if(m.map&&m.map.colorSpace===''&&m.map.image&&m.map.image.width){if(!mc.has(m.uuid)){const c=m.clone();c.map=fix(m.map);mc.set(m.uuid,c)}return mc.get(m.uuid)}return m});o.material=Array.isArray(o.material)?nm:nm[0]})}
 {const rm=[];const bb=new THREE.Box3(),c=new THREE.Vector3(),sz=new THREE.Vector3();grp.traverse(o=>{if(!o.isMesh)return;bb.setFromObject(o);bb.getCenter(c);bb.getSize(sz);const big=Math.max(sz.x,sz.z)>60;const lago=o.material&&o.material.map===window.WT;if(!big&&!lago&&(c.x<-16||c.x>36||c.z<-14||c.z>30))rm.push(o)});rm.forEach(o=>o.parent.remove(o));}
 const ex=new GLTFExporter();
 const buf=await new Promise((res,rej)=>ex.parse(root,res,rej,{binary:true,onlyVisible:true,maxTextureSize:1024}));
 let bin='';const u=new Uint8Array(buf);for(let i=0;i<u.length;i+=32768)bin+=String.fromCharCode.apply(null,u.subarray(i,i+32768));
 return {glb:btoa(bin),lights:info,bg:sc.background&&sc.background.getHexString?sc.background.getHexString():null,fog:sc.fog?{c:sc.fog.color.getHexString(),n:sc.fog.near,f:sc.fog.far}:null,n:keep.length}};
