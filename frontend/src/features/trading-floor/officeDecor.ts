import { iso, Point, layoutScene } from './sceneGeometry';
/** Original Handliv furnishings; same vector plan in Canvas and native SVG. */
export type OfficeShape =
 | {type:'poly';points:Point[];fill:string;stroke?:string;tag:string}
 | {type:'rect';x:number;y:number;width:number;height:number;radius:number;fill:string;tag:string}
 | {type:'ellipse';x:number;y:number;rx:number;ry:number;fill:string;tag:string}
 | {type:'line';a:Point;b:Point;stroke:string;width:number;tag:string}
 | {type:'text';x:number;y:number;text:string;size:number;fill:string;tag:string};
export function officeShapes(layout:ReturnType<typeof layoutScene>):OfficeShape[]{
 const shapes:OfficeShape[]=[];
 const poly=(points:Point[],fill:string,tag:string,stroke?:string)=>shapes.push({type:'poly',points,fill,tag,stroke});
 const rect=(x:number,y:number,width:number,height:number,fill:string,tag:string,radius=4)=>shapes.push({type:'rect',x,y,width,height,fill,tag,radius});
 const ellipse=(x:number,y:number,rx:number,ry:number,fill:string,tag:string)=>shapes.push({type:'ellipse',x,y,rx,ry,fill,tag});
 const line=(a:Point,b:Point,stroke:string,tag:string,width=2)=>shapes.push({type:'line',a,b,stroke,tag,width});
 const text=(value:string,x:number,y:number,fill:string,tag:string,size=14)=>shapes.push({type:'text',text:value,x,y,fill,tag,size});
 for(const room of layout.rooms){
  const {x,y,width:w,height:h}=room;
  poly([iso(x+5,y+5),iso(x+w-5,y+5),iso(x+w-5,y+h-5),iso(x+5,y+h-5)],['#2B302E','#233647','#243C38','#302C43','#29313D'][layout.rooms.indexOf(room)],'room',room.color);
  const label=iso(x+w/2,y+30);
  rect(label.x-74,label.y-82,148,28,'#0C192A','room-label',7);
  text(room.kind,label.x-64,label.y-62,room.color,'room-label',17);
  if(!room.members.length){const p=iso(x+w/2,y+125);text('SEM ESTAÇÕES',p.x-48,p.y,'#7E91A9','room-label',10);}
  const door=iso(x+w/2,y+h);
  line(iso(x+w/2-52,y+h),iso(x+w/2+52,y+h),room.color,'door',5);
  text('ENTRADA',door.x-24,door.y+17,'#9EAFBD','door',8);
 }
 // Low glass walls leave people, desktops and doors readable at fit zoom.
 for(const wall of layout.walls){
  const a=iso(wall.a.x,wall.a.y),b=iso(wall.b.x,wall.b.y);
  poly([a,b,{x:b.x,y:b.y-54},{x:a.x,y:a.y-54}],'#314557','partition','#698497');
  line({x:a.x,y:a.y-54},{x:b.x,y:b.y-54},'#ABC5CB','partition',3);
  line(a,{x:a.x,y:a.y-54},'#748E9E','partition',3);
 }
 for(const prop of layout.decorations){const {x,y}=prop;
  if(prop.kind==='plant'){
   ellipse(x,y+4,22,9,'#0D1C28','plant');rect(x-12,y-19,24,27,'#C39D72','plant',5);
   line({x,y:y-12},{x,y:y-62},'#648C58','plant',4);
   for(const [dx,dy] of [[-15,-42],[15,-49],[-10,-64],[10,-68]])ellipse(x+dx,y+dy,14,9,'#438568','plant');
  }else{
   rect(x-34,y-74,68,76,'#B9926D','bookcase',3);rect(x-29,y-69,58,65,'#273141','bookcase',1);
   for(let row=0;row<3;row++){rect(x-30,y-50+row*22,60,4,'#B9926D','bookcase',0);for(let i=0;i<6;i++)rect(x-25+i*9,y-67+row*22,6,17,['#4D8B86','#A7796B','#6D80A8','#C6B086'][i%4],'bookcase',1);}
  }
 }
 for(const area of layout.amenities){
  const p=iso(area.gridX,area.gridY-10);
  poly([iso(area.gridX-145,area.gridY-75),iso(area.gridX+145,area.gridY-75),iso(area.gridX+145,area.gridY+80),iso(area.gridX-145,area.gridY+80)],area.kind==='coffee'?'#705947':area.kind==='meeting'?'#3A4F63':'#425959','rug','#758483');
  const lamp={x:p.x+120,y:p.y-14};ellipse(lamp.x,lamp.y+30,15,6,'#192E3A','lamp');line({x:lamp.x,y:lamp.y+25},{x:lamp.x,y:lamp.y-55},'#A6A199','lamp',3);poly([{x:lamp.x-20,y:lamp.y-60},{x:lamp.x+20,y:lamp.y-60},{x:lamp.x+13,y:lamp.y-83},{x:lamp.x-13,y:lamp.y-83}],'#E7C894','lamp');
 }
 const lounge=layout.lounge;
 rect(lounge.x-115,lounge.y+12,165,50,'#172A39','sofa',12);rect(lounge.x-115,lounge.y-7,165,27,'#5B7D84','sofa',10);
 for(let i=0;i<3;i++)rect(lounge.x-99+i*46,lounge.y+13,41,23,'#7FA0A0','sofa',6);
 rect(lounge.x-122,lounge.y+4,18,43,'#466B75','sofa',6);rect(lounge.x+42,lounge.y+4,18,43,'#466B75','sofa',6);
 text('LOUNGE • PAUSA',lounge.x-91,lounge.y+74,'#ABC9C5','sofa',12);
 const dog=layout.dogHome;ellipse(dog.x,dog.y+14,37,19,'#BC916E','dog-bed');ellipse(dog.x,dog.y+11,28,12,'#D9B898','dog-bed');ellipse(dog.x+50,dog.y+19,10,5,'#91A7B2','dog-bed');
 text('DOG LOUNGE',dog.x-40,dog.y+45,'#DAB693','dog-bed',10);
 const meeting=layout.amenities[2];
 rect(meeting.x-88,meeting.y-120,176,53,'#AEBDC3','classroom',5);rect(meeting.x-81,meeting.y-114,162,40,'#223D4B','classroom',2);
 text('SALA DE REUNIÃO / AULA',meeting.x-73,meeting.y-93,'#B6D6D9','classroom',10);
 const note=iso(layout.worldWidth/2,layout.corridorY);
 text('CIRCULAÇÃO • ANIMAÇÃO VISUAL, NÃO TELEMETRIA',note.x-140,note.y+5,'#A3B4C5','notice',11);
 return [...shapes.filter(s=>s.tag!=='room-label'),...shapes.filter(s=>s.tag==='room-label')];
}
