// iOS transport for the unchanged Android renderer and lazy grammar modules.
// Keep this a classic script: module-load failures must reach native UI too.
(() => {
  const notify = payload => window.webkit?.messageHandlers?.codePreview?.postMessage({
    ...payload, loadID: window.codePreviewLoadID,
  });
  let failed = false;
  function fail(reason) {
    if (failed) return;
    failed = true;
    notify({ type: 'error', message: `Code preview: ${reason?.message ?? String(reason)}` });
  }
  window.addEventListener('error', event => {
    fail(event.error ?? event.message ?? `Unable to load ${event.target?.src ?? 'resource'}`);
  }, true);
  window.addEventListener('unhandledrejection', event => fail(event.reason));
  document.addEventListener('securitypolicyviolation', event => {
    fail(`Blocked ${event.violatedDirective}: ${event.blockedURI}`);
  });
  import('./preview.js').then(() => {
    if (failed) return;
    if (!window.codePreview || !document.getElementById('code')) {
      throw new Error('Renderer did not initialize.');
    }
    Object.defineProperty(window, 'codePreviewBridge', {
      value: {
        ack() {
          if (failed) throw new Error('Renderer failed; reload required.');
          const code = document.getElementById('code');
          return { ready: true, textLength: code.textContent.length };
        },
      },
      writable: false,
    });
    notify({ type: 'ready' });
  }).catch(fail);
})();
