// Mapa de colisão em dois níveis: corte da cena no piso (0) e no nível alto (terraço, tribuna, galeria), unidos pelas escadas.
// cfg.nivel(x,z) devolve 0 (chão), 1 (alto) ou 2 (escada, liga os dois). Mesmo método do colisao.js da missão 1.
import * as THREE from 'three';
export function colisao(K,{area,inicio,raio=.3,px=.1,gatilhos=[],baixo=.35,marcas=[],nivel=()=>0,alto=1.5}){
  const [x0,z0,x1,z1]=area,W=Math.round((x1-x0)/px),H=Math.round((z1-z0)/px),sc=K.sc;
  const esc=[];sc.traverse(o=>{let hide=o.isSprite;if(o.userData.fantasma||o.userData.porta||o.userData.agente)hide=true;
    if(o.isMesh&&!o.userData.bloqueio){const ms=Array.isArray(o.material)?o.material:[o.material];if(ms.every(m=>m.transparent||m.alphaTest>0||m.blending===THREE.AdditiveBlending||m.colorWrite===false))hide=true}
    if(hide&&o.visible){o.visible=false;esc.push(o)}});
  const bg=sc.background,fog=sc.fog;sc.background=new THREE.Color(0xffffff);sc.fog=null;sc.updateMatrixWorld(true);
  const corte=(piso)=>{const cam=new THREE.OrthographicCamera(-(x1-x0)/2,(x1-x0)/2,(z1-z0)/2,-(z1-z0)/2,0,1.75-baixo);cam.position.set((x0+x1)/2,piso+1.75,(z0+z1)/2);cam.up.set(0,0,-1);cam.lookAt((x0+x1)/2,piso,(z0+z1)/2);
    const rt=new THREE.WebGLRenderTarget(W,H),lo=piso+baixo,hi=piso+1.74,PRETO=new THREE.MeshBasicMaterial({color:0,side:THREE.DoubleSide});
    const ACH=new THREE.ShaderMaterial({side:THREE.DoubleSide,uniforms:{lo:{value:lo},hi:{value:hi}},vertexShader:'uniform float lo,hi;void main(){vec4 w=modelMatrix*vec4(position,1.);w.y=clamp(w.y,lo,hi);gl_Position=projectionMatrix*viewMatrix*w;}',fragmentShader:'void main(){gl_FragColor=vec4(0.,0.,0.,1.);}'});
    const troca=[],bb=new THREE.Box3(),up=new THREE.Vector3();sc.traverse(o=>{if(!o.isMesh)return;troca.push([o,o.material]);const t=o.geometry&&o.geometry.type;let m=PRETO;
      if(t==='BoxGeometry'||t==='CylinderGeometry'){bb.setFromObject(o);up.set(0,1,0).transformDirection(o.matrixWorld);if(bb.max.y>hi&&bb.min.y<hi&&Math.abs(up.y)>.999)m=ACH}o.material=m});
    K.rr.setRenderTarget(rt);K.rr.render(sc,cam);const buf=new Uint8Array(W*H*4);K.rr.readRenderTargetPixels(rt,0,0,W,H,buf);K.rr.setRenderTarget(null);troca.forEach(([o,m])=>o.material=m);
    const B=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++)B[y*W+x]=buf[((H-1-y)*W+x)*4]<128?1:0;return B};
  const B0=corte(0),B1=corte(alto);
  // segundo corte sem o que é baixo (parapeito, sarcófago, banco, bloco do fosso): o que sobra é o que barra a visão
  const bx=[];sc.traverse(o=>{if((o.userData.baixo||o.userData.bloqueio)&&o.visible){o.visible=false;bx.push(o)}});const V0=corte(0),V1=corte(alto);bx.forEach(o=>o.visible=true);sc.background=bg;sc.fog=fog;esc.forEach(o=>o.visible=true);
  const Lv=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++)Lv[y*W+x]=nivel(x0+(x+.5)*px,z0+(y+.5)*px);
  const B=new Uint8Array(W*H);for(let i=0;i<W*H;i++)B[i]=Lv[i]===2?0:Lv[i]===1?B1[i]:B0[i];
  const r=Math.round(raio/px),M=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++){if(!B[y*W+x])continue;for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(dx*dx+dy*dy>r*r)continue;const xx=x+dx,yy=y+dy;if(xx>=0&&yy>=0&&xx<W&&yy<H&&Lv[yy*W+xx]!==2&&(Lv[yy*W+xx]===Lv[y*W+x]))M[yy*W+xx]=1}}
  // borda entre níveis sem escada não se atravessa
  const passa=(i,j)=>Lv[i]===Lv[j]||Lv[i]===2||Lv[j]===2;
  const A=new Uint8Array(W*H);const sx=Math.round((inicio[0]-x0)/px),sy=Math.round((inicio[1]-z0)/px);const st=[[sx,sy]];A[sy*W+sx]=1;
  while(st.length){const [x,y]=st.pop();for(const [dx,dy] of[[1,0],[-1,0],[0,1],[0,-1]]){const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=W||yy>=H)continue;const i=yy*W+xx;if(M[i]||A[i]||!passa(y*W+x,i))continue;A[i]=1;st.push([xx,yy])}}
  const ret=[];let ab=new Map();for(let y=0;y<=H;y++){const runs=new Map();if(y<H){let x=0;while(x<W){if(B0[y*W+x]){let e=x;while(e<W&&B0[y*W+e])e++;runs.set(x+'_'+e,[x,e]);x=e}else x++}}
    for(const [k,v] of ab){if(!runs.has(k)){ret.push([+(x0+v[0]*px).toFixed(2),+(z0+v[2]*px).toFixed(2),+((v[1]-v[0])*px).toFixed(2),+((y-v[2])*px).toFixed(2)]);ab.delete(k)}}for(const [k,v] of runs)if(!ab.has(k))ab.set(k,[v[0],v[1],y])}
  // Para o jogo (plano único): sólido é tudo o que não se alcança sem a margem do corpo, mais a borda entre o alto e o
  // chão onde não há escada. O jogo aplica o raio de cada personagem por conta própria.
  // alcançável sem margem = o alcançável com margem (A) engordado de volta pelo raio, fora do que é sólido; assim frestas mais estreitas que o corpo não vazam
  const Ar=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++){if(!A[y*W+x])continue;for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(dx*dx+dy*dy>r*r)continue;const xx=x+dx,yy=y+dy;if(xx>=0&&yy>=0&&xx<W&&yy<H&&!B[yy*W+xx])Ar[yy*W+xx]=1}}
  const So=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;if(!Ar[i]){So[i]=1;continue}if(Lv[i]!==1)continue;for(const [dx,dy] of[[1,0],[-1,0],[0,1],[0,-1]]){const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=W||yy>=H)continue;const k=yy*W+xx;if(Ar[k]&&Lv[k]===0){So[i]=1;break}}}
  const fundir=(So)=>{const solidos=[];let ab2=new Map();for(let y=0;y<=H;y++){const runs=new Map();if(y<H){let x=0;while(x<W){if(So[y*W+x]){let e=x;while(e<W&&So[y*W+e])e++;runs.set(x+'_'+e,[x,e]);x=e}else x++}}
    for(const [k,v] of ab2){if(!runs.has(k)){solidos.push([+(x0+v[0]*px).toFixed(2),+(z0+v[2]*px).toFixed(2),+((v[1]-v[0])*px).toFixed(2),+((y-v[2])*px).toFixed(2)]);ab2.delete(k)}}for(const [k,v] of runs)if(!ab2.has(k))ab2.set(k,[v[0],v[1],y])}return solidos};
  const solidos=fundir(So),Vi=new Uint8Array(W*H);for(let i=0;i<W*H;i++)Vi[i]=Lv[i]===2?0:Lv[i]===1?V1[i]:V0[i];const visao=fundir(Vi);
  const S=6,c=document.createElement('canvas');c.width=W*S;c.height=H*S;const g=c.getContext('2d');g.fillStyle='#14161a';g.fillRect(0,0,c.width,c.height);
  let a0=0,a1=0;for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;if(A[i]){if(Lv[i]===1)a1++;else a0++}g.fillStyle=B[i]?'#c0483c':M[i]?'#5a3a34':A[i]?(Lv[i]===1?'#3b6fb0':Lv[i]===2?'#8fc0e8':'#2f6a52'):'#1b1d22';g.fillRect(x*S,y*S,S,S)}
  g.strokeStyle='rgba(255,255,255,.10)';g.lineWidth=1;for(let m=Math.ceil(x0);m<x1;m++){g.beginPath();g.moveTo((m-x0)/px*S,0);g.lineTo((m-x0)/px*S,c.height);g.stroke()}for(let m=Math.ceil(z0);m<z1;m++){g.beginPath();g.moveTo(0,(m-z0)/px*S);g.lineTo(c.width,(m-z0)/px*S);g.stroke()}
  g.textAlign='center';for(const t of gatilhos){const [a,b,d,e]=t.ret;g.fillStyle='rgba(240,200,80,.28)';g.fillRect((a-x0)/px*S,(b-z0)/px*S,(d-a)/px*S,(e-b)/px*S);g.strokeStyle='#f0c850';g.lineWidth=3;g.strokeRect((a-x0)/px*S,(b-z0)/px*S,(d-a)/px*S,(e-b)/px*S);g.font='bold 26px sans-serif';g.fillStyle='#fff';g.strokeStyle='#000';g.lineWidth=5;const tx=((a+d)/2-x0)/px*S,ty=(b-z0)/px*S-10;g.strokeText(t.nome,tx,ty);g.fillText(t.nome,tx,ty)}
  g.fillStyle='#fff';g.beginPath();g.arc(sx*S,sy*S,13,0,7);g.fill();
  for(const k of marcas){const X=(k.x-x0)/px*S,Y=(k.z-z0)/px*S,rr=(k.r||8)*1.7;g.fillStyle=k.cor;g.strokeStyle='#fff';g.lineWidth=3;g.beginPath();g.arc(X,Y,rr,0,7);g.fill();g.stroke();g.fillStyle='#fff';g.font='bold '+Math.round(rr*1.2)+'px sans-serif';g.fillText(k.nome,X,Y+rr*.42)}
  // ilhas: chão ou alto livres que não se alcançam, dentro da cripta (ignora o lado de fora, que toca a borda)
  const seen=new Uint8Array(W*H),ilhas=[];for(let i=0;i<W*H;i++){if(M[i]||A[i]||seen[i])continue;let n=0,cx=0,cy=0,fora=false;const q=[i];seen[i]=1;while(q.length){const j=q.pop(),jx=j%W,jy=(j/W)|0;n++;cx+=jx;cy+=jy;if(jx===0||jy===0||jx===W-1||jy===H-1)fora=true;for(const [dx,dy] of[[1,0],[-1,0],[0,1],[0,-1]]){const xx=jx+dx,yy=jy+dy;if(xx<0||yy<0||xx>=W||yy>=H)continue;const k=yy*W+xx;if(seen[k]||M[k]||A[k])continue;seen[k]=1;q.push(k)}}
    if(!fora&&n*px*px>.4)ilhas.push({m2:+(n*px*px).toFixed(2),x:+(x0+cx/n*px).toFixed(1),z:+(z0+cy/n*px).toFixed(1)})}
  return {png:c.toDataURL('image/png'),area,px,raio,inicio,gatilhos,alto,chao_m2:+(a0*px*px).toFixed(1),alto_m2:+(a1*px*px).toFixed(1),ilhas,retangulos:ret,solidos,visao}}
