// typewriter.js — 原生可调用的渲染接口 + 打字机 + 高度回传
(function (global) {
  'use strict';

  var contentEl = function () { return document.getElementById('content'); };
  var fullText = '';      // 当前完整 Markdown 文本
  var shownLen = 0;       // 已"打字"显示到的字符数
  var timer = null;
  var STEP = 2;           // 每帧推进字符数
  var INTERVAL = 16;      // ms

  function reportHeight() {
    var h = document.body.scrollHeight;
    if (global.webkit && global.webkit.messageHandlers && global.webkit.messageHandlers.heightHandler) {
      global.webkit.messageHandlers.heightHandler.postMessage(h);
    }
  }

  function renderNow(text, cursor) {
    var html = global.STMarkdown.render(text);
    contentEl().innerHTML = html;
    contentEl().className = cursor ? 'tw-cursor' : '';
    reportHeight();
  }

  // 直接整段渲染（历史消息、非打字机）
  function setMarkdown(md) {
    stopTypewriter();
    fullText = md || '';
    shownLen = fullText.length;
    renderNow(fullText, false);
  }

  // 设定目标全文并启动打字机（从当前已显示处推进到全文）
  function typeTo(md) {
    fullText = md || '';
    if (shownLen > fullText.length) { shownLen = 0; }
    startTypewriter();
  }

  function startTypewriter() {
    if (timer) return;
    timer = setInterval(function () {
      if (shownLen >= fullText.length) {
        stopTypewriter();
        renderNow(fullText, false);
        return;
      }
      shownLen = Math.min(fullText.length, shownLen + STEP);
      renderNow(fullText.slice(0, shownLen), true);
    }, INTERVAL);
  }

  function stopTypewriter() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  // 立即完成打字机（直接显示全文）
  function finishTypewriter() {
    stopTypewriter();
    shownLen = fullText.length;
    renderNow(fullText, false);
  }

  global.STBubble = {
    setMarkdown: setMarkdown,
    typeTo: typeTo,
    finish: finishTypewriter,
    reportHeight: reportHeight
  };
})(window);
