// Exporta a cena para o Godot: um glb por estado (base + grupos 'estado_*') e um JSON com luzes, brilhos,
// caixas que só fazem sombra, hora e névoa. Os materiais levam marcas no nome (o Godot 4.3 não lê extras).
import * as THREE from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {AMB,HORAS} from './kit.js';
const hex=c=>'#'+c.getHexString();
export async function exportar(K,mod,vista){const sc=K.sc;sc.updateMatrixWorld(true);
  const info={hora:AMB.h,amb:{...AMB},cfg:HORAS[AMB.h]||null,vista,luzes:[],brilhos:[],sombras:[],agentes:[],hemi:{ceu:hex(K.hemi.color),chao:hex(K.hemi.groundColor),i:K.hemi.intensity},
    sol:{cor:hex(K.sun.color),i:K.sun.intensity,dir:K.sun.position.clone().sub(K.sun.target.position).toArray()},nevoa:{cor:hex(sc.fog.color)},fundo:hex(sc.background)};
  const estadoDe=o=>{for(let p=o;p;p=p.parent)if(p.name&&p.name.startsWith('estado_'))return p.name.slice(7);return ''};
  const P=new THREE.Vector3(),Q=new THREE.Quaternion(),S=new THREE.Vector3();
  const fora=new Set();
  sc.traverse(o=>{
    if(o.userData.agente){o.getWorldPosition(P);info.agentes.push({pos:P.toArray(),ry:o.rotation.y});fora.add(o);return}
    if(o.isPointLight){if(o.intensity>0){o.getWorldPosition(P);info.luzes.push({cor:hex(o.color),i:o.intensity,d:o.distance,q:o.decay,pos:P.toArray(),estado:estadoDe(o)})}return}
    if(o.isSprite){if(o.visible&&o.material.opacity>0){o.getWorldPosition(P);o.getWorldScale(S);info.brilhos.push({pos:P.toArray(),s:S.x,o:o.material.opacity,cor:hex(o.material.color),estado:estadoDe(o)})}fora.add(o);return}
    if(o.isMesh){const ms=Array.isArray(o.material)?o.material:[o.material];
      if(ms.every(m=>m.colorWrite===false)){if(o.castShadow&&o.geometry.type==='BoxGeometry'){o.matrixWorld.decompose(P,Q,S);const g=o.geometry.parameters;info.sombras.push({pos:P.toArray(),rot:Q.toArray(),tam:[g.width*S.x,g.height*S.y,g.depth*S.z],estado:estadoDe(o)})}fora.add(o);return}
      if(!o.visible)fora.add(o)}});
  // marcas nos nomes dos materiais
  let n=0;const visto=new Map();
  sc.traverse(o=>{if(!o.isMesh||fora.has(o))return;const ms=Array.isArray(o.material)?o.material:[o.material];
    for(const m of ms){if(visto.has(m))continue;const t=[];if(m.blending===THREE.AdditiveBlending)t.push('add');if(m.isMeshBasicMaterial)t.push('unlit');if(m.flatShading)t.push('flat');if(m.fog===false)t.push('semnevoa');
      if(!o.castShadow)t.push('semsombra');if(m.side===THREE.BackSide)t.push('dentro');if(m.emissiveMap||(m.emissive&&m.emissive.getHex()))t.push('emi'+Math.round((m.emissiveIntensity??1)*100));
      m.name='k'+(n++)+(t.length?'__'+t.join('_'):'');visto.set(m,1)}});
  const grupos={base:new THREE.Scene()};
  const add=(o,dest)=>{ // clona só malhas, com a matriz do mundo
    if(fora.has(o)||o.isLight||o.isSprite)return;
    if(o.isMesh){const c=new THREE.Mesh(o.geometry,o.material);c.applyMatrix4(o.matrixWorld);dest.add(c);return}
    let d=dest;if(o.name&&o.name.startsWith('estado_')){const k=o.name.slice(7);d=grupos[k]=grupos[k]||new THREE.Scene()}
    for(const c of o.children)add(c,d)};
  for(const c of sc.children)add(c,grupos.base);
  const ex=new GLTFExporter();const out={info,glb:{}};
  for(const k in grupos){grupos[k].updateMatrixWorld(true);const buf=await new Promise((res,rej)=>ex.parse(grupos[k],res,rej,{binary:true,onlyVisible:true,maxTextureSize:2048}));
    let bin='';const u=new Uint8Array(buf);for(let i=0;i<u.length;i+=32768)bin+=String.fromCharCode.apply(null,u.subarray(i,i+32768));out.glb[k]=btoa(bin)}
  info.colisao=(mod.COLISAO||{})[vista]||(mod.COLISAO||{}).dentro||null;
  return out}
