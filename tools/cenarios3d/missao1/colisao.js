// Mapa de colisão tirado da própria cena: corte horizontal entre 15 cm e 1,75 m do piso, visto de cima.
// Tudo que tem volume nessa faixa bloqueia; portas ficam livres. Depois engorda os bloqueios pelo raio do personagem
// e pinta o que dá para alcançar a partir do ponto de entrada.
import * as THREE from 'three';
export function colisao(K,{area,inicio,piso=0,raio=.3,px=.1,gatilhos=[],baixo=.15}){
  const [x0,z0,x1,z1]=area,W=Math.round((x1-x0)/px),H=Math.round((z1-z0)/px),sc=K.sc;
  const esc=[];sc.traverse(o=>{let hide=false;if(o.isSprite||o.isLight)hide=o.isSprite;if(o.userData.fantasma||o.userData.porta||o.userData.agente)hide=true;
    if(o.isMesh){const ms=Array.isArray(o.material)?o.material:[o.material];if(ms.every(m=>m.transparent||m.alphaTest>0||m.blending===THREE.AdditiveBlending||m.colorWrite===false))hide=true}
    if(hide&&o.visible){o.visible=false;esc.push(o)}});
  const cam=new THREE.OrthographicCamera(-(x1-x0)/2,(x1-x0)/2,(z1-z0)/2,-(z1-z0)/2,0,1.75-baixo);cam.position.set((x0+x1)/2,piso+1.75,(z0+z1)/2);cam.up.set(0,0,-1);cam.lookAt((x0+x1)/2,piso,(z0+z1)/2);
  const rt=new THREE.WebGLRenderTarget(W,H);const bg=sc.background,fog=sc.fog;sc.background=new THREE.Color(0xffffff);sc.fog=null;
  // Paredes inteiras, colunas e móveis altos atravessam a câmera do corte: de cima só se veem as faces laterais, de perfil,
  // e eles sumiam do mapa (13/11: paredes do fundo da delegacia e da biblioteca não bloqueavam). Caixas e cilindros em pé
  // que cruzam o topo do corte são achatados para dentro da faixa, então o topo deles aparece com a seção exata.
  const PRETO=new THREE.MeshBasicMaterial({color:0,side:THREE.DoubleSide}),lo=piso+baixo,hi=piso+1.74;
  const ACHATA=new THREE.ShaderMaterial({side:THREE.DoubleSide,uniforms:{lo:{value:lo},hi:{value:hi}},vertexShader:'uniform float lo,hi;void main(){vec4 w=modelMatrix*vec4(position,1.);w.y=clamp(w.y,lo,hi);gl_Position=projectionMatrix*viewMatrix*w;}',fragmentShader:'void main(){gl_FragColor=vec4(0.,0.,0.,1.);}'});
  const troca=[],bb=new THREE.Box3(),up=new THREE.Vector3();sc.updateMatrixWorld(true);
  sc.traverse(o=>{if(!o.isMesh)return;troca.push([o,o.material]);const t=o.geometry&&o.geometry.type;let m=PRETO;
    if(t==='BoxGeometry'||t==='CylinderGeometry'){bb.setFromObject(o);up.set(0,1,0).transformDirection(o.matrixWorld);if(bb.max.y>hi&&bb.min.y<hi&&Math.abs(up.y)>.999)m=ACHATA}
    o.material=m});
  K.rr.setRenderTarget(rt);K.rr.render(sc,cam);const buf=new Uint8Array(W*H*4);K.rr.readRenderTargetPixels(rt,0,0,W,H,buf);K.rr.setRenderTarget(null);
  troca.forEach(([o,m])=>o.material=m);sc.background=bg;sc.fog=fog;esc.forEach(o=>o.visible=true);
  // grade: linha 0 = z0 (a leitura do GL vem de baixo para cima)
  const B=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++)B[y*W+x]=buf[((H-1-y)*W+x)*4]<128?1:0;
  const r=Math.round(raio/px),M=new Uint8Array(W*H);for(let y=0;y<H;y++)for(let x=0;x<W;x++){if(!B[y*W+x])continue;for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(dx*dx+dy*dy>r*r)continue;const xx=x+dx,yy=y+dy;if(xx>=0&&yy>=0&&xx<W&&yy<H)M[yy*W+xx]=1}}
  const A=new Uint8Array(W*H);const sx=Math.round((inicio[0]-x0)/px),sy=Math.round((inicio[1]-z0)/px);const st=[[sx,sy]];if(!M[sy*W+sx])A[sy*W+sx]=1;
  while(st.length){const [x,y]=st.pop();for(const [dx,dy] of[[1,0],[-1,0],[0,1],[0,-1]]){const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=W||yy>=H)continue;const i=yy*W+xx;if(M[i]||A[i])continue;A[i]=1;st.push([xx,yy])}}
  // ilhas: áreas livres que não se alcançam
  const seen=new Uint8Array(W*H),ilhas=[];for(let i=0;i<W*H;i++){if(M[i]||A[i]||seen[i])continue;let n=0,cx=0,cy=0;const q=[i];seen[i]=1;while(q.length){const j=q.pop();n++;cx+=j%W;cy+=(j/W)|0;for(const d of[1,-1,W,-W]){const k=j+d;if(k<0||k>=W*H||seen[k]||M[k]||A[k])continue;if((d===1||d===-1)&&((k/W)|0)!==((j/W)|0))continue;seen[k]=1;q.push(k)}}
    if(n*px*px>.4)ilhas.push({m2:+(n*px*px).toFixed(2),x:+(x0+cx/n*px).toFixed(1),z:+(z0+cy/n*px).toFixed(1)})}
  // retângulos de bloqueio (faixas por linha, unidas na vertical)
  const ret=[];let abertos=new Map();for(let y=0;y<=H;y++){const runs=new Map();if(y<H){let x=0;while(x<W){if(B[y*W+x]){let e=x;while(e<W&&B[y*W+e])e++;runs.set(x+'_'+e,[x,e]);x=e}else x++}}
    for(const [k,v] of abertos){if(!runs.has(k)){ret.push([+(x0+v[0]*px).toFixed(2),+(z0+v[2]*px).toFixed(2),+((v[1]-v[0])*px).toFixed(2),+((y-v[2])*px).toFixed(2)]);abertos.delete(k)}}
    for(const [k,v] of runs)if(!abertos.has(k))abertos.set(k,[v[0],v[1],y])}
  // desenho
  const S=6,c=document.createElement('canvas');c.width=W*S;c.height=H*S;const g=c.getContext('2d');g.fillStyle='#14161a';g.fillRect(0,0,c.width,c.height);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;g.fillStyle=B[i]?'#c0483c':M[i]?'#5a3a34':A[i]?'#2f6a52':'#8a7a2a';g.fillRect(x*S,y*S,S,S)}
  g.strokeStyle='rgba(255,255,255,.10)';g.lineWidth=1;for(let m=Math.ceil(x0);m<x1;m++){g.beginPath();g.moveTo((m-x0)/px*S,0);g.lineTo((m-x0)/px*S,c.height);g.stroke()}for(let m=Math.ceil(z0);m<z1;m++){g.beginPath();g.moveTo(0,(m-z0)/px*S);g.lineTo(c.width,(m-z0)/px*S);g.stroke()}
  g.font='bold 15px sans-serif';g.textAlign='center';for(const t of gatilhos){const [a,b,d,e]=t.ret;g.fillStyle='rgba(240,200,80,.5)';g.fillRect((a-x0)/px*S,(b-z0)/px*S,(d-a)/px*S,(e-b)/px*S);g.strokeStyle='#f0c850';g.lineWidth=2;g.strokeRect((a-x0)/px*S,(b-z0)/px*S,(d-a)/px*S,(e-b)/px*S);g.fillStyle='#fff';g.fillText(t.nome,((a+d)/2-x0)/px*S,((b+e)/2-z0)/px*S+5)}
  g.fillStyle='#fff';g.beginPath();g.arc(sx*S,sy*S,7,0,7);g.fill();
  let livre=0,alc=0;for(let i=0;i<W*H;i++){if(!M[i])livre++;if(A[i])alc++}
  return {png:c.toDataURL('image/png'),area,px,piso,raio,inicio,gatilhos,livre_m2:+(livre*px*px).toFixed(1),alcancavel_m2:+(alc*px*px).toFixed(1),ilhas,retangulos:ret}}
