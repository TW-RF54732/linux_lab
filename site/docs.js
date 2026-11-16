// 指令區塊的「複製」按鈕。沒有 JavaScript 時按鈕保持隱藏，指令仍可直接選取。
(() => {
  'use strict';
  const content = document.querySelector('[data-copied-label]');
  if (!content || !navigator.clipboard?.writeText) return;
  content.querySelectorAll('.guide-command').forEach(panel => {
    const button = panel.querySelector('.copy-command');
    const code = panel.querySelector('code');
    const status = panel.querySelector('.copy-status');
    button.hidden = false;
    button.addEventListener('click', async () => {
      button.disabled = true;
      status.textContent = '';
      try {
        await navigator.clipboard.writeText(code.textContent);
        status.textContent = content.dataset.copiedLabel;
      } catch {
        status.textContent = content.dataset.copyFailed;
      } finally {
        button.disabled = false;
      }
    });
  });
})();
