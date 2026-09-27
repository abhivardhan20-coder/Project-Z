/** Browser input is sampled by the simulation; event handlers never move the player. */
export class PlayerInput {
  enabled = false;
  yaw = Math.PI;
  pitch = 0.19;
  distance = 3.65;
  flashlight = false;
  private keys = new Set<string>();
  private jumpQueued = false;
  private interactQueued = false;
  private dragging = false;
  private crouching = false;
  private walking = false;
  private abort = new AbortController();
  constructor(private canvas: HTMLCanvasElement) {
    const options = { signal: this.abort.signal };
    window.addEventListener('keydown', event => {
      if (!this.enabled || (event.target instanceof Element && event.target.closest('input,select,textarea,button'))) return;
      if (['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','ShiftLeft','ShiftRight','Space','KeyC','KeyE','AltLeft'].includes(event.code)) event.preventDefault();
      this.keys.add(event.code);
      if (!event.repeat) {
        if (event.code === 'Space') this.jumpQueued = true;
        if (event.code === 'KeyE') this.interactQueued = true;
        if (event.code === 'KeyC') this.crouching = !this.crouching;
        if (event.code === 'AltLeft') this.walking = !this.walking;
        if (event.code === 'KeyF') this.flashlight = !this.flashlight;
      }
    }, options);
    window.addEventListener('keyup', event => this.keys.delete(event.code), options);
    window.addEventListener('blur', () => this.clear(), options);
    canvas.addEventListener('pointerdown', event => {
      if (!this.enabled || event.button !== 0) return;
      this.dragging = true; canvas.setPointerCapture(event.pointerId); canvas.style.cursor = 'grabbing';
    }, options);
    const release = () => { this.dragging = false; canvas.style.cursor = this.enabled ? 'grab' : 'default'; };
    canvas.addEventListener('pointerup',release,options);
    canvas.addEventListener('pointercancel',release,options);
    canvas.addEventListener('lostpointercapture',release,options);
    canvas.addEventListener('pointermove',event => {
      if (!this.enabled || !this.dragging) return;
      this.yaw -= event.movementX * .0026;
      this.pitch = Math.max(-.27,Math.min(1.05,this.pitch + event.movementY * .0022));
    },options);
    canvas.addEventListener('wheel',event => {
      if (!this.enabled) return;
      event.preventDefault(); this.distance=Math.max(2.3,Math.min(5.2,this.distance+event.deltaY*.003));
    },{...options,passive:false});
  }
  sample() {
    const held = (a:string,b='') => this.keys.has(a)||this.keys.has(b);
    const forward=Number(held('KeyW','ArrowUp'))-Number(held('KeyS','ArrowDown'));
    const right=Number(held('KeyD','ArrowRight'))-Number(held('KeyA','ArrowLeft'));
    const length=Math.hypot(forward,right)||1;
    const jump=this.jumpQueued; this.jumpQueued=false;
    return {
      moveX:(Math.sin(this.yaw)*forward-Math.cos(this.yaw)*right)/length,
      moveZ:(Math.cos(this.yaw)*forward+Math.sin(this.yaw)*right)/length,
      sprint:held('ShiftLeft','ShiftRight'),walk:this.walking,crouch:this.crouching,jump,
    };
  }
  consumeInteraction() { const result=this.interactQueued; this.interactQueued=false; return result; }
  setCrouched(value:boolean) {this.crouching=value;}
  clear() { this.keys.clear(); this.jumpQueued=false; this.interactQueued=false; this.dragging=false; }
  reset() { this.clear(); this.crouching=false; this.walking=false; this.yaw=Math.PI; this.pitch=.19; }
  dispose() { this.abort.abort(); this.clear(); }
}
