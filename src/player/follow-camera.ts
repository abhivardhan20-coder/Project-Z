import { PerspectiveCamera, Vector3 } from 'three/webgpu';
import type { CollisionWorld } from '../world/collision';
import type { PlayerInput } from './input';

/** An orbit boom follows the render pose; only its length and vertical anchor ease. */
export class FollowCamera {
  private readonly target = new Vector3();
  private readonly direction = new Vector3();
  private readonly clearanceOrigin = new Vector3();
  private readonly up = new Vector3(0, 1, 0);
  private readonly camera: PerspectiveCamera;
  private readonly collision: CollisionWorld;
  private initialized = false;
  private boomLength = 0;
  private extensionDelay = 0;

  constructor(camera: PerspectiveCamera, collision: CollisionWorld) {
    this.camera = camera;
    this.collision = collision;
  }

  reset() { this.initialized = false; this.extensionDelay = 0; }

  update(dt: number, position: { x: number; y: number; z: number }, crouched: boolean, input: PlayerInput) {
    const delta = Math.max(0, Math.min(Number.isFinite(dt) ? dt : 0, .1));
    const desiredHeight = position.y + (crouched ? .80 : 1.43);
    // Horizontal translation must share the survivor's interpolated pose. Lerping a
    // world-space eye while looking at a stepped physics target rotates the entire
    // view on every tick, even when walking across a perfectly level street.
    const anchorHeight = this.initialized
      ? this.target.y + (desiredHeight - this.target.y) * (1 - Math.exp(-delta * 16))
      : desiredHeight;
    this.target.set(position.x, anchorHeight, position.z);

    // Ease over steps and stance changes, but never leave the camera anchor inside
    // a low ceiling while crouching. This is an upward clearance sweep, not a
    // second constraint applied to an already moving camera position.
    this.clearanceOrigin.set(position.x, position.y + .32, position.z);
    const height = Math.max(0, this.target.y - this.clearanceOrigin.y);
    this.target.y = Math.min(this.target.y, this.clearanceOrigin.y
      + this.collision.cameraDistance(this.clearanceOrigin, this.up, height));

    const cos = Math.cos(input.pitch);
    this.direction.set(-Math.sin(input.yaw) * cos, Math.sin(input.pitch), -Math.cos(input.yaw) * cos).normalize();
    const permitted = this.collision.cameraDistance(this.target, this.direction, input.distance);
    if (!this.initialized) {
      this.boomLength = permitted;
      this.initialized = true;
    } else if (permitted < this.boomLength) {
      // Safety retraction is immediate. A short hold prevents repeated outward
      // pumping when the sphere grazes a doorway or a furniture edge.
      if (this.boomLength - permitted > .005) this.extensionDelay = .12;
      this.boomLength = permitted;
    } else {
      this.extensionDelay = Math.max(0, this.extensionDelay - delta);
      if (this.extensionDelay === 0) this.boomLength += (permitted - this.boomLength) * (1 - Math.exp(-delta * 7));
    }
    this.camera.position.copy(this.target).addScaledVector(this.direction, this.boomLength);
    this.camera.lookAt(this.target);
    return this.boomLength;
  }
}
