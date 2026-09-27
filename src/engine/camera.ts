import { PerspectiveCamera, Vector3, Euler } from 'three/webgpu';

/** Inspection camera only. Gameplay collision and character movement belong in Phase 1. */
export class InspectionCamera {
  mode: 'showcase' | 'explore' = 'showcase';
  private keys = new Set<string>();
  private dragging = false;
  private yaw = 0;
  private pitch = 0;
  private velocity = new Vector3();
  private direction = new Vector3();
  private euler = new Euler(0, 0, 0, 'YXZ');
  private home = new Vector3(6.6, 5.1, 27);
  private target = new Vector3(-2.5, 5, -43);
  private anchor = new Vector3();
  enabled = true;

  constructor(private camera: PerspectiveCamera, canvas: HTMLCanvasElement) {
    this.reset();
    window.addEventListener('keydown', event => {
      if (event.target instanceof Element && event.target.closest('input,textarea,select,button')) return;
      if (!this.enabled || this.mode !== 'explore') return;
      if (['KeyW','KeyA','KeyS','KeyD','KeyQ','KeyE','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','ShiftLeft','ShiftRight'].includes(event.code)) {
        event.preventDefault();
        this.keys.add(event.code);
      }
      if (event.code === 'KeyF') this.reset();
    });
    window.addEventListener('keyup', event => this.keys.delete(event.code));
    window.addEventListener('blur', () => this.clear());
    canvas.addEventListener('pointerdown', event => {
      if (this.mode !== 'explore' || !this.enabled || event.button !== 0) return;
      this.dragging = true;
      canvas.setPointerCapture(event.pointerId);
      canvas.style.cursor = 'grabbing';
    });
    canvas.addEventListener('pointerup', () => { this.dragging = false; canvas.style.cursor = 'grab'; });
    canvas.addEventListener('pointermove', event => {
      if (!this.dragging || !this.enabled) return;
      this.yaw -= event.movementX * 0.0023;
      this.pitch = Math.max(-1.25, Math.min(1.25, this.pitch - event.movementY * 0.0023));
    });
  }

  clear() { this.keys.clear(); this.dragging = false; this.velocity.set(0,0,0); }
  setAnchor(x:number,z:number) {this.anchor.set(x,0,z);this.reset();}

  reset() {
    this.camera.position.copy(this.mode === 'explore' ? new Vector3(0, 1.85, 23) : this.home).add(this.anchor);
    this.camera.lookAt(this.target.x+this.anchor.x,this.target.y,this.target.z+this.anchor.z);
    this.euler.setFromQuaternion(this.camera.quaternion, 'YXZ');
    this.yaw = this.euler.y; this.pitch = this.euler.x;
    this.clear();
  }

  setMode(mode: 'showcase' | 'explore') { this.mode = mode; this.reset(); }

  update(dt: number, elapsed: number, benchmark: number | null) {
    if (benchmark !== null) {
      this.camera.position.set(this.anchor.x+2 + Math.sin(benchmark * Math.PI * 2) * 3.4, 4 + Math.sin(benchmark * Math.PI) * 2, this.anchor.z+27 - benchmark * 118);
      this.camera.lookAt(this.anchor.x-1 + Math.sin(benchmark * Math.PI * 2) * 4, 4.4, this.camera.position.z - 45);
      return;
    }
    if (this.mode === 'showcase') {
      this.camera.position.copy(this.home).add(this.anchor);
      this.camera.position.x += Math.sin(elapsed * 0.055) * 0.9;
      this.camera.position.y += Math.sin(elapsed * 0.08) * 0.12;
      this.camera.lookAt(this.target.x+this.anchor.x,this.target.y,this.target.z+this.anchor.z);
      return;
    }
    if (!this.enabled) { this.clear(); return; }
    const held = (a: string, b = '') => this.keys.has(a) || this.keys.has(b);
    const forward = Number(held('KeyW','ArrowUp')) - Number(held('KeyS','ArrowDown'));
    const strafe = Number(held('KeyD','ArrowRight')) - Number(held('KeyA','ArrowLeft'));
    const vertical = Number(held('KeyE')) - Number(held('KeyQ'));
    this.direction.set(strafe, vertical, -forward).normalize();
    this.direction.applyAxisAngle(new Vector3(0,1,0), this.yaw);
    this.direction.multiplyScalar(held('ShiftLeft','ShiftRight') ? 13 : 4.6);
    this.velocity.lerp(this.direction, 1 - Math.exp(-8 * dt));
    this.camera.position.addScaledVector(this.velocity, dt);
    this.camera.position.x = Math.max(-8.4, Math.min(8.4, this.camera.position.x));
    this.camera.position.z = Math.max(-136, Math.min(34, this.camera.position.z));
    this.camera.position.y = Math.max(1.65, Math.min(27, this.camera.position.y));
    this.camera.quaternion.setFromEuler(this.euler.set(this.pitch, this.yaw, 0, 'YXZ'));
  }
}
