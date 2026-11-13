const {chromium}=require('playwright');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:900}});
const errs=[];p.on('pageerror',e=>errs.push(e.message));p.on('console',m=>{if(m.type()==='error')errs.push(m.text())});
const F='file://'+__dirname+'/../Open me - course player.html';const O=process.argv[2]||__dirname;
await p.goto(F);await p.waitForTimeout(800);await p.screenshot({path:O+'/s-home.png',fullPage:true});
for(const h of ['lesson-0','lesson-4','lesson-7','lesson-11','lesson-12','lesson-14','prompts','help']){await p.evaluate(x=>location.hash=x,h);await p.waitForTimeout(300);await p.screenshot({path:O+'/s-'+h+'.png',fullPage:['lesson-0','lesson-4'].includes(h)});}
await p.evaluate(()=>location.hash='lesson-6');await p.waitForTimeout(200);
await p.fill('input[data-ans]','$500');await p.click('[data-yt]');console.log('yt:',await p.textContent('.fb'));
await p.evaluate(()=>location.hash='lesson-4');await p.waitForTimeout(200);
await p.fill('input[data-ans]','2');await p.click('[data-yt]');console.log('yt4:',await p.textContent('.fb'));
await p.click('.q[data-q="0"] .opt[data-o="1"]');console.log('quiz:',await p.textContent('#qscore'));
await p.click('#markdone');console.log('done:',await p.textContent('#markdone'));
await p.evaluate(()=>location.hash='lesson-0');await p.waitForTimeout(200);await p.click('.mdin >> nth=1');console.log('recipe:',(await p.textContent('.mrec')).slice(0,60));
const m=await b.newPage({viewport:{width:390,height:844}});await m.goto(F+'#lesson-0');await m.waitForTimeout(600);
console.log('mobile overflow:',await m.evaluate(()=>document.documentElement.scrollWidth));await m.screenshot({path:O+'/m-l0.png',fullPage:true});
await m.goto(F+'#home');await m.waitForTimeout(400);console.log('mobile home overflow:',await m.evaluate(()=>document.documentElement.scrollWidth));
console.log('errors:',errs);await b.close();})();
