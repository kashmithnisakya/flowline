/* Flowline boot, inlined into <head> from jac.toml before the bundle: paints the
   saved theme on <html> and, on app paths with a session, a header and page
   placeholder before #root that pages/layout.jac removes on first paint. */
(function(){
var d=document,h=d.documentElement;
function g(k){try{return localStorage.getItem(k)}catch(e){}}
var t=g('flowline-theme')||g('standup-theme');
var dark=t=='dark'||t!='light'&&matchMedia('(prefers-color-scheme:dark)').matches;
var bg=dark?'#111413':'#F2F3F1';
if(dark)h.className+=' dark';
h.style.colorScheme=dark?'dark':'light';h.style.backgroundColor=bg;
if(/^\/(login|auth\/callback|setup)?$/.test(location.pathname)||!g('jac_token'))return;
var s=dark?'#191D1B':'#FFFFFF',l=dark?'#2D3330':'#D3D8D2',k=dark?'#1E2220':'#DEDFDD';
var c='#flowline-boot i{background:'+k+';border-radius:4px}.bm,.ba,.bo,.bn,.bd,.bq,.bt,.bl{display:block}'
+'.bh{display:flex;align-items:center;gap:2px;height:47px;padding:0 16px;background:'+s+';border-bottom:1px solid '+l+'}'
+'.bm,.ba{border-radius:50%}.bm{width:20px;height:20px;margin-right:8px}.ba{width:24px;height:24px;margin:0 4px}'
+'.bo{width:112px;height:14px;margin-right:12px}.bn{height:12px;margin:0 10px}.bd{width:1px;height:20px;margin:0 8px;background:'+l+'}'
+'.br{margin-left:auto;display:flex;align-items:center;gap:6px}.bq{width:65px;height:28px;border:1px solid '+l+';background:'+bg+'}'
+'.bo,.bd,.bs{display:none}'
+'.bp{padding:24px 16px}.bt{width:104px;height:24px;margin:6px 0 24px}.bl{height:14px;margin-bottom:14px}'
+'@media(max-width:639px){.bn,.bq{display:none}.bo{display:block;width:72px}}'
+'@media(min-width:640px){.bp{padding:24px}}'
+'@media(min-width:1024px){.bh{padding:0 20px}.bo,.bd,.bs{display:block}.bx{display:none}.bp{padding:32px 40px}}';
function n(x,y){return '<i class="bn '+(y||'')+'" style="width:'+x+'px"></i>'}
var e=d.createElement('div');e.id='flowline-boot';
e.innerHTML='<style>'+c+'</style><div class="bh"><i class="bm"></i><i class="bo"></i>'
+n(36)+n(34)+n(57)+n(20)+n(55)+n(48,'bx')+'<i class="bd"></i>'+n(51,'bs')+n(63,'bs')+n(40,'bs')
+'<div class="br"><i class="bq"></i>'+n(50)+'<i class="ba"></i></div></div>'
+'<div class="bp"><i class="bt"></i><i class="bl" style="width:42%"></i><i class="bl" style="width:58%"></i><i class="bl" style="width:36%"></i></div>';
var o=new MutationObserver(f);
function f(){var r=d.getElementById('root');if(r){o.disconnect();r.parentNode.insertBefore(e,r)}}
o.observe(h,{childList:true,subtree:true});f();
})();
