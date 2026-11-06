// Trecho a inserir em parque3d_bake.html (antes de window.bake), junto com
// import {GLTFExporter} from "three/addons/exporters/GLTFExporter.js";
window.exportScene=async function(){
 const info=[];sc.traverse(o=>{if(o.isLight)info.push({t:o.type,c:o.color.getHexString(),i:o.intensity,p:o.getWorldPosition(new THREE.Vector3()).toArray(),d:o.distance||0,sh:o.castShadow})});
 const root=new THREE.Scene();const keep=[];
 sc.children.forEach(o=>{if(chars.includes(o)||o.isLight)return;keep.push(o)});
 const hid=[];sc.traverse(o=>{if(o.isSprite||o.isPoints){hid.push([o,o.visible]);o.visible=false}});
 const grp=new THREE.Group();keep.forEach(o=>{if(o.visible!==false)grp.add(o.clone(true))});
 grp.traverse(o=>{if(o.isSprite||o.isPoints||o.isLine)o.visible=false});
 root.add(grp);root.updateMatrixWorld(true);
 {const rm=[];const bb=new THREE.Box3(),c=new THREE.Vector3(),sz=new THREE.Vector3();grp.traverse(o=>{if(!o.isMesh)return;bb.setFromObject(o);bb.getCenter(c);bb.getSize(sz);const big=Math.max(sz.x,sz.z)>60;if(!big&&(c.x<-16||c.x>36||c.z<-14||c.z>30))rm.push(o)});rm.forEach(o=>o.parent.remove(o));}
 const ex=new GLTFExporter();
 const buf=await new Promise((res,rej)=>ex.parse(root,res,rej,{binary:true,onlyVisible:true,maxTextureSize:1024}));
 let bin='';const u=new Uint8Array(buf);for(let i=0;i<u.length;i+=32768)bin+=String.fromCharCode.apply(null,u.subarray(i,i+32768));
 return {glb:btoa(bin),lights:info,bg:sc.background&&sc.background.getHexString?sc.background.getHexString():null,fog:sc.fog?{c:sc.fog.color.getHexString(),n:sc.fog.near,f:sc.fog.far}:null,n:keep.length}};
