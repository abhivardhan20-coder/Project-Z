import { loadJourney } from './save.mjs';

export const WORLD_SAVE_KEY = 'afterfall.world.v2';
export const DEFAULT_WORLD_SEED = 7307;
const MAX_RECORDS = 10000;
const ITEM_IDS = ['water', 'food', 'bandage'];
const validId = value => typeof value === 'string' && value.length > 0 && value.length <= 160 && /^[a-zA-Z0-9:._-]+$/.test(value);
const validSeed = seed => Number.isInteger(seed) && seed >= 0 && seed <= 0xffffffff;

export function newWorld(seed = DEFAULT_WORLD_SEED) {
  return {
    version: 2, seed: validSeed(seed) ? seed : DEFAULT_WORLD_SEED,
    position: { x: 0, y: .1, z: 22 }, yaw: Math.PI, stamina: 1, crouched: false,
    inventory: { water: 0, food: 0, bandage: 0 }, looted: [], visited: [], openedDoors: [],
    day: 1, hour: 16.25, shelterId: null, savedAt: 0,
  };
}

/** Storage is untrusted: rebuild a known schema instead of merging arbitrary values. */
export function validateWorldSave(value) {
  if (!value || value.version !== 2 || !validSeed(value.seed) || !value.position || !value.inventory) return null;
  const { x, y, z } = value.position;
  if (![x, y, z, value.yaw, value.stamina, value.hour].every(Number.isFinite)) return null;
  if (Math.abs(x) > 1e6 || Math.abs(z) > 1e6 || y < -50 || y > 500) return null;
  if (value.stamina < 0 || value.stamina > 1 || typeof value.crouched !== 'boolean') return null;
  if (!Number.isInteger(value.day) || value.day < 1 || value.day > 1000000 || value.hour < 0 || value.hour >= 24) return null;
  if (value.shelterId !== null && !validId(value.shelterId)) return null;
  for (const id of ITEM_IDS) {
    if (!Number.isInteger(value.inventory[id]) || value.inventory[id] < 0 || value.inventory[id] > 999) return null;
  }
  for (const field of ['looted', 'visited']) {
    const ids = value[field];
    if (!Array.isArray(ids) || ids.length > MAX_RECORDS || !ids.every(validId) || new Set(ids).size !== ids.length) return null;
  }
  // Existing v2 worlds predate working doors; absent state means every door starts shut.
  const openedDoors = value.openedDoors === undefined ? [] : value.openedDoors;
  if (!Array.isArray(openedDoors) || openedDoors.length > MAX_RECORDS || !openedDoors.every(validId)
    || new Set(openedDoors).size !== openedDoors.length) return null;
  const clean = newWorld(value.seed);
  clean.position = { x, y, z };
  clean.yaw = value.yaw;
  clean.stamina = value.stamina;
  clean.crouched = value.crouched;
  for (const id of ITEM_IDS) clean.inventory[id] = value.inventory[id];
  clean.looted = [...value.looted];
  clean.visited = [...value.visited];
  clean.openedDoors = [...openedDoors];
  clean.day = value.day;
  clean.hour = value.hour;
  clean.shelterId = value.shelterId;
  clean.savedAt = Number.isFinite(value.savedAt) && value.savedAt >= 0 ? value.savedAt : 0;
  return clean;
}

/** Keep the original save intact; its old street coordinates do not fit the new world. */
export function loadWorld(storage) {
  try {
    const raw = storage.getItem(WORLD_SAVE_KEY);
    if (raw !== null) return validateWorldSave(JSON.parse(raw));
    const legacy = loadJourney(storage);
    if (!legacy) return null;
    const migrated = newWorld();
    migrated.inventory.water = legacy.inventory.water;
    migrated.inventory.bandage = legacy.inventory.bandage;
    migrated.stamina = legacy.stamina;
    migrated.savedAt = legacy.savedAt;
    return migrated;
  } catch { return null; }
}

export function saveWorld(storage, data) {
  const clean = validateWorldSave(data);
  if (!clean) return false;
  try {
    storage.setItem(WORLD_SAVE_KEY, JSON.stringify({ ...clean, savedAt: Date.now() }));
    return true;
  } catch { return false; }
}
