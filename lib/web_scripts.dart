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

  // ═══════ Selects (Vue 3) — النسخة القوية ═══════
  static const setFilters = r'''
(function(){
  try {
    var count = String(%COUNT%);
    var type  = String(%TYPE%);
    var cOk = 0, tOk = 0;
    var info = [];

    var SEL_COUNT = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-records > label > select';
    var SEL_TYPE  = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-lead > label > select';

    function hasVals(sel, requiredVals){
      if (!sel || sel.tagName !== 'SELECT') return false;
      for (var k=0;k<requiredVals.length;k++){
        var found = false;
        for (var j=0;j<sel.options.length;j++){
          if (String(sel.options[j].value) === String(requiredVals[k])) { found = true; break; }
        }
        if (!found) return false;
      }
      return true;
    }

    function pick(primarySel, requiredVals){
      // 1) السليكتور الدقيق
      var el = document.querySelector(primarySel);
      if (hasVals(el, requiredVals)) return el;
      // 2) fallback: أول select فيه القيم دي
      var all = document.querySelectorAll('select');
      for (var i=0;i<all.length;i++){
        if (hasVals(all[i], requiredVals)) return all[i];
      }
      return null;
    }

    function setVal(el, val){
      if (!el) return false;
      val = String(val);

      // 1) focus
      try { el.focus(); } catch(e){}

      // 2) native setter على selectedIndex (الأقوى مع Vue)
      var idx = -1;
      for (var k=0;k<el.options.length;k++){
        if (String(el.options[k].value) === val){ idx = k; break; }
      }
      if (idx < 0) return false;

      try {
        var idxSetter = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'selectedIndex').set;
        idxSetter.call(el, idx);
      } catch(e){ el.selectedIndex = idx; }

      // 3) native setter على value
      try {
        var vSetter = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set;
        vSetter.call(el, val);
      } catch(e){ el.value = val; }

      // 4) تأكيد يدوي
      for (var m=0;m<el.options.length;m++){
        el.options[m].selected = (m === idx);
      }
      try { el.selectedIndex = idx; } catch(e){}

      // 5) أحداث بالشكل اللي Vue بيعترف بيه
      try { el.dispatchEvent(new Event('focus', {bubbles:true})); } catch(e){}
      try { el.dispatchEvent(new Event('input', {bubbles:true, cancelable:true})); } catch(e){}
      try { el.dispatchEvent(new Event('change', {bubbles:true, cancelable:true})); } catch(e){}
      try { el.dispatchEvent(new UIEvent('change', {bubbles:true})); } catch(e){}
      try { el.dispatchEvent(new Event('blur', {bubbles:true})); } catch(e){}
      try { el.dispatchEvent(new Event('focusout', {bubbles:true})); } catch(e){}
      try { el.blur(); } catch(e){}

      return String(el.value) === val;
    }

    var cSel = pick(SEL_COUNT, ['5000','1000','10','500']);
    var tSel = pick(SEL_TYPE,  ['full','local']);

    info.push('cSel=' + (cSel ? 'yes' : 'no'));
    info.push('tSel=' + (tSel ? 'yes' : 'no'));

    if (cSel) { cOk = setVal(cSel, count) ? 1 : 0; info.push('cVal=' + cSel.value + '|cReq=' + count); }
    if (tSel) { tOk = setVal(tSel, type)  ? 1 : 0; info.push('tVal=' + tSel.value + '|tReq=' + type); }

    return 'ok|c=' + cOk + '|t=' + tOk + '|' + info.join(',');
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