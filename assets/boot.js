/* Flowline boot (inlined into <head> from jac.toml, before the bundle):
   theme on <html>, an Archivo preload, an app-path placeholder
   that pages/layout.jac removes on first paint. */
(function(){
var d=document,h=d.documentElement;
function g(k){try{return localStorage.getItem(k)}catch(e){}}
var t=g('flowline-theme')||g('standup-theme');
var dark=t=='dark'||t!='light'&&matchMedia('(prefers-color-scheme:dark)').matches;
var bg=dark?'#111413':'#F2F3F1';
if(dark)h.className+=' dark';
h.style.colorScheme=dark?'dark':'light';h.style.backgroundColor=bg;
d.head.insertAdjacentHTML('beforeend','<link rel=preload as=font crossorigin href=/archivo-latin-wdth-normal.woff2>');
if(/^\/(login|auth\/callback|setup)?$/.test(location.pathname)||!g('jac_token'))return;
var s=dark?'#191D1B':'#fff',l=dark?'#2D3330':'#D3D8D2',k=dark?'#1E2220':'#DEDFDD';
var c='.bm,.ba,.bo,.bn,.bd,.bq,.bt,.bl{display:block;background:'+k+';border-radius:4px}.bh{display:flex;align-items:center;gap:2px;height:47px;padding:0 16px;background:'+s+';border-bottom:1px solid '+l+'}'
+'.bm,.ba{border-radius:50%}.bm{width:20px;height:20px;margin-right:8px}.ba{width:24px;height:24px;margin:0 4px}.bo{width:112px;height:14px;margin-right:12px}.bn{height:12px;margin:0 10px}.bd{width:1px;height:20px;margin:0 8px;background:'+l+'}'
+'.br{margin-left:auto;display:flex;align-items:center;gap:6px}.bq{width:65px;height:28px;border:1px solid '+l+';background:'+bg+'}.bo,.bd,.bs{display:none}.bp{padding:24px 16px}.bt{width:104px;height:24px;margin:6px 0 24px}.bl{height:14px;margin-bottom:14px}'
+'@media(max-width:639px){.bn{display:none}.bo{display:block;width:72px}.bq{width:20px;height:20px;margin:10px;border:0;background:'+k+'}}@media(min-width:640px){.bp{padding:24px}}'
+'@media(min-width:1024px){.bh{padding:0 20px}.bo,.bd,.bs{display:block}.bx{display:none}.bp{padding:32px 40px}}';
function n(x,y){return '<i class="bn '+(y||'')+'"style=width:'+x+'px></i>'}
function b(w){return '<i class=bl style=width:'+w+'%></i>'}
var e=d.createElement('div');e.id='flowline-boot';
e.innerHTML='<style>'+c+'</style><div class=bh><i class=bm></i><i class=bo></i>'
+n(36)+n(34)+n(57)+n(20)+n(55)+n(48,'bx')+'<i class=bd></i>'+n(51,'bs')+n(63,'bs')+n(40,'bs')
+'<div class=br><i class=bq></i>'+n(50)+'<i class=ba></i></div></div><div class=bp><i class=bt></i>'+b(42)+b(58)+b(36)+'</div>';
var o=new MutationObserver(p);
function p(){if(d.body){o.disconnect();d.body.prepend(e)}}
o.observe(h,{childList:!0,subtree:!0});p();
})();
