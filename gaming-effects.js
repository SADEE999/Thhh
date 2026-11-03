/* SADEE PRO STORE — lightweight gaming experience enhancements */
(()=>{'use strict';
 const $=(s,r=document)=>r.querySelector(s), $$=(s,r=document)=>[...r.querySelectorAll(s)];
 const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 const toast=$('#gaming-toast');let toastTimer;
 function notify(message){if(!toast)return;toast.textContent=message;toast.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.classList.remove('show'),2600)}
 // 1-4: branded boot screen, progress animation, safe timeout, reduced-motion support
 const boot=$('#boot-screen'),bootBar=$('#boot-progress'),bootPct=$('#boot-percent'),bootStatus=$('#boot-status');
 let bootValue=0;const bootTimer=setInterval(()=>{bootValue=Math.min(100,bootValue+(bootValue<70?7:bootValue<92?3:1));if(bootBar)bootBar.style.width=bootValue+'%';if(bootPct)bootPct.textContent=bootValue+'%';if(bootValue>=100){clearInterval(bootTimer);if(bootStatus)bootStatus.textContent='SADEE XDIMA // SYSTEM READY';}},reduced?20:55);
 const finishBoot=()=>{if(boot){bootValue=100;if(bootBar)bootBar.style.width='100%';if(bootPct)bootPct.textContent='100%';boot.classList.add('boot-done');clearInterval(bootTimer)}};
 window.addEventListener('load',()=>setTimeout(finishBoot,reduced?0:900));setTimeout(finishBoot,5000);
 // 5: reading progress bar
 const progress=$('#reading-progress');let ticking=false;
 function scrollFX(){const max=document.documentElement.scrollHeight-innerHeight; if(progress)progress.style.width=(max>0?scrollY/max*100:0)+'%';$('#back-top')?.classList.toggle('visible',scrollY>500);ticking=false}
 addEventListener('scroll',()=>{if(!ticking){requestAnimationFrame(scrollFX);ticking=true}},{passive:true});scrollFX();
 // 6: reveal-on-scroll for content blocks
 const revealTargets=$$('.section,.how-section,.support-banner,.product-card,.steps article');revealTargets.forEach(el=>el.classList.add('reveal-ready'));
 if('IntersectionObserver'in window&&!reduced){const io=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting){e.target.classList.add('revealed');io.unobserve(e.target)}}),{threshold:.08});revealTargets.forEach(el=>io.observe(el))}else revealTargets.forEach(el=>el.classList.add('revealed'));
 // 7: back-to-top
 $('#back-top')?.addEventListener('click',()=>scrollTo({top:0,behavior:reduced?'auto':'smooth'}));
 // 8: keyboard shortcut / to focus search; 9: Escape clears search when not in modal
 addEventListener('keydown',e=>{if(e.key==='/'&&!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)){e.preventDefault();$('#search')?.focus()}if(e.key==='Escape'&&document.activeElement===$('#search')){$('#search').value='';$('#search').dispatchEvent(new Event('input',{bubbles:true}));$('#search').blur()}});
 // 10: subtle pointer glow, disabled on touch/reduced motion
 if(!reduced&&matchMedia('(pointer:fine)').matches){addEventListener('pointermove',e=>{document.documentElement.style.setProperty('--pointer-x',e.clientX+'px');document.documentElement.style.setProperty('--pointer-y',e.clientY+'px')},{passive:true})}
 // 11: card tilt on desktop
 if(!reduced&&matchMedia('(pointer:fine)').matches){document.addEventListener('pointermove',e=>{const card=e.target.closest('.product-card');if(!card)return;const r=card.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;card.style.setProperty('--tilt-x',(-y*2)+'deg');card.style.setProperty('--tilt-y',(x*2)+'deg')});document.addEventListener('pointerout',e=>{const c=e.target.closest?.('.product-card');if(c){c.style.setProperty('--tilt-x','0deg');c.style.setProperty('--tilt-y','0deg')}})}
 // 12: ripple feedback for buttons
 document.addEventListener('click',e=>{const b=e.target.closest('button,.btn,.order-btn');if(!b||reduced)return;const r=b.getBoundingClientRect(),dot=document.createElement('i');dot.className='tap-ripple';dot.style.left=(e.clientX-r.left)+'px';dot.style.top=(e.clientY-r.top)+'px';b.append(dot);setTimeout(()=>dot.remove(),650)});
 // 13: image lazy loading and 14: async decoding
 $$('img').forEach(img=>{if(!img.hasAttribute('fetchpriority'))img.loading='lazy';img.decoding='async'});
 // 15: current year fallback
 const year=$('#year');if(year&&!year.textContent.trim())year.textContent=new Date().getFullYear();
 // 16-17: connection status feedback
 addEventListener('offline',()=>notify('Connection lost — check your internet connection.'));addEventListener('online',()=>notify('Connection restored.'));
 // 18: active navigation marker
 const navLinks=$$('header nav a[href^="#"]');if('IntersectionObserver'in window){const sections=navLinks.map(a=>$(a.getAttribute('href'))).filter(Boolean);const navIO=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting)navLinks.forEach(a=>a.classList.toggle('nav-current',a.hash==='#'+e.target.id))}),{rootMargin:'-25% 0px -65% 0px'});sections.forEach(s=>navIO.observe(s))}
 // 19: product grid loading state enhancement
 const grid=$('#product-grid');if(grid){const mo=new MutationObserver(()=>$$('.product-card',grid).forEach(c=>c.classList.add('card-ready')));mo.observe(grid,{childList:true})}
 // 20: animated live system indicator
 const live=$$('.live-dot,.footer-status i');live.forEach(el=>el.classList.add('pulse-live'));
 // 21: focus-visible keyboard accessibility
 document.addEventListener('keydown',e=>{if(e.key==='Tab')document.body.classList.add('keyboard-mode')});document.addEventListener('pointerdown',()=>document.body.classList.remove('keyboard-mode'));
 // 22: prevent accidental double-submit visual feedback (native form logic remains intact)
 $$('form').forEach(f=>f.addEventListener('submit',()=>f.classList.add('form-processing')));
 // 23: page fade-in
 requestAnimationFrame(()=>document.body.classList.add('page-ready'));
 // 24: smooth anchor navigation with sticky-header offset
 document.addEventListener('click',e=>{const a=e.target.closest('a[href^="#"]');if(!a)return;const target=$(a.getAttribute('href'));if(target){e.preventDefault();target.scrollIntoView({behavior:reduced?'auto':'smooth',block:'start'})}});
 // 25: live clock label in system caption
 const caption=$('.hero-caption span');if(caption){const base=caption.textContent;const update=()=>{const d=new Date();caption.textContent=base+' // '+d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})};update();setInterval(update,60000)}
 // 26: hero parallax depth, desktop only
 const hero=$('#hero-art');if(hero&&!reduced&&matchMedia('(pointer:fine)').matches){hero.addEventListener('pointermove',e=>{const r=hero.getBoundingClientRect();hero.style.setProperty('--hero-x',((e.clientX-r.left)/r.width-.5)*10+'px');hero.style.setProperty('--hero-y',((e.clientY-r.top)/r.height-.5)*10+'px')});hero.addEventListener('pointerleave',()=>{hero.style.setProperty('--hero-x','0px');hero.style.setProperty('--hero-y','0px')})}
 // 27: product count indicator via existing rendered catalog
 if(grid){const count=new MutationObserver(()=>{const n=$$('.product-card',grid).length;grid.dataset.itemCount=String(n)});count.observe(grid,{childList:true})}
 // 28: copy-friendly order status links get a confirmation toast when copied
 document.addEventListener('click',e=>{if(e.target.closest('#copy-new-order'))setTimeout(()=>notify('Order code copied when clipboard access is available.'),50)});
 // 29: modal body scroll lock safety on escape remains in store.js; add focus hint
 const modal=$('#product-modal');if(modal){const obs=new MutationObserver(()=>{if(!modal.hidden)modal.querySelector('input,select,button')?.focus({preventScroll:true})});obs.observe(modal,{attributes:true,attributeFilter:['hidden']})}
 // 30: installable app hint only when browser supports PWA install prompt (no intrusive popup)
 let installPrompt=null;addEventListener('beforeinstallprompt',e=>{e.preventDefault();installPrompt=e;document.documentElement.classList.add('pwa-install-available')});
 // 31: reduced-motion class and 32: theme metadata synchronization
 if(reduced)document.documentElement.classList.add('reduced-motion');document.documentElement.style.colorScheme='dark';
 // 33: accessible external links
 $$('a[target="_blank"]').forEach(a=>{if(!a.rel.includes('noopener'))a.rel=(a.rel+' noopener noreferrer').trim()});
 // 34: no-JS-safe interaction status announcement
 if(!navigator.onLine)notify('You appear to be offline.');
})();
