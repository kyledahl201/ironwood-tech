import sys,base64,os
d=sys.argv[1]
hub=os.path.join(d,'..','..','reference-hub')
s=open(d+'/shell.html').read()
s=s.replace('.scroll{overflow-x:auto}','.scroll{overflow-x:auto}\n.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}')
biscuit='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120"><title>Biscuit the dog</title><circle cx="60" cy="60" r="58" fill="#1C2B4D"/><ellipse cx="60" cy="68" rx="32" ry="28" fill="#D9B48A"/><ellipse cx="30" cy="52" rx="13" ry="24" fill="#8C5727" transform="rotate(12 30 52)"/><ellipse cx="90" cy="52" rx="13" ry="24" fill="#8C5727" transform="rotate(-12 90 52)"/><circle cx="48" cy="62" r="5" fill="#14213D"/><circle cx="72" cy="62" r="5" fill="#14213D"/><circle cx="50" cy="60" r="1.6" fill="#fff"/><circle cx="74" cy="60" r="1.6" fill="#fff"/><ellipse cx="60" cy="78" rx="8" ry="6" fill="#14213D"/><path d="M52 88 Q60 96 68 88" stroke="#14213D" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M58 92 q2 10 6 8 q3-2 0-10" fill="#9B2335"/><rect x="38" y="96" width="44" height="8" rx="4" fill="#B87333"/><circle cx="60" cy="106" r="5" fill="#E8B84A"/></svg>'
assets=open(d+'/assets.js').read()+'\nwindow.ASSETS.biscuit="data:image/svg+xml;base64,'+base64.b64encode(biscuit.encode()).decode()+'";\n'
data=''.join(open(os.path.join(hub,f)).read()+'\n' for f in ['schedule.js','meals.js','budget.js'])
s=s.replace('/*ASSETS*/',assets+'\n'+data).replace('/*CONTENT*/',open(d+'/content.js').read())
open(d+'/../index.html','w').write(s)
full='<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n'+s+'\n</body>\n</html>\n'
open(d+'/../Open me - course player.html','w').write(full)
print(len(s))
