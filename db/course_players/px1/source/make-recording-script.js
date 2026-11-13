// Regenerates ../../RECORDING-SCRIPT.md from content.js. Run: node make-recording-script.js
const path=require('path');global.window={};require(path.join(__dirname,'content.js'));
const C=window.COURSE,strip=s=>s.replace(/<[^>]+>/g,'');
let o='# Recording script (draft 2, generated from course-player/source/content.js)\n\nRecord from this. It is generated from the course player, so the video and the player always match. After editing content.js, run `node make-recording-script.js` in course-player/source. Read the steps in your own words; type every prompt on screen exactly as written. Stay nameless on camera: screen and voice only.\n\nBefore every Cowork lesson (3 to 8), the student pastes the start line: "Before you do anything in this folder, read CLAUDE.md and follow it."\n';
for(const l of C.lessons){o+='\n---\n\n## '+(l.n?'Lesson '+l.n:'Welcome')+'. '+l.title+' ('+l.mins+' min)\n\n**Leave with:** '+l.leave+'\n\n**Cold open (Walt):** "'+l.walt+'"\n\n**Big idea, '+l.idea.title+':** '+l.idea.text+'\n\n';let n=0;
 for(const s of l.steps){if(s.k=='start'){o+=(++n)+'. Start here: choose Cowork, pick the thunder-otters folder, paste the start line.\n';continue}
  if(s.k=='note'){o+='   - Note: '+strip(s.text)+'\n';continue}
  o+=(++n)+'. '+strip(s.text)+'\n';if(s.prompt)o+='\n   > '+s.prompt.replace(/\n/g,'\n   > ')+'\n\n';
  if(s.k=='quiz1')o+='   (Pause: viewer works it out. Answer '+s.answer+'%.)\n';if(s.cos)o+='   [CHECK ON SCREEN: '+s.cos+']\n';}
 o+='\n**Check:** '+l.check+'\n';if(l.breaks.length){o+='\n**If it breaks:**\n';for(const b of l.breaks)o+='- '+b[0]+' '+b[1]+'\n'}
 o+="\n**Lead's Edge, "+l.edge.title+':** '+l.edge.body+' Try this: '+l.edge.try+'\n'}
require('fs').writeFileSync(path.join(__dirname,'..','..','RECORDING-SCRIPT.md'),o);console.log('wrote',o.length);
