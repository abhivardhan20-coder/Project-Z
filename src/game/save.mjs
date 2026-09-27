export const SAVE_KEY = 'afterfall.journey.v1';
const ITEM_LIMITS = { water: 8, bandage: 8, battery: 2, key: 1 };
const FLAGS = ['fieldKit','serviceCache','shelterOpen','powerRestored','rested'];
export function newJourney() {
  return {version:1,position:{x:0,y:.06,z:22},yaw:Math.PI,stamina:1,crouched:false,inventory:{water:0,bandage:0,battery:0,key:0},flags:{fieldKit:false,serviceCache:false,shelterOpen:false,powerRestored:false,rested:false},savedAt:0};
}
/** Treat browser storage as untrusted input. Never restore invalid coordinates or item counts. */
export function validateSave(value) {
  if(!value || value.version!==1 || !value.position || !value.inventory || !value.flags) return null;
  const {x,y,z}=value.position;
  if(![x,y,z,value.yaw,value.stamina].every(Number.isFinite) || Math.abs(x)>11.25 || z < -154.75 || z>41.75 || y < -.2 || y>8) return null;
  if(value.crouched!==undefined && typeof value.crouched!=='boolean') return null;
  if(value.stamina<0 || value.stamina>1) return null;
  for(const [id,max] of Object.entries(ITEM_LIMITS)) if(!Number.isInteger(value.inventory[id]) || value.inventory[id]<0 || value.inventory[id]>max) return null;
  for(const id of FLAGS) if(typeof value.flags[id]!=='boolean') return null;
  if(value.flags.powerRestored&&!value.flags.shelterOpen || value.flags.shelterOpen&&!value.flags.serviceCache || value.flags.rested&&!value.flags.powerRestored) return null;
  if(value.flags.powerRestored&&!value.flags.fieldKit || value.inventory.key!==Number(value.flags.serviceCache)
    || value.inventory.battery!==Number(value.flags.fieldKit&&!value.flags.powerRestored)) return null;
  const clean=newJourney();
  clean.position={x,y,z};clean.yaw=value.yaw;clean.stamina=value.stamina;clean.crouched=value.crouched??false;
  for(const id of Object.keys(ITEM_LIMITS)) clean.inventory[id]=value.inventory[id];
  for(const id of FLAGS) clean.flags[id]=value.flags[id];
  clean.savedAt=Number.isFinite(value.savedAt)?value.savedAt:0;
  return clean;
}
export function loadJourney(storage) {
  try { const raw=storage.getItem(SAVE_KEY); return raw?validateSave(JSON.parse(raw)):null; } catch { return null; }
}
export function saveJourney(storage,journey) {
  const clean=validateSave(journey);if(!clean) return false;
  try { storage.setItem(SAVE_KEY,JSON.stringify({...clean,savedAt:Date.now()}));return true; } catch { return false; }
}
