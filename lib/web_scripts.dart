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

  // ═══════ Selects — حل Vue 3 reactivity ═══════
  static const setFilters = r'''
(function(){
  try {
    var count = '%COUNT%';
    var type  = '%TYPE%';
    var log = [];

    var SEL_COUNT = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-records > label > select';
    var SEL_TYPE  = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-lead > label > select';

    function findSelect(primarySel, requiredVals){
      var el = document.querySelector(primarySel);
      if (el && el.tagName === 'SELECT') return el;
      var all = document.querySelectorAll('select');
      for (var k=0; k<all.length; k++){
        var ok = true;
        for (var m=0; m<requiredVals.length; m++){
          var f = false;
          for (var n=0; n<all[k].options.length; n++){
            if (String(all[k].options[n].value) === String(requiredVals[m])){ f = true; break; }
          }
          if (!f){ ok = false; break; }
        }
        if (ok) return all[k];
      }
      return null;
    }

    function applyVueSelect(el, targetVal){
      if (!el) return 'no-el';
      targetVal = String(targetVal);

      var idx = -1;
      for (var i = 0; i < el.options.length; i++) {
        if (String(el.options[i].value) === targetVal) {
          idx = i;
          break;
        }
      }
      if (idx === -1) return 'no-opt';

      // 1) Set HTML native index
      el.selectedIndex = idx;

      // 2) Break Vue/React descriptor overrides
      try {
        var setter = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set;
        setter.call(el, targetVal);
      } catch(e) {
        el.value = targetVal;
      }

      // 3) Vue internal value store
      try { el._value = targetVal; } catch(e){}

      // 4) Dispatch Events for Vue v-model listener
      ['focus', 'input', 'change', 'blur'].forEach(function(evtName){
        var ev;
        try {
          ev = new Event(evtName, { bubbles: true, cancelable: true });
        } catch(e) {
          ev = document.createEvent('HTMLEvents');
          ev.initEvent(evtName, true, true);
        }
        el.dispatchEvent(ev);
      });

      // 5) Direct VNode handler trigger fallback
      try {
        var vnode = el.__vnode || el._vnode;
        if (vnode && vnode.props) {
          if (typeof vnode.props.onChange === 'function') vnode.props.onChange({ target: el, currentTarget: el });
          if (typeof vnode.props['onUpdate:modelValue'] === 'function') vnode.props['onUpdate:modelValue'](targetVal);
        }
      } catch(e){}

      return 'ok:' + targetVal;
    }

    var cSel = findSelect(SEL_COUNT, ['5000','1000','10']);
    var tSel = findSelect(SEL_TYPE, ['full','local']);

    if (cSel) log.push('Count[' + applyVueSelect(cSel, count) + ']');
    if (tSel) log.push('Type[' + applyVueSelect(tSel, type) + ']');

    window.__imsFilterCheck = {wantC: count, wantT: type};

    return 'ok|| ' + log.join(' || ');
  } catch(e){ return 'err:' + e.message; }
})()
''';

  static const verifyFilters = r'''
(function(){
  try {
    var SEL_COUNT = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-records > label > select';
    var SEL_TYPE  = '#app > div > div > main > div > div:nth-child(2) > div.card > div.classic-toolbar > div:nth-child(1) > div.classic-toolbar-lead > label > select';

    function findSelect(primarySel, requiredVals){
      var el = document.querySelector(primarySel);
      if (el && el.tagName === 'SELECT') return el;
      var all = document.querySelectorAll('select');
      for (var k=0;k<all.length;k++){
        var ok = true;
        for (var m=0;m<requiredVals.length;m++){
          var f = false;
          for (var n=0;n<all[k].options.length;n++){
            if (String(all[k].options[n].value) === String(requiredVals[m])){ f = true; break; }
          }
          if (!f){ ok = false; break; }
        }
        if (ok) return all[k];
      }
      return null;
    }

    var cSel = findSelect(SEL_COUNT, ['5000','1000','10']);
    var tSel = findSelect(SEL_TYPE, ['full','local']);
    var w = window.__imsFilterCheck || {};

    return JSON.stringify({
      c: cSel ? String(cSel.value) : null,
      t: tSel ? String(tSel.value) : null,
      cText: cSel && cSel.selectedIndex >= 0 ? String(cSel.options[cSel.selectedIndex].text).trim() : null,
      tText: tSel && tSel.selectedIndex >= 0 ? String(tSel.options[tSel.selectedIndex].text).trim() : null,
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
