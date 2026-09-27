export interface InterfaceSettings {
  quality?: string;
  weather?: string;
  time?: string;
  volume?: number;
  diagnostics?: boolean;
}

export interface InterfaceStats {
  fps: number;
  frameMs: number;
  drawCalls: number;
  triangles: number;
  gpuMs: number | null;
  memoryMB: number | null;
  geometries: number;
  textures: number;
  backend: string;
}

interface Callbacks {
  onEnter(): void;
  onExit(): void;
  onBenchmark(): void;
  onSettingsChange(settings: InterfaceSettings): void;
  onPause(paused: boolean): void;
  onInventory?(): void;
  onUseItem?(itemId: string): void;
  onNewJourney?(seed?:number): void;
  onMap?():void;
}

export interface PlayerInterfaceState {
  stamina: number;
  locomotion: string;
  grounded: boolean;
  crouched: boolean;
  objective: string;
  objectiveDetail: string;
  interactLabel: string | null;
  saveStatus?: string;
}

export interface InventoryInterfaceItem {
  id: string;
  name: string;
  description: string;
  count: number;
  usable: boolean;
}

interface BenchmarkResult {
  avgFps: number;
  p1Fps: number;
  avgFrameMs: number;
  frames: number;
  context?: string;
}

const arrow = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 12h15M13 5l7 7-7 7" stroke="currentColor" stroke-width="1.5"/></svg>';
const closeIcon = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m6 6 12 12M6 18 18 6" stroke="currentColor" stroke-width="1.4"/></svg>';
const mark = '<svg viewBox="0 0 36 38" fill="none" aria-hidden="true"><path d="M3 34 17.5 4 32 34h-8l-6.5-14L11 34H3Z" stroke="currentColor" stroke-width="2.4"/><path d="m20 4 13 28M8 23h18" stroke="currentColor" stroke-width="1.4"/><path d="M4 37h27" stroke="currentColor"/></svg>';
const settingsIcon = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 17h16M9 4v6M15 14v6" stroke="currentColor" stroke-width="1.4"/></svg>';
const speakerIcon = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M11 5 6 9H3v6h3l5 4V5ZM15 8c2 2 2 6 0 8M18 5c4 4 4 10 0 14" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"/></svg>';

const map = `<svg class="district-map" viewBox="0 0 238 137" fill="none" role="img" aria-label="Schematic map of Financial District, Sector 07. Observation point at the central junction.">
  <defs><pattern id="af-map-grid" width="19" height="19" patternUnits="userSpaceOnUse"><path d="M19 0H0v19" stroke="currentColor" stroke-opacity=".055" stroke-width=".7"/></pattern></defs>
  <path fill="url(#af-map-grid)" d="M0 0h238v137H0z"/>
  <g fill="currentColor" fill-opacity=".1" stroke="currentColor" stroke-opacity=".19" stroke-width=".65">
    <path d="M4 12h32v20H4zM45 12h24v20H45zM80 8h37v24H80zM128 4h37v28h-37zM181 11h45v21h-45zM5 42h20v29H5zM35 43h34v28H35zM82 44h29v28H82zM128 44h37v28h-37zM180 44h20v28h-20zM210 44h21v28h-21zM4 88h32v37H4zM47 89h23v29H47zM82 88h29v38H82zM129 88h35v38h-35zM180 88h21v35h-21zM211 89h20v40h-20z"/>
  </g>
  <g stroke="currentColor" stroke-opacity=".33" stroke-width="1"><path d="M0 37h238M0 79h238M75 0v137M120 0v137M172 0v137"/><path d="M0 81h238M174 0v137" stroke-opacity=".12"/></g>
  <path d="M228 10v15m-3-12 3-3 3 3" stroke="currentColor" stroke-opacity=".65" stroke-width=".8"/><text x="225.5" y="7" fill="currentColor" fill-opacity=".65" font-size="6">N</text>
  <circle cx="121" cy="79" r="18" fill="#ff6846" fill-opacity=".035" stroke="#ff6846" stroke-opacity=".28" stroke-dasharray="2 3"/>
  <circle cx="121" cy="79" r="5" stroke="#ff6846" stroke-opacity=".45"/>
  <path d="m121 74 3.7 8-3.7-1.6-3.7 1.6 3.7-8Z" fill="#ff6846"/>
  <path d="M140 63h17m-17 0-7 8" stroke="#ff6846" stroke-opacity=".8" stroke-width=".7"/><text x="160" y="65" fill="#ff6846" font-size="6" letter-spacing="1">YOU</text>
</svg>`;

export function createInterface(callbacks: Callbacks) {
  const mount = document.querySelector<HTMLDivElement>('#ui');
  if (!mount) throw new Error('Missing #ui mount.');
  mount.innerHTML = `
    <div class="af-interface is-loading">
      <div class="cinematic-shade" aria-hidden="true"></div>
      <header class="topbar">
        <button class="brand" type="button" data-action="home" aria-label="Afterfall, return to experience">${mark}<span>AFTERFALL<span class="brand-sub">AN OPEN WORLD. LEFT BEHIND.</span></span></button>
        <nav class="main-nav" aria-label="Main navigation">
          <button class="nav-item is-current" type="button" data-action="home">Experience<span class="nav-index">01</span></button>
          <button class="nav-item" type="button" data-action="notes">Field notes<span class="nav-index">02</span></button>
          <button class="nav-item" type="button" data-action="settings">System${settingsIcon}</button>
        </nav>
      </header>
      <main class="showcase-content">
        <div class="chapter-label"><span class="tiny-cross">+</span> A WORLD THAT CARRIES ON <span class="chapter-number">/ 001</span></div>
        <h1 class="wordmark">AFTERFALL<span class="title-period">.</span></h1>
        <p class="wordmark-caption">SURVIVAL IS ONLY THE BEGINNING</p>
        <div class="intro-copy">
          <div class="eyebrow"><span class="signal-dot"></span> DECCAN REGION, INDIA</div>
          <h2>Some things survive<br>the end of the world.</h2>
          <p>The city went quiet. Life found a way.<br>Step into a world that never stopped moving.</p>
          <div class="entry-actions">
            <button class="enter-button" type="button" data-action="enter" disabled><span>Enter the district</span>${arrow}</button>
            <button class="benchmark-button" type="button" data-action="benchmark" disabled><span class="benchmark-glyph">⌁</span><span>Run benchmark<small>30 SECOND PERFORMANCE TEST</small></span></button>
          </div>
          <p class="entry-disclaimer">PROCEDURAL OPEN WORLD <span>·</span> A JOURNEY THROUGH SECTOR 07</p>
        </div>
      </main>
      <aside class="scene-caption" aria-label="Environment information">
        <span class="caption-rule"></span><span class="eyebrow">SECTOR 07 <span>/</span> FINANCIAL DISTRICT</span>
        <span class="scene-description">The world belongs to no one now.</span>
      </aside>
      <aside class="location-panel">
        <div class="map-heading"><span>YOUR NEXT CHAPTER</span><span>17.44° N &nbsp; 78.35° E</span></div>
        ${map}
        <div class="map-caption"><span class="signal-dot"></span><span>Financial district</span><span class="sector-code">S—07</span></div>
      </aside>
      <footer class="bottom-bar">
        <div class="build-meta"><span class="version-label">PRE-ALPHA</span><span>PHASE 2 <i>—</i> PROCEDURAL OPEN WORLD</span></div>
        <div class="footer-tools"><button type="button" class="sound-button" data-action="sound" aria-label="Mute atmosphere" title="Mute atmosphere">${speakerIcon}<span class="sound-state">SOUND ON</span></button><span class="performance-live"><span class="signal-dot"></span><span data-stat="fps">—</span><span>FPS</span></span><span class="renderer-name">INITIALIZING</span></div>
      </footer>
      <div class="explore-overlay" hidden>
        <div class="explore-location"><span class="eyebrow"><span class="explore-role">SURVIVOR</span> <span class="orange">/</span> SECTOR 07</span><strong>Financial district</strong><span class="save-status" role="status"></span></div>
        <div class="camera-crosshair" aria-hidden="true"></div>
        <div class="survivor-hud">
          <aside class="journey-objective" aria-label="Current objective"><span class="eyebrow">THE WAY THROUGH</span><strong data-player="objective">Find supplies</strong><p data-player="objectiveDetail">Look for the field supplies near the entrance.</p></aside>
          <div class="physical-state" hidden><span data-player="physical"></span><div class="stamina-track" role="meter" aria-label="Stamina" aria-valuemin="0" aria-valuemax="100" aria-valuenow="100"><span></span></div></div>
          <div class="interact-prompt" role="status" hidden><kbd>E</kbd><span data-player="interact"></span></div>
          <div class="world-clock"></div><div class="world-compass" aria-label="Heading"></div><canvas class="world-minimap" width="300" height="300" aria-label="Nearby roads, buildings, shelters and lakes"></canvas>
          <div class="survivor-actions"><button type="button" data-action="map" aria-keyshortcuts="m"><kbd>M</kbd> Map</button><button type="button" data-action="inventory" aria-keyshortcuts="i"><kbd>I</kbd> Pack</button><button type="button" data-action="help" aria-keyshortcuts="h" aria-expanded="true"><kbd>H</kbd> Controls</button><button type="button" data-action="exit" aria-keyshortcuts="Escape"><kbd>Esc</kbd> Menu</button></div>
          <div class="explore-controls" aria-label="Movement controls"><span><kbd>W A S D</kbd> Move</span><span><kbd>SHIFT</kbd> Sprint</span><span><kbd>C</kbd> Crouch</span><span><kbd>SPACE</kbd> Jump / climb</span><span><kbd>E</kbd> Interact</span><span><kbd>F</kbd> Torch</span><span>Drag to look</span></div>
        </div>
        <div class="inspection-controls"><span class="signal-dot"></span> INSPECTION ROUTE <span>Performance capture in progress</span><button type="button" data-action="exit"><kbd>Esc</kbd> Cancel</button></div>
      </div>
      <section class="diagnostics" aria-label="Live renderer diagnostics" hidden>
        <div class="diagnostics-title">RENDER DIAGNOSTICS <span class="signal-dot"></span></div>
        <dl><div><dt>Frame time</dt><dd data-stat="frameMs">—</dd></div><div><dt>GPU time</dt><dd data-stat="gpuMs">—</dd></div><div><dt>Draw calls</dt><dd data-stat="drawCalls">—</dd></div><div><dt>Triangles</dt><dd data-stat="triangles">—</dd></div><div><dt>JS heap</dt><dd data-stat="memoryMB">—</dd></div><div><dt>Geometries</dt><dd data-stat="geometries">—</dd></div><div><dt>Textures</dt><dd data-stat="textures">—</dd></div></dl>
      </section>
      <section class="benchmark-panel" aria-live="polite" aria-label="Benchmark" hidden></section>
      <div class="af-toast" role="status" hidden></div>
      <div class="loading-screen" aria-live="polite"><div class="loading-mark">${mark}</div><span class="loading-title">A WORLD, LEFT BEHIND.</span><span class="loading-line"></span><span class="loading-description">BUILDING THE DISTRICT</span></div>
      <div class="dialog-backdrop" hidden><section class="af-dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" tabindex="-1"></section></div>
    </div>`;

  const root = mount.querySelector<HTMLDivElement>('.af-interface')!;
  const dialogBackdrop = mount.querySelector<HTMLDivElement>('.dialog-backdrop')!;
  const dialog = mount.querySelector<HTMLElement>('.af-dialog')!;
  const benchmarkPanel = mount.querySelector<HTMLElement>('.benchmark-panel')!;
  const diagnosticsPanel = mount.querySelector<HTMLElement>('.diagnostics')!;
  const enterButton = mount.querySelector<HTMLButtonElement>('[data-action="enter"]')!;
  const benchmarkButton = mount.querySelector<HTMLButtonElement>('[data-action="benchmark"]')!;
  const liveFps = mount.querySelector<HTMLElement>('[data-stat="fps"]')!;
  const rendererName = mount.querySelector<HTMLElement>('.renderer-name')!;
  const toastElement = mount.querySelector<HTMLDivElement>('.af-toast')!;
  const settings = { quality: 'high', weather: 'clear', time: 'dusk', volume: 0.3, diagnostics: false };
  let mode: 'showcase' | 'explore' = 'showcase';
  let ready = false;
  let benchmarking = false;
  let savedVolume = 0.3;
  let toastTimer = 0;
  let lastFocus: HTMLElement | null = null;
  let lastStats: InterfaceStats | null = null;
  let dialogKind: 'inventory' | 'other' = 'other';
  let helpTimer = 0;
  let helpVisible = true;
  const physicalState = mount.querySelector<HTMLElement>('.physical-state')!;
  const staminaTrack = mount.querySelector<HTMLElement>('.stamina-track')!;
  const staminaFill = staminaTrack.querySelector<HTMLElement>('span')!;
  const interactPrompt = mount.querySelector<HTMLElement>('.interact-prompt')!;

  const formatNumber = (value: number) => Math.round(value).toLocaleString('en-US');
  const positionDiagnostics = () => {
    if (!benchmarkPanel.hidden) root.style.setProperty('--benchmark-panel-bottom', `${benchmarkPanel.offsetTop + benchmarkPanel.offsetHeight + 14}px`);
  };
  new ResizeObserver(positionDiagnostics).observe(benchmarkPanel);
  window.addEventListener('resize', positionDiagnostics);
  const hideBenchmark = () => {
    benchmarkPanel.hidden = true;
    root.classList.remove('has-benchmark');
  };
  const setText = (selector: string, value: string) => {
    const node = mount.querySelector<HTMLElement>(selector);
    if (node && node.textContent !== value) node.textContent = value;
  };
  const updateSound = () => {
    const soundButton = mount.querySelector<HTMLButtonElement>('[data-action="sound"]')!;
    soundButton.classList.toggle('is-muted', settings.volume === 0);
    soundButton.setAttribute('aria-label', settings.volume === 0 ? 'Unmute atmosphere' : 'Mute atmosphere');
    soundButton.title = settings.volume === 0 ? 'Unmute atmosphere' : 'Mute atmosphere';
    setText('.sound-state', settings.volume === 0 ? 'SOUND OFF' : 'SOUND ON');
  };
  const closeDialog = () => {
    if (dialogBackdrop.hidden) return;
    dialogBackdrop.hidden = true;
    dialogKind = 'other';
    callbacks.onPause(false);
    lastFocus?.focus({ preventScroll: true });
  };
  const openDialog = (html: string, kind: 'inventory' | 'other' = 'other') => {
    if (dialogBackdrop.hidden) lastFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    dialogKind = kind;
    dialog.innerHTML = html;
    dialogBackdrop.hidden = false;
    callbacks.onPause(true);
    dialog.querySelector<HTMLButtonElement>('[data-action="close"]')?.focus({ preventScroll: true });
  };
  const dialogHeader = (index: string, title: string) => `<div class="dialog-topline"><span class="eyebrow">AFTERFALL <span class="orange">/</span> ${index}</span><button class="icon-button" data-action="close" type="button" aria-label="Close dialog">${closeIcon}</button></div><h2 id="dialog-title">${title}</h2>`;
  const openNotes = () => openDialog(`${dialogHeader('FIELD NOTES', 'A world in the making.')}
    <p class="dialog-lead">Your journey begins in the financial district.</p>
    <p>Explore a procedural Indian city. Follow connected streets, search open buildings, find a bed for the night, and travel through gardens and lakes. Your world seed, discoveries, and supplies persist on this device.</p>
    <div class="note-divider"></div>
    <span class="eyebrow orange">WHAT YOU CAN DO TODAY</span>
    <div class="notes-grid"><div><span class="note-number">01</span><h3>Beyond the city.</h3><p>Follow the streets into woodland, foothills, and mountain country. Open M to mark a destination. Trails and isolated rest houses offer places to explore along the way.</p></div><div><span class="note-number">02</span><h3>A door to close.</h3><p>Press E at a door to open or close it. Search the rooms and find a bed for the night. Supplies, doors, and your journey are saved on this device.</p></div></div>
    <p class="scope-note">This is an open-world pre-alpha. Zombies, NPC simulation, combat, and deeper survival systems remain future work.</p>
    <div class="notes-controls"><span><kbd>W A S D</kbd> Move</span><span><kbd>SHIFT</kbd> Sprint</span><span><kbd>C</kbd> Crouch</span><span><kbd>SPACE</kbd> Jump / climb</span><span><kbd>E</kbd> Interact</span><span><kbd>I</kbd> Pack</span><span><kbd>DRAG</kbd> Look around</span><span><kbd>H</kbd> Controls</span><span><kbd>ESC</kbd> Menu</span></div>
    <button class="dialog-done" data-action="close" type="button">Back to the world ${arrow}</button>`);
  const selectField = (name: 'quality' | 'weather' | 'time', label: string, description: string, options: string[]) => `<label class="setting-row"><span><strong>${label}</strong><small>${description}</small></span><select name="${name}" aria-label="${label}">${options.map(value => `<option value="${value}"${settings[name] === value ? ' selected' : ''}>${value.charAt(0).toUpperCase() + value.slice(1)}</option>`).join('')}</select></label>`;
  const openSettings = () => openDialog(`${dialogHeader('SYSTEM', 'Set the atmosphere.')}
    <p class="dialog-lead">Your window into the world.</p>
    <form class="settings-form" onsubmit="return false">
      ${selectField('quality', 'Visual quality', 'Render resolution, shadows, and scene detail.', ['low', 'medium', 'high', 'ultra'])}
      ${selectField('weather', 'Weather', 'Change what hangs in the air.', ['clear', 'rain', 'fog'])}
      ${selectField('time', 'Time of day', 'A different light. The same abandoned city.', ['dawn', 'overcast', 'dusk', 'night'])}
      <label class="setting-row"><span><strong>Atmosphere volume</strong><small>The sound of a world still breathing.</small></span><span class="volume-control"><input name="volume" type="range" min="0" max="1" step="0.01" value="${settings.volume}" aria-label="Atmosphere volume"><output class="volume-value">${Math.round(settings.volume * 100)}%</output></span></label>
      <label class="setting-row"><span><strong>Renderer diagnostics</strong><small>Live frame timing and scene statistics.</small></span><input name="diagnostics" class="switch-input" type="checkbox"${settings.diagnostics ? ' checked' : ''}><span class="switch" aria-hidden="true"></span></label>
    </form>
    <div class="settings-footer"><span>CHANGES APPLY IMMEDIATELY</span><button class="dialog-done" data-action="close" type="button">Return ${arrow}</button></div>
    ${callbacks.onNewJourney ? '<div class="journey-reset"><span>Start again at the district entrance.</span><button type="button" data-action="new-journey">New world</button></div>' : ''}`);
  const confirmNewJourney = () => openDialog(`${dialogHeader('NEW WORLD', 'A different world awaits.')}<p class="dialog-lead">Every seed creates its own neighborhoods, buildings, and wilderness.</p><label class="seed-field">World seed<input id="world-seed" type="number" min="0" max="4294967295" step="1" value="${Math.floor(Math.random()*4294967295)}" /></label><p>Your current exploration save will be replaced. The same seed recreates the same geography.</p><div class="confirm-actions"><button class="dialog-done" data-action="close" type="button">Keep my world</button><button class="danger-button" data-action="confirm-new-journey" type="button">Generate world ${arrow}</button></div>`);
  const setHelpVisible = (visible: boolean) => {
    helpVisible = visible;
    mount.querySelector<HTMLElement>('.explore-controls')!.hidden = !visible;
    mount.querySelector<HTMLButtonElement>('[data-action="help"]')!.setAttribute('aria-expanded', String(visible));
  };
  const toggleHelp = () => {
    window.clearTimeout(helpTimer);
    setHelpVisible(!helpVisible);
  };

  const escapeHTML = (value: string) => value.replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]!);
  const renderInventory = (items: InventoryInterfaceItem[]) => `<div class="pack-caption"><span>${items.reduce((count, item) => count + item.count, 0)} ITEMS CARRIED</span><span>SECTOR 07</span></div><div class="pack-items">${items.length ? items.map(item => `<article class="pack-item"><div class="pack-item-mark" aria-hidden="true">${item.usable ? '+' : '◇'}</div><div class="pack-item-description"><h3>${escapeHTML(item.name)}<span>× ${item.count}</span></h3><p>${escapeHTML(item.description)}</p></div>${item.usable && callbacks.onUseItem ? `<button type="button" data-action="use-item" data-item-id="${escapeHTML(item.id)}"${item.count < 1 ? ' disabled' : ''}>Use ${arrow}</button>` : '<span class="pack-kept">KEPT</span>'}</article>`).join('') : '<p class="pack-empty">Your pack is empty. Search the district for supplies.</p>'}</div>`;
  const showInventory = (items: InventoryInterfaceItem[]) => {
    if (benchmarking || mode !== 'explore') return;
    if (dialogKind === 'inventory' && !dialogBackdrop.hidden) {
      const focusedItem = (document.activeElement as HTMLElement | null)?.dataset.itemId;
      dialog.querySelector<HTMLElement>('.pack-content')!.innerHTML = renderInventory(items);
      const itemButton = [...dialog.querySelectorAll<HTMLButtonElement>('[data-item-id]')].find(button => button.dataset.itemId === focusedItem && !button.disabled);
      if (focusedItem) (itemButton ?? dialog.querySelector<HTMLButtonElement>('[data-action="close"]'))?.focus({ preventScroll: true });
      return;
    }
    openDialog(`${dialogHeader('SURVIVOR / PACK', 'What you carry.')}<p class="dialog-lead">A few things worth holding on to.</p><div class="pack-content">${renderInventory(items)}</div><div class="pack-footer"><span>The world is paused while your pack is open.</span><button class="dialog-done" data-action="close" type="button"><kbd>I</kbd> Return ${arrow}</button></div>`, 'inventory');
  };

  mount.addEventListener('click', event => {
    const target = (event.target as HTMLElement).closest<HTMLButtonElement>('[data-action]');
    if (!target || target.disabled) return;
    switch (target.dataset.action) {
      case 'home': closeDialog(); if (mode === 'explore') callbacks.onExit(); break;
      case 'enter': if (ready) callbacks.onEnter(); break;
      case 'exit': callbacks.onExit(); break;
      case 'benchmark': if (ready && !benchmarking) { closeDialog(); callbacks.onBenchmark(); } break;
      case 'notes': openNotes(); break;
      case 'settings': openSettings(); break;
      case 'inventory': if (mode === 'explore' && !benchmarking) callbacks.onInventory?.(); break;
      case 'map': if(mode==='explore'&&!benchmarking)callbacks.onMap?.();break;
      case 'use-item': if (target.dataset.itemId) callbacks.onUseItem?.(target.dataset.itemId); break;
      case 'new-journey': if (callbacks.onNewJourney) confirmNewJourney(); break;
      case 'confirm-new-journey': {
        const seed=Number(dialog.querySelector<HTMLInputElement>('#world-seed')?.value);
        if(!Number.isInteger(seed)||seed<0||seed>4294967295){toast('Enter a seed from 0 to 4294967295.');break;}
        closeDialog(); callbacks.onNewJourney?.(seed);break;
      }
      case 'help': toggleHelp(); document.querySelector<HTMLElement>('#world canvas')?.focus({preventScroll:true}); break;
      case 'close': closeDialog(); break;
      case 'dismiss-benchmark': hideBenchmark(); break;
      case 'sound':
        if (settings.volume > 0) { savedVolume = settings.volume; settings.volume = 0; }
        else settings.volume = savedVolume || 0.3;
        updateSound(); callbacks.onSettingsChange({ volume: settings.volume });
        if(mode==='explore')document.querySelector<HTMLElement>('#world canvas')?.focus({preventScroll:true});
        break;
    }
  });
  dialogBackdrop.addEventListener('click', event => { if (event.target === dialogBackdrop) closeDialog(); });
  dialog.addEventListener('input', event => {
    const input = event.target as HTMLInputElement | HTMLSelectElement;
    const name = input.name;
    if (name === 'quality' || name === 'weather' || name === 'time') {
      settings[name] = input.value;
      callbacks.onSettingsChange({ [name]: input.value });
    } else if (name === 'volume') {
      settings.volume = Number(input.value);
      if (settings.volume > 0) savedVolume = settings.volume;
      setText('.volume-value', `${Math.round(settings.volume * 100)}%`);
      updateSound(); callbacks.onSettingsChange({ volume: settings.volume });
    } else if (name === 'diagnostics') {
      settings.diagnostics = (input as HTMLInputElement).checked;
      diagnosticsPanel.hidden = !settings.diagnostics;
      if (lastStats) setStats(lastStats);
      callbacks.onSettingsChange({ diagnostics: settings.diagnostics });
    }
  });
  document.addEventListener('keydown', event => {
    if (dialogBackdrop.hidden) {
      if (event.key === 'Escape' && mode === 'explore') { event.preventDefault(); callbacks.onExit(); }
      if (mode === 'explore' && !benchmarking && !event.repeat && !event.ctrlKey && !event.metaKey && !event.altKey) {
        if (event.code === 'KeyI') { event.preventDefault(); event.stopImmediatePropagation(); callbacks.onInventory?.(); }
        if (event.code === 'KeyM') { event.preventDefault(); event.stopImmediatePropagation(); callbacks.onMap?.(); }
        if (event.code === 'KeyH') { event.preventDefault(); event.stopImmediatePropagation(); toggleHelp(); }
      }
      return;
    }
    event.stopImmediatePropagation();
    if (event.key === 'Escape' || (dialogKind === 'inventory' && event.code === 'KeyI' && !event.repeat) || (dialog.querySelector('#world-map-detail')&&event.code==='KeyM'&&!event.repeat)) { event.preventDefault(); closeDialog(); return; }
    if (event.key === 'Tab') {
      const focusable = Array.from(dialog.querySelectorAll<HTMLElement>('button:not(:disabled), select, input, [tabindex="0"]'));
      const first = focusable[0], last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    }
  }, true);

  function toast(message: string) {
    window.clearTimeout(toastTimer);
    toastElement.textContent = message;
    toastElement.hidden = false;
    toastTimer = window.setTimeout(() => { toastElement.hidden = true; }, 4200);
  }

  function setStats(stats: InterfaceStats) {
    lastStats = stats;
    liveFps.textContent = Math.round(stats.fps).toString().padStart(2, '0');
    rendererName.textContent = stats.backend;
    if (diagnosticsPanel.hidden) return;
    setText('[data-stat="frameMs"]', `${stats.frameMs.toFixed(1)} ms`);
    setText('[data-stat="gpuMs"]', stats.gpuMs === null ? 'Unavailable' : `${stats.gpuMs.toFixed(1)} ms`);
    setText('[data-stat="drawCalls"]', formatNumber(stats.drawCalls));
    setText('[data-stat="triangles"]', formatNumber(stats.triangles));
    setText('[data-stat="memoryMB"]', stats.memoryMB === null ? 'Unavailable' : `${Math.round(stats.memoryMB)} MB`);
    setText('[data-stat="geometries"]', formatNumber(stats.geometries));
    setText('[data-stat="textures"]', formatNumber(stats.textures));
  }

  return {
    setReady(backend: string) {
      ready = true;
      root.classList.remove('is-loading');
      mount.querySelector<HTMLElement>('.loading-screen')!.hidden = true;
      rendererName.textContent = backend;
      enterButton.disabled = false;
      benchmarkButton.disabled = false;
    },
    setStats,
    setPlayer(state: PlayerInterfaceState) {
      const stamina = Math.max(0, Math.min(1, Number.isFinite(state.stamina) ? state.stamina : 1));
      const sprinting = /sprint/i.test(state.locomotion);
      physicalState.hidden = stamina >= 0.97 && !sprinting && !state.crouched;
      physicalState.classList.toggle('is-exhausted', stamina < 0.2);
      staminaFill.style.transform = `scaleX(${stamina})`;
      staminaTrack.setAttribute('aria-valuenow', String(Math.round(stamina * 100)));
      setText('[data-player="physical"]', state.crouched ? 'CROUCHED' : stamina < 0.2 ? 'CATCHING BREATH' : sprinting ? 'SPRINTING' : 'RECOVERING');
      setText('[data-player="objective"]', state.objective);
      setText('[data-player="objectiveDetail"]', state.objectiveDetail);
      interactPrompt.hidden = !state.interactLabel;
      setText('[data-player="interact"]', state.interactLabel ?? '');
      if (state.saveStatus !== undefined) setText('.save-status', state.saveStatus);
    },
    showInventory,
    showWorldMap() {
      openDialog(`${dialogHeader('FIELD MAP','Beyond the next street.')}<p class="map-guide">Click to mark a destination. Scroll to zoom out and find the forests and highlands beyond the city.</p><canvas id="world-map-detail" width="640" height="480" aria-label="Procedural world map. Click to set a waypoint."></canvas><div class="map-legend"><span>▣ Enterable building</span><span>◈ Shelter</span><span class="lake-key">● Lake</span><span class="player-key">▲ You</span></div><button class="dialog-done" data-action="close" type="button">Return to the world ${arrow}</button>`);
      return dialog.querySelector<HTMLCanvasElement>('#world-map-detail')!;
    },
    setLoading(label:string) {
      root.classList.add('is-loading');mount.querySelector<HTMLElement>('.loading-screen')!.hidden=false;
      setText('.loading-description',label);
    },
    setWorldInfo(name:string,day:number,hour:number,seed:number,heading:number,sleeping:boolean) {
      setText('.explore-location strong',name);
      setText('.world-clock',`DAY ${day}  /  ${String(Math.floor(hour)).padStart(2,'0')}:${String(Math.floor(hour%1*60)).padStart(2,'0')}  ·  SEED ${seed}`);
      const compass=['N','NE','E','SE','S','SW','W','NW'];
      const deg=(((Math.PI-heading)*180/Math.PI)%360+360)%360;
      setText('.world-compass',`${compass[Math.round(deg/45)%8]}  ·  ${Math.round(deg)}°`);
      root.classList.toggle('is-sleeping',sleeping);
      settings.time=hour<5.5||hour>=19.5?'night':hour<8?'dawn':hour<17.5?'overcast':'dusk';
    },
    refreshInventory(items: InventoryInterfaceItem[]) {
      if (dialogKind === 'inventory' && !dialogBackdrop.hidden) showInventory(items);
    },
    setSession(hasSave: boolean) {
      setText('[data-action="enter"] > span', hasSave ? 'Continue journey' : 'Enter the district');
    },
    setMode(nextMode: 'showcase' | 'explore') {
      mode = nextMode;
      root.classList.toggle('is-exploring', mode === 'explore');
      mount.querySelector<HTMLElement>('.explore-overlay')!.hidden = mode !== 'explore';
      mount.querySelector<HTMLElement>('.showcase-content')!.inert = mode === 'explore';
      window.clearTimeout(helpTimer);
      if (mode === 'explore') {
        (document.activeElement as HTMLElement)?.blur?.();
        setHelpVisible(true);
        helpTimer = window.setTimeout(() => setHelpVisible(false), 11000);
      }
    },
    setBenchmark(progress: number | null, result?: BenchmarkResult) {
      benchmarking = progress !== null;
      root.classList.toggle('is-benchmark-running', benchmarking);
      setText('.explore-role', benchmarking ? 'INSPECTION' : 'SURVIVOR');
      benchmarkButton.disabled = benchmarking || !ready;
      if (progress === null && !result) { hideBenchmark(); return; }
      benchmarkPanel.hidden = false;
      root.classList.add('has-benchmark');
      if (result) {
        benchmarkPanel.innerHTML = `<div class="benchmark-title"><span class="eyebrow">BENCHMARK COMPLETE</span><button class="icon-button" type="button" data-action="dismiss-benchmark" aria-label="Dismiss benchmark results">${closeIcon}</button></div><div class="benchmark-result"><strong>${result.avgFps.toFixed(1)}<small>AVERAGE FPS</small></strong><span>${result.p1Fps.toFixed(1)}<small>1% LOW FPS</small></span><span>${result.avgFrameMs.toFixed(1)}<small>AVG. FRAME MS</small></span></div><p class="benchmark-footnote">${formatNumber(result.frames)} frames sampled · Actual device performance</p>`;
        if (result.context) {
          const context = document.createElement('p');
          context.className = 'benchmark-context';
          context.textContent = result.context;
          benchmarkPanel.append(context);
        }
      } else {
        const percent = Math.min(100, Math.max(0, Math.round((progress ?? 0) * 100)));
        if (!benchmarkPanel.querySelector('.benchmark-track')) benchmarkPanel.innerHTML = '<div class="benchmark-title"><span class="eyebrow">MEASURING YOUR WORLD</span><span class="benchmark-percent">0%</span></div><div class="benchmark-track"><span></span></div><p class="benchmark-footnote">30-second renderer test · Keep this tab active</p>';
        benchmarkPanel.querySelector<HTMLElement>('.benchmark-percent')!.textContent = `${percent}%`;
        benchmarkPanel.querySelector<HTMLElement>('.benchmark-track span')!.style.width = `${percent}%`;
      }
    },
    toast,
    isModalOpen() { return !dialogBackdrop.hidden; },
    showError(message: string) {
      ready = false;
      root.classList.remove('is-loading');
      mount.querySelector<HTMLElement>('.loading-screen')!.hidden = true;
      enterButton.disabled = true;
      benchmarkButton.disabled = true;
      rendererName.textContent = 'RENDERER UNAVAILABLE';
      openDialog(`${dialogHeader('SYSTEM NOTICE', 'The district could not load.')}<p class="dialog-lead">The renderer needs your attention.</p><p class="renderer-error"></p><p>Try a current desktop version of Chrome or Edge with hardware acceleration enabled, then reload this page.</p><button class="dialog-done" data-action="close" type="button">Close ${arrow}</button>`);
      dialog.querySelector<HTMLElement>('.renderer-error')!.textContent = message;
    },
  };
}

