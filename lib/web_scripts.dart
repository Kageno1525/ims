class WebScripts {
  WebScripts._();

  static const fillLogin = r'''
(function(){
  try {
    var U = %USER%, P = %PASS%;
    var root = document.querySelector('#app') || document;
    var u = root.querySelector('input[type=text]') || root.querySelector('input[type=email]');
    var p = root.querySelector('input[type=password]');
    var b = root.querySelector('button[type=submit]') || root.querySelector('form button') || root.querySelector('button');
    if (!u || !p || !b) return 'not-ready';
    var setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(u), 'value').set
              || Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    function fire(el, val){
      el.focus();
      try { setter.call(el, val); } catch(e){ el.value = val; }
      ['input','change','keyup','blur'].forEach(function(ev){
        el.dispatchEvent(new Event(ev, {bubbles:true}));
      });
    }
    fire(u, U); fire(p, P);
    setTimeout(function(){ try{ b.click(); }catch(e){} }, 120);
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const diag = r'''
(function(){
  try {
    var url = location.href;
    var inputs = document.querySelectorAll('input').length;
    var buttons = document.querySelectorAll('button').length;
    var stats = document.querySelectorAll('.cstat-value').length;
    return [url, inputs, buttons, stats].join('|');
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const readStats = r'''
(function(){
  try {
    var els = document.querySelectorAll('.cstat-value');
    if (els.length >= 2) {
      var t = (els[0].innerText || '').trim();
      var w = (els[1].innerText || '').trim();
      return 'ok|' + t + '|' + w;
    }
    return 'no';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  // ═══════ Blob/CSV interception ═══════
  static const blobCapture = r'''
(function(){
  try {
    window.__imsBlobContent = null;
    window.__imsDownloadName = '';

    var origCreate = URL.createObjectURL;
    if (origCreate){
      URL.createObjectURL = function(blob){
        var url = origCreate.call(URL, blob);
        try {
          var reader = new FileReader();
          reader.onload = function(){ window.__imsBlobContent = reader.result; };
          reader.readAsText(blob);
        } catch(e){}
        return url;
      };
    }

    var origClick = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function(){
      try { if (this.download) window.__imsDownloadName = this.download; } catch(e){}
      return origClick.apply(this, arguments);
    };

    var origXOpen = XMLHttpRequest.prototype.open;
    var origXSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(m,u){ this.__imsUrl = u; return origXOpen.apply(this, arguments); };
    XMLHttpRequest.prototype.send = function(){
      var self = this;
      this.addEventListener('load', function(){
        try {
          var cd = self.getResponseHeader('content-disposition') || '';
          var ct = self.getResponseHeader('content-type') || '';
          if (ct.indexOf('csv') >= 0 || cd.toLowerCase().indexOf('.csv') >= 0){
            window.__imsBlobContent = self.responseText;
            var m = cd.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
            if (m) window.__imsDownloadName = m[1].replace(/['"]/g,'');
          }
        } catch(e){}
      });
      return origXSend.apply(this, arguments);
    };

    var origFetch = window.fetch;
    if (origFetch){
      window.fetch = function(){
        return origFetch.apply(this, arguments).then(function(resp){
          try {
            var ct = resp.headers.get('content-type') || '';
            var cd = resp.headers.get('content-disposition') || '';
            if (ct.indexOf('csv') >= 0 || cd.toLowerCase().indexOf('.csv') >= 0){
              var clone = resp.clone();
              clone.text().then(function(txt){
                window.__imsBlobContent = txt;
                var m = cd.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
                if (m) window.__imsDownloadName = m[1].replace(/['"]/g,'');
              });
            }
          } catch(e){}
          return resp;
        });
      };
    }
  } catch(e){}
})();
''';

  // ═══════ Ranges ═══════
  static const openRanges = r'''
(function(){
  try {
    var btn = document.querySelector('#app > div > div > main > div > div:nth-child(2) > form > div > div:nth-child(1) > div > button');
    if (!btn) {
      var form = document.querySelector('form');
      if (form){
        var all = form.querySelectorAll('button');
        for (var i=0;i<all.length;i++){
          if (all[i].type !== 'submit'){ btn = all[i]; break; }
        }
      }
    }
    if (!btn) return 'no-btn';
    btn.click();
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const isRangeDropdownOpen = r'''
(function(){ return document.querySelector('.ss-pop') ? 'yes' : 'no'; })()
''';

  static const readRanges = r'''
(function(){
  try {
    var items = document.querySelectorAll('.ss-pop .ss-item, .ss-list .ss-item');
    var arr = [];
    items.forEach(function(li){
      if (li.querySelector('.ss-clear')){ arr.push('All ranges'); return; }
      var s = li.querySelector('span');
      var t = s ? (s.innerText || s.textContent || '').trim() : '';
      if (t) arr.push(t);
    });
    return JSON.stringify(arr);
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const readRangeButton = r'''
(function(){
  try {
    var btn = document.querySelector('#app > div > div > main > div > div:nth-child(2) > form > div > div:nth-child(1) > div > button');
    if (!btn) return '';
    return (btn.innerText || btn.textContent || '').trim();
  } catch(e){ return ''; }
})()
''';

  static const selectRange = r'''
(function(){
  try {
    var name = %NAME%;
    var items = document.querySelectorAll('.ss-item');
    for (var i=0;i<items.length;i++){
      var isAll = !!items[i].querySelector('.ss-clear');
      var s = items[i].querySelector('span');
      var t = isAll ? 'All ranges' : (s ? (s.innerText||'').trim() : '');
      if (t !== name) continue;
      var el = items[i];
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width/2;
      var cy = r.top + r.height/2;
      var dn = {bubbles:true, cancelable:true, view:window, clientX:cx, clientY:cy, button:0, buttons:1};
      var up = {bubbles:true, cancelable:true, view:window, clientX:cx, clientY:cy, button:0, buttons:0};
      try { el.dispatchEvent(new PointerEvent('pointerdown', dn)); } catch(e){}
      try { el.dispatchEvent(new MouseEvent('mousedown', dn)); } catch(e){}
      try { el.dispatchEvent(new PointerEvent('pointerup', up)); } catch(e){}
      try { el.dispatchEvent(new MouseEvent('mouseup', up)); } catch(e){}
      try { el.dispatchEvent(new MouseEvent('click', up)); } catch(e){}
      return 'ok';
    }
    return 'not-found';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  // ═══════ Selects — الحل الشامل ═══════
  /// ضبط قوي جدًا على الـ selects باستخدام كل الطرق الممكنة
  static const setFilters = r'''
(function(){
  try {
    var count = String(%COUNT%);
    var type  = String(%TYPE%);
    var log = [];

    var SEL_COUNT = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-records > label > select';
    var SEL_TYPE  = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-lead > label > select';

    function findSelect(primarySel, requiredVals){
      var el = document.querySelector(primarySel);
      if (el && el.tagName === 'SELECT'){
        var ok = true;
        for (var i=0;i<requiredVals.length;i++){
          var f = false;
          for (var j=0;j<el.options.length;j++){
            if (String(el.options[j].value) === String(requiredVals[i])){ f = true; break; }
          }
          if (!f){ ok = false; break; }
        }
        if (ok) return el;
      }
      var all = document.querySelectorAll('select');
      for (var k=0;k<all.length;k++){
        var ok2 = true;
        for (var m=0;m<requiredVals.length;m++){
          var f2 = false;
          for (var n=0;n<all[k].options.length;n++){
            if (String(all[k].options[n].value) === String(requiredVals[m])){ f2 = true; break; }
          }
          if (!f2){ ok2 = false; break; }
        }
        if (ok2) return all[k];
      }
      return null;
    }

    function forceSelect(el, val){
      if (!el) return {ok:false, log:'no-el'};
      val = String(val);
      var det = [];

      var optIndex = -1;
      for (var k=0;k<el.options.length;k++){
        if (String(el.options[k].value) === val){ optIndex = k; break; }
      }
      if (optIndex < 0) return {ok:false, log:'no-opt'};

      det.push('idx=' + optIndex);

      // 1) focus
      try { el.focus(); } catch(e){}

      // 2) Native setter selectedIndex
      try {
        Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'selectedIndex').set.call(el, optIndex);
        det.push('iset');
      } catch(e){ det.push('iset!'); }

      // 3) Native setter value
      try {
        Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(el, val);
        det.push('vset');
      } catch(e){ det.push('vset!'); }

      // 4) تأكيد يدوي
      for (var m=0;m<el.options.length;m++){
        el.options[m].selected = (m === optIndex);
        el.options[m].removeAttribute('selected');
      }
      el.options[optIndex].setAttribute('selected','');
      el.selectedIndex = optIndex;
      el.value = val;

      // 5) click على option
      try { el.options[optIndex].click(); } catch(e){}

      // 6) كل أنواع الأحداث
      var fired = [];
      function tryFire(ev, name){
        try { el.dispatchEvent(ev); fired.push(name); } catch(e){}
      }
      tryFire(new Event('focus', {bubbles:true}), 'focus');
      tryFire(new Event('input', {bubbles:true, cancelable:true}), 'input');
      tryFire(new Event('change', {bubbles:true, cancelable:true}), 'change');
      try { tryFire(new UIEvent('change', {bubbles:true, cancelable:true}), 'UIchg'); } catch(e){}
      try { tryFire(new InputEvent('input', {bubbles:true, cancelable:true, data:val, inputType:'insertText'}), 'IEinp'); } catch(e){}
      tryFire(new Event('blur', {bubbles:true}), 'blur');
      tryFire(new Event('focusout', {bubbles:true}), 'focusout');

      // 7) KeyboardEnter
      try {
        ['keydown','keypress','keyup'].forEach(function(t){
          var e = new KeyboardEvent(t, {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true, cancelable:true});
          el.dispatchEvent(e);
        });
        fired.push('kbd');
      } catch(e){}

      try { el.blur(); } catch(e){}

      det.push('fired=' + fired.length);
      det.push('now=' + String(el.value));

      return {ok:true, log:det.join(',')};
    }

    var cSel = findSelect(SEL_COUNT, ['5000','1000','10']);
    var tSel = findSelect(SEL_TYPE, ['full','local']);

    log.push('cSel=' + (cSel?'y':'n'));
    log.push('tSel=' + (tSel?'y':'n'));

    if (cSel){ var rC = forceSelect(cSel, count); log.push('C[' + rC.log + ']'); }
    if (tSel){ var rT = forceSelect(tSel, type);  log.push('T[' + rT.log + ']'); }

    // خزّن للتحقق لاحقاً
    window.__imsFilterCheck = {
      wantC: count,
      wantT: type,
      cIdx: (cSel ? cSel.selectedIndex : -1),
      tIdx: (tSel ? tSel.selectedIndex : -1)
    };

    return 'ok|cSel=' + (cSel?1:0) + '|tSel=' + (tSel?1:0) + '|| ' + log.join(' || ');
  } catch(e){ return 'err:' + e.message; }
})()
''';

  /// يقرأ القيم الحقيقية من الصفحة (بعد ما Vue يعمل re-render)
  static const verifyFilters = r'''
(function(){
  try {
    var SEL_COUNT = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-records > label > select';
    var SEL_TYPE  = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-lead > label > select';

    function findSelect(primarySel, requiredVals){
      var el = document.querySelector(primarySel);
      if (el && el.tagName === 'SELECT'){
        var ok = true;
        for (var i=0;i<requiredVals.length;i++){
          var f = false;
          for (var j=0;j<el.options.length;j++){
            if (String(el.options[j].value) === String(requiredVals[i])){ f = true; break; }
          }
          if (!f){ ok = false; break; }
        }
        if (ok) return el;
      }
      var all = document.querySelectorAll('select');
      for (var k=0;k<all.length;k++){
        var ok2 = true;
        for (var m=0;m<requiredVals.length;m++){
          var f2 = false;
          for (var n=0;n<all[k].options.length;n++){
            if (String(all[k].options[n].value) === String(requiredVals[m])){ f2 = true; break; }
          }
          if (!f2){ ok2 = false; break; }
        }
        if (ok2) return all[k];
      }
      return null;
    }

    var cSel = findSelect(SEL_COUNT, ['5000','1000','10']);
    var tSel = findSelect(SEL_TYPE, ['full','local']);
    var w = window.__imsFilterCheck || {};

    return JSON.stringify({
      c: cSel ? String(cSel.value) : null,
      t: tSel ? String(tSel.value) : null,
      wantC: w.wantC || null,
      wantT: w.wantT || null
    });
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const clickFilter = r'''
(function(){
  try {
    var f = document.querySelector('#app > div > div > main > div > div:nth-child(2) > form button[type=submit]')
         || document.querySelector('button.btn-danger');
    if (!f){
      var btns = document.querySelectorAll('button');
      for (var i=0;i<btns.length;i++){
        var t = (btns[i].innerText||'').trim().toLowerCase();
        if (t === 'filter'){ f = btns[i]; break; }
      }
    }
    if (!f) return 'no-filter';
    f.click();
    return 'ok';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const clickCsv = r'''
(function(){
  try {
    var btns = document.querySelectorAll('button');
    for (var i=0;i<btns.length;i++){
      if ((btns[i].innerText||'').trim().toUpperCase() === 'CSV'){
        if (btns[i].disabled) return 'disabled';
        btns[i].click();
        return 'ok';
      }
    }
    return 'no-csv';
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const readBlob = r'''
(function(){
  try {
    if (window.__imsBlobContent == null) return 'no-blob';
    return JSON.stringify({
      name: window.__imsDownloadName || '',
      content: window.__imsBlobContent
    });
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const clearBlob = r'''
(function(){ window.__imsBlobContent=null; window.__imsDownloadName=""; return 'ok'; })()
''';
}