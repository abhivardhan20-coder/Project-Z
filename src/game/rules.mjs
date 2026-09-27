/** Journey rules are deterministic and independent of rendering and browser storage. */
export function applyInteraction(journey, id) {
  const {flags,inventory}=journey;
  if(id==='fieldKit' && !flags.fieldKit) {
    flags.fieldKit=true;inventory.water+=2;inventory.bandage+=1;inventory.battery+=1;
    return {changed:true,message:'Packed 2 water bottles, a bandage, and a charged battery.'};
  }
  if(id==='serviceCache' && !flags.serviceCache) {
    flags.serviceCache=true;inventory.key=1;
    return {changed:true,message:'Service key collected. The shelter is farther down the street.'};
  }
  if(id==='shelterDoor' && !flags.shelterOpen) {
    if(!inventory.key) return {changed:false,message:'Locked. Find the maintenance key on the scaffold.'};
    flags.shelterOpen=true;
    return {changed:true,message:'Shelter unlocked. Find the power panel inside.'};
  }
  if(id==='power' && flags.shelterOpen && !flags.powerRestored) {
    if(!inventory.battery) return {changed:false,message:'A charged battery is needed. Check the field supplies near the entrance.'};
    inventory.battery--;flags.powerRestored=true;
    return {changed:true,message:'Power restored. The shelter is ready for the night.'};
  }
  if(id==='rest' && flags.powerRestored) return {changed:false,rest:true,message:'Taking a moment to rest…'};
  return {changed:false,message:'Nothing to collect here.'};
}

export function useWater(journey,stamina) {
  if(journey.inventory.water<1) return {changed:false,stamina,message:'No water left in your pack.'};
  if(stamina>.9) return {changed:false,stamina,message:'You are rested. Save your water for later.'};
  journey.inventory.water--;
  return {changed:true,stamina:Math.min(1,stamina+.45),message:'Drank water. Some stamina recovered.'};
}
