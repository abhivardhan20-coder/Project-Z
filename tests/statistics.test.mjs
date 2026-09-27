import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeFrames, QUALITY } from '../src/engine/statistics.mjs';

test('steady 60 Hz frames produce accurate timing', () => {
  const result = summarizeFrames(Array(1800).fill(1000 / 60));
  assert.ok(Math.abs(result.avgFps - 60) < 0.0001);
  assert.ok(Math.abs(result.p1Fps - 60) < 0.0001);
  assert.equal(result.frames, 1800);
});
test('1% low uses the slowest frames, not the 99th percentile FPS', () => {
  const result = summarizeFrames([...Array(990).fill(10), ...Array(10).fill(100)]);
  assert.equal(result.p1Fps, 10);
  assert.ok(result.avgFps < 100 && result.avgFps > 90);
});
test('empty and invalid samples cannot produce infinite diagnostics', () => {
  assert.deepEqual(summarizeFrames([NaN, Infinity, 0, -20]), { avgFps: 0, p1Fps: 0, avgFrameMs: 0, frames: 0 });
});
test('presets limit pixel ratio, shadows, and atmospheric work', () => {
  assert.equal(QUALITY.low.shadows, false);
  assert.ok(QUALITY.ultra.pixelRatio <= 2);
  assert.ok(QUALITY.high.particles < QUALITY.ultra.particles);
});
