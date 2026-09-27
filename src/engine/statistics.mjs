export function summarizeFrames(samples) {
  const valid = samples.filter(value => Number.isFinite(value) && value > 0);
  if (!valid.length) return { avgFps: 0, p1Fps: 0, avgFrameMs: 0, frames: 0 };
  const average = valid.reduce((sum, value) => sum + value, 0) / valid.length;
  const slowest = [...valid].sort((a, b) => b - a).slice(0, Math.max(1, Math.ceil(valid.length * 0.01)));
  return {
    avgFps: 1000 / average,
    p1Fps: 1000 / (slowest.reduce((sum, value) => sum + value, 0) / slowest.length),
    avgFrameMs: average,
    frames: valid.length,
  };
}

export const QUALITY = {
  low: { pixelRatio: 0.75, shadowSize: 512, shadows: false, particles: 350 },
  medium: { pixelRatio: 1, shadowSize: 1024, shadows: true, particles: 700 },
  high: { pixelRatio: 1.35, shadowSize: 2048, shadows: true, particles: 1200 },
  ultra: { pixelRatio: 2, shadowSize: 4096, shadows: true, particles: 2000 },
};
