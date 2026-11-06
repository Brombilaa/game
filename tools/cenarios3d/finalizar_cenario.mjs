// Uso: node finalizar_cenario.mjs entrada.glb saida.glb chao_original_invertido.jpg
// Finaliza o cenário exportado: materiais sem metal, textura do chão original e normais chapadas
// nos materiais que o three.js desenha com flatShading (marcados em extras.flat no export).
import {NodeIO} from '@gltf-transform/core';
import {ALL_EXTENSIONS} from '@gltf-transform/extensions';
import fs from 'fs';
const io=new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc=await io.read(process.argv[2]);
const root=doc.getRoot();
root.listMaterials().forEach((m,i)=>m.setName('m'+i));  // nome estável para a calibragem por material
for(const m of root.listMaterials()){
  // 0.5 é o padrão do exportador para Lambert (sem metal no JS). Metal real (vidro da van, 0.3): sem mapa de
  // ambiente o three.js só tira (1 - metal) do difuso, então o Godot recebe a cor já escurecida e metal 0.
  const mf=m.getMetallicFactor();
  if(mf===0.5)m.setMetallicFactor(0);
  else if(mf>0){const c=m.getBaseColorFactor();m.setBaseColorFactor([c[0]*(1-mf),c[1]*(1-mf),c[2]*(1-mf),c[3]]);m.setMetallicFactor(0)}
  if(m.getRoughnessFactor()===0.5||m.getRoughnessFactor()===0.25)m.setRoughnessFactor(1);
}
let tr=0;
for(const t of root.listTextures()){const s=t.getSize();if(s&&s[0]===1024&&s[1]===1024){t.setImage(fs.readFileSync(process.argv[4]));t.setMimeType('image/jpeg');tr++}}
let fl=0,tot=0,viradas=0;
for(const mesh of root.listMeshes())for(const p of mesh.listPrimitives()){
  tot++;const mat=p.getMaterial();if(!mat||!(mat.getExtras()||{}).flat||p.getMode()!==4)continue;
  const idx=p.getIndices();const pos=p.getAttribute('POSITION');
  const n=idx?idx.getCount():pos.getCount();
  const ix=k=>idx?idx.getScalar(k):k;
  for(const sem of p.listSemantics()){
    const a=p.getAttribute(sem);const es=a.getElementSize();const src=a.getArray();
    const out=new src.constructor(n*es);
    for(let k=0;k<n;k++){const v=ix(k);for(let c=0;c<es;c++)out[k*es+c]=src[v*es+c]}
    const na=doc.createAccessor().setType(a.getType()).setArray(out).setNormalized(a.getNormalized()).setBuffer(a.getBuffer());
    p.setAttribute(sem,na);
  }
  p.setIndices(null);
  const P=p.getAttribute('POSITION').getArray();const N=new Float32Array(n*3);
  const N0=p.getAttribute('NORMAL')?p.getAttribute('NORMAL').getArray():null;  // normais originais: dão o lado de fora
  for(let k=0;k+2<n;k+=3){
    const ax=P[k*3],ay=P[k*3+1],az=P[k*3+2];
    const ux=P[k*3+3]-ax,uy=P[k*3+4]-ay,uz=P[k*3+5]-az,vx=P[k*3+6]-ax,vy=P[k*3+7]-ay,vz=P[k*3+8]-az;
    let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;const L=Math.hypot(nx,ny,nz)||1;nx/=L;ny/=L;nz/=L;
    if(N0){const sx=N0[k*3]+N0[k*3+3]+N0[k*3+6],sy=N0[k*3+1]+N0[k*3+4]+N0[k*3+7],sz=N0[k*3+2]+N0[k*3+5]+N0[k*3+8];if(nx*sx+ny*sy+nz*sz<0){nx=-nx;ny=-ny;nz=-nz;viradas++}}
    for(let q=0;q<3;q++){N[(k+q)*3]=nx;N[(k+q)*3+1]=ny;N[(k+q)*3+2]=nz}
  }
  const buf=p.getAttribute('POSITION').getBuffer();
  p.setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(N).setBuffer(buf));
  p.setAttribute('TANGENT',null);
  fl++;
}
for(const a of root.listAccessors())if(a.listParents().length<=1)a.dispose();
console.log('substituidas',tr,'prims',tot,'chapadas',fl,'faces viradas',viradas);
await io.write(process.argv[3],doc);
