// node finalizar.mjs entrada.glb saida.glb : junta malhas, tira o metal padrão do exportador, normais chapadas nos materiais __flat
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import {dedup,flatten,join,weld,prune,textureCompress} from '@gltf-transform/functions';
import sharp from 'sharp';
const io=new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc=await io.read(process.argv[2]);const root=doc.getRoot();
await doc.transform(dedup({keepUniqueNames:true}),flatten(),join({keepNamed:false}),weld(),prune());
for(const m of root.listMaterials()){const mf=m.getMetallicFactor();
  if(mf===0.5)m.setMetallicFactor(0);else if(mf>0){const c=m.getBaseColorFactor();m.setBaseColorFactor([c[0]*(1-mf),c[1]*(1-mf),c[2]*(1-mf),c[3]]);m.setMetallicFactor(0)}
  m.setRoughnessFactor(1)}
let fl=0;
for(const mesh of root.listMeshes())for(const p of mesh.listPrimitives()){
  const mat=p.getMaterial();if(!mat||!/__.*flat/.test(mat.getName())||p.getMode()!==4)continue;
  const idx=p.getIndices();const pos=p.getAttribute('POSITION');const n=idx?idx.getCount():pos.getCount();const ix=k=>idx?idx.getScalar(k):k;
  for(const sem of p.listSemantics()){const a=p.getAttribute(sem);const es=a.getElementSize();const src=a.getArray();const out=new src.constructor(n*es);
    for(let k=0;k<n;k++){const v=ix(k);for(let c=0;c<es;c++)out[k*es+c]=src[v*es+c]}
    p.setAttribute(sem,doc.createAccessor().setType(a.getType()).setArray(out).setNormalized(a.getNormalized()).setBuffer(a.getBuffer()))}
  p.setIndices(null);const Pp=p.getAttribute('POSITION').getArray();const N=new Float32Array(n*3);const N0=p.getAttribute('NORMAL')?p.getAttribute('NORMAL').getArray():null;
  for(let k=0;k+2<n;k+=3){const ax=Pp[k*3],ay=Pp[k*3+1],az=Pp[k*3+2];const ux=Pp[k*3+3]-ax,uy=Pp[k*3+4]-ay,uz=Pp[k*3+5]-az,vx=Pp[k*3+6]-ax,vy=Pp[k*3+7]-ay,vz=Pp[k*3+8]-az;
    let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;const L=Math.hypot(nx,ny,nz)||1;nx/=L;ny/=L;nz/=L;
    if(N0){const sx=N0[k*3]+N0[k*3+3]+N0[k*3+6],sy=N0[k*3+1]+N0[k*3+4]+N0[k*3+7],sz=N0[k*3+2]+N0[k*3+5]+N0[k*3+8];if(nx*sx+ny*sy+nz*sz<0){nx=-nx;ny=-ny;nz=-nz}}
    for(let q=0;q<3;q++){N[(k+q)*3]=nx;N[(k+q)*3+1]=ny;N[(k+q)*3+2]=nz}}
  p.setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(N).setBuffer(p.getAttribute('POSITION').getBuffer()));p.setAttribute('TANGENT',null);fl++}
await doc.transform(prune());
console.log(process.argv[3],'materiais',root.listMaterials().length,'malhas',root.listMeshes().length,'texturas',root.listTextures().length,'chapadas',fl);
await io.write(process.argv[3],doc);
