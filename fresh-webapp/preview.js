(() => {
  'use strict';
  const devices = { iphone:[393,852], 'iphone-small':[375,667], ipad:[820,1180], 'ipad-pro':[1024,1366] };
  const device = document.querySelector('#device');
  const zoom = document.querySelector('#zoom');
  const frame = document.querySelector('#device-frame');
  const space = document.querySelector('#frame-space');
  const stage = document.querySelector('#preview-stage');
  const iframe = document.querySelector('#app-preview');
  let landscape = false;
  function resize() {
    let [width,height] = devices[device.value];
    if (landscape) [width,height] = [height,width];
    const border = device.value.startsWith('ipad') ? 18 : 12;
    const outerWidth = width + border * 2;
    const outerHeight = height + border * 2;
    const scale = zoom.value === 'fit'
      ? Math.min(1, Math.max(0.1,(stage.clientWidth - 36) / outerWidth), Math.max(0.1,(stage.clientHeight - 36) / outerHeight))
      : Number(zoom.value);
    frame.style.width = outerWidth + 'px';
    frame.style.height = outerHeight + 'px';
    frame.style.padding = border + 'px';
    frame.style.borderRadius = device.value.startsWith('ipad') ? '34px' : '46px';
    frame.style.transform = 'scale(' + scale + ')';
    iframe.style.width = width + 'px';
    iframe.style.height = height + 'px';
    iframe.style.borderRadius = device.value.startsWith('ipad') ? '18px' : '34px';
    space.style.width = outerWidth * scale + 'px';
    space.style.height = outerHeight * scale + 'px';
    document.querySelector('#dimensions').textContent = width + ' × ' + height + ' CSS pixels · ' + Math.round(scale * 100) + '%';
  }
  device.addEventListener('change', resize);
  zoom.addEventListener('change', resize);
  document.querySelector('#rotate').addEventListener('click', () => { landscape = !landscape; resize(); });
  window.addEventListener('resize', resize);
  resize();
})();
