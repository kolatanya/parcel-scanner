/* shared: one copy helper with visible feedback */
window.EFCopy=(function(){
  var el=null;
  function toast(text){
    if(!el){ el=document.createElement('div'); el.className='toast'; document.body.appendChild(el); }
    el.innerHTML='<span class="tick">\u2713</span>'+text;
    void el.offsetWidth; el.classList.add('on');
    clearTimeout(el._t); el._t=setTimeout(function(){ el.classList.remove('on'); },1700);
  }
  function beep(){
    try{ var a=new (window.AudioContext||window.webkitAudioContext)(),o=a.createOscillator(),g=a.createGain();
      o.connect(g);g.connect(a.destination);o.frequency.value=880;o.type='sine';
      g.gain.setValueAtTime(.05,a.currentTime);g.gain.exponentialRampToValueAtTime(.0001,a.currentTime+.09);
      o.start();o.stop(a.currentTime+.09);
    }catch(e){}
  }
  function fallback(t){
    var ta=document.createElement('textarea'); ta.value=t; ta.style.position='fixed'; ta.style.opacity='0';
    document.body.appendChild(ta); ta.select(); ta.setSelectionRange(0,99999);
    var ok=false; try{ ok=document.execCommand('copy'); }catch(e){}
    document.body.removeChild(ta); return ok;
  }
  /* copy(text, label, button) -> promise<boolean> */
  return function(text,label,btn){
    var done=function(ok){
      if(ok){
        toast(label||'Copied');
        beep();
        try{ navigator.vibrate&&navigator.vibrate(18); }catch(e){}
        if(btn){ btn.classList.remove('copied'); void btn.offsetWidth; btn.classList.add('copied'); }
      }
      return ok;
    };
    if(navigator.clipboard&&navigator.clipboard.writeText){
      return navigator.clipboard.writeText(text).then(function(){return done(true);},function(){return done(fallback(text));});
    }
    return Promise.resolve(done(fallback(text)));
  };
})();
