# AFTERFALL

## Browser-Based AI Open-World Zombie Survival Simulation

### Product Requirements Document
Version 1.0

---

# 1. PRODUCT VISION

AFTERFALL is a high-fidelity open-world survival simulation set in a fictional Indian metropolis heavily inspired by Hyderabad.

The apocalypse is not a temporary level.

It is the player's new life.

The objective is not to cure the infection or follow a linear campaign.

The player should be able to:

- survive
- explore
- build relationships
- create a home
- form communities
- establish safe zones
- lose people
- develop skills
- gain enemies
- gain allies
- build a reputation
- encounter factions
- travel
- scavenge
- build
- trade
- fight
- avoid fighting
- fall in love
- experience grief
- change as a person

The player is one person inside a world that continues without them.

---

# 2. PLATFORM

Initial platform:

Desktop browsers only.

Primary targets:

- Chrome
- Edge
- Chromium-based desktop browsers

Recommended minimum hardware target:

- 16 GB RAM
- modern 6-core CPU
- dedicated GPU equivalent to GTX 1660 / RX 5600 or greater

Recommended hardware:

- RTX 3060 / RX 6700 class or greater
- 16–32 GB RAM
- SSD

Resolution target:

1920×1080.

Performance target:

60 FPS on recommended hardware.

Acceptable high-quality target:

45–60 FPS.

---

# 3. VISUAL TARGET

The intention is NOT to technically reproduce GTA VI.

The desired feeling is:

**AAA cinematic open-world presentation inside a browser.**

Target qualities:

- realistic PBR materials
- highly detailed nearby environments
- cinematic lighting
- physically believable shadows
- dense vegetation
- atmospheric fog
- volumetric-feeling weather
- wet roads
- puddles
- reflections
- realistic character proportions
- convincing animation
- abandoned vehicles
- environmental storytelling
- debris
- interiors
- dynamic time of day
- weather transitions
- strong ambient audio
- realistic camera movement

The game should avoid looking like:

- a Roblox game
- a low-poly survival game
- a generic Three.js tech demo
- a voxel Minecraft clone

Minecraft should inspire the **streaming architecture**, not the art direction.

---

# 4. CUSTOM OPEN WORLD

## 4.1 City

The city is fictional.

Working name:

## Hyderabad Exclusion Zone

The environment should visually reference Hyderabad and South Indian urban architecture without attempting a literal 1:1 map.

This allows us to combine:

- modern Hyderabad
- dense old-city streets
- IT districts
- residential colonies
- highways
- rocky terrain
- lakes
- villages
- forests
- industrial districts

into a world optimized for gameplay.

---

# 5. WORLD SIZE

Do NOT attempt the entire world immediately.

Development progression:

### Prototype

1 km × 1 km

### Vertical Slice

2 km × 2 km

### Early Alpha

4 km × 4 km

### Full World Target

Approximately:

8 km × 8 km

Logical area:

64 km².

The complete 64 km² is NEVER loaded simultaneously.

Only the surrounding world exists at maximum graphical detail.

---

# 6. OPEN-WORLD MAP

The world is divided into major regions.

## REGION 1 — Ground Zero

Dense central urban area.

This is where the outbreak initially became uncontrollable.

Environment:

- apartments
- shops
- hospitals
- offices
- metro structures
- collapsed barricades
- buses
- abandoned vehicles
- military checkpoints
- narrow streets

Zombie population:

Extremely high.

Loot:

Extremely high.

Danger:

Extreme.

---

# REGION 2 — Old City

Inspired by historic Hyderabad.

Environment:

- dense bazaars
- narrow alleys
- old stone architecture
- markets
- residential rooftops
- courtyards
- mosques
- old commercial buildings

Gameplay focus:

Close-range exploration.

Rooftop traversal.

Extremely limited vehicle movement.

High zombie density.

---

# REGION 3 — Financial District

Modern business district.

Inspired by HITEC City / Gachibowli.

Environment:

- skyscrapers
- corporate campuses
- hotels
- luxury apartments
- parking structures
- glass office towers
- malls

This region includes the building where the player crashes during the opening sequence.

Lissie's original hideout exists here.

---

# REGION 4 — Residential Belt

Large suburbs.

Environment:

- houses
- apartments
- gated communities
- schools
- supermarkets
- parks
- clinics

Important because these areas contain:

- food
- clothes
- domestic supplies
- survivor groups
- potential safe houses

---

# REGION 5 — Industrial Zone

Factories and warehouses.

Contains:

- fuel
- industrial tools
- generators
- machinery
- chemicals
- vehicle components
- construction materials

Potential faction territory.

---

# REGION 6 — Outer Highway

Large arterial roads connecting districts.

Contains:

- abandoned traffic
- military roadblocks
- overturned trucks
- evacuation camps
- fuel stations
- crashed vehicles

Vehicles become especially useful here.

---

# REGION 7 — Quarry / Rocky Hills

Inspired by Hyderabad's rocky terrain.

Environment:

- granite formations
- quarries
- caves
- hilltop viewpoints
- abandoned construction projects

Lower zombie population.

High visibility.

Possible long-term settlement locations.

---

# REGION 8 — Forest Belt

Semi-rural outskirts.

Environment:

- scrub forest
- farms
- dirt roads
- abandoned villages
- small water bodies
- electrical infrastructure

Threats gradually shift from zombies toward survival itself.

---

# REGION 9 — Reservoir

Large artificial lake/reservoir.

Contains:

- dam
- maintenance facility
- fishing areas
- flooded structures
- abandoned boats

Water becomes strategically important.

---

# REGION 10 — Military Exclusion Zone

Late-game high-risk region.

Contains:

- military staging areas
- helicopter wreckage
- temporary hospitals
- ammunition storage
- damaged armored vehicles
- classified outbreak evidence

It is NOT the game's ending.

It is simply another region.

---

# 7. MAP DESIGN PHILOSOPHY

Avoid creating a giant empty environment.

Every district must have:

### Primary landmarks

Large recognizable structures.

### Secondary landmarks

Shops, stations, schools, apartments.

### Micro landmarks

Small memorable environmental details.

Examples:

- crashed ambulance
- burned restaurant
- barricaded pharmacy
- rooftop garden
- abandoned wedding hall
- damaged police station
- flooded underpass
- overturned bus

These allow the player to navigate using memory.

---

# 8. WORLD STREAMING

This is one of the most important technical systems.

The open world is separated into:

## Macro Cells

256 m × 256 m.

Each stores:

- terrain
- streets
- large buildings
- vegetation zones
- spawn metadata
- navigation metadata

Each macro cell contains:

## Sub-Chunks

64 m × 64 m.

These contain actual renderable objects.

Only nearby sub-chunks are loaded.

---

# 9. STREAMING RINGS

Around the player:

### Ring 0

0–80 metres.

Maximum detail.

Includes:

- physics
- detailed textures
- interactive objects
- characters
- zombies
- particles
- interiors

### Ring 1

80–250 metres.

High-detail models.

Reduced physics.

### Ring 2

250–600 metres.

Medium-detail meshes.

NPC simulation simplified.

### Ring 3

600–1500 metres.

Low-poly silhouettes.

Major buildings.

Tree clusters.

Terrain.

### Ring 4

Beyond 1500 metres.

Skyline impostors.

Terrain heightfield.

Atmospheric approximation.

No individual objects.

---

# 10. CHUNK LOADING

Movement must NOT cause visible loading screens.

When the player approaches the edge of the current region:

Worker threads begin preparing neighbouring chunks.

Pipeline:

PLAYER MOVES

↓

Predict movement

↓

Identify needed chunks

↓

Load compressed assets

↓

Generate procedural objects

↓

Build collision data

↓

Prepare navigation data

↓

Upload GPU resources

↓

Activate chunk

Old chunks become:

HIBERNATED

rather than destroyed immediately.

Recently visited areas remain temporarily cached.

---

# 11. WORLD GENERATION

The world uses hybrid generation.

Not pure procedural generation.

Not purely handmade.

## Handmade

Used for:

- landmarks
- important buildings
- story locations
- survivor camps
- Lissie's locations
- hospitals
- military locations

## Procedural

Used for:

- minor buildings
- apartments
- vegetation
- abandoned cars
- debris
- furniture
- garbage
- loot placement
- road damage
- small interiors

This dramatically increases world scale without requiring every metre to be manually designed.

---

# 12. BUILDING SYSTEM

Buildings contain three categories.

### Tier A

Fully explorable.

Major story/location buildings.

### Tier B

Procedurally explorable.

Reusable interior modules.

### Tier C

Exterior only.

Background buildings.

The player should never know which category from appearance alone.

---

# 13. WORLD PERSISTENCE

Changes made by the player remain.

Example:

Player enters a supermarket.

They remove:

- canned food
- water
- medicine

The game records those items as gone.

Coming back later does NOT regenerate them.

Similarly:

- doors remain broken
- containers remain looted
- bodies remain
- cars remain moved
- barricades remain
- player-built structures remain

until physical processes modify them.

---

# 14. WORLD DEGENERATION

Civilization gradually decays.

Track:

WORLD AGE

Example:

Day 1

City mostly intact.

Day 7

Garbage accumulating.

Electricity unreliable.

Day 20

Vegetation spreading.

Vehicles rusting.

Bodies decomposing.

Day 60

Roads becoming obstructed.

Buildings weathered.

Plants growing through structures.

Year 1

Nature visibly reclaiming large areas.

The visual world changes according to time.

---

# 15. WEATHER

Dynamic weather simulation.

Possible states:

- clear
- overcast
- drizzle
- rain
- heavy rain
- thunderstorm
- haze
- fog
- extreme heat

Weather affects gameplay.

Rain:

- reduces visibility
- reduces zombie hearing range
- makes surfaces slippery
- creates puddles
- increases wetness
- lowers temperature

Heat:

- increases dehydration
- increases stamina drain

Storms:

- reduce visibility
- mask sound
- affect electrical systems

---

# 16. SEASONS

The world progresses through believable regional seasonal conditions.

Broad phases:

### Hot Season

Hot and dry.

### Monsoon

Frequent rain.

Flooding.

Green vegetation.

### Post-Monsoon

Moderate weather.

### Winter

Cooler and drier.

Season influences:

- plant growth
- water availability
- temperature
- clothing
- disease
- visibility
- food availability

---

# 17. DAY/NIGHT CYCLE

Target default:

1 real minute approximately equals 10–15 game minutes.

Configurable.

Cycle includes:

- sunrise
- morning
- afternoon
- sunset
- dusk
- night

Lighting should transition continuously.

Night must actually be dangerous.

Artificial light matters.

---

# 18. ELECTRICITY

Electricity exists as a world system.

Initial grid:

unstable.

Eventually:

mostly offline.

Certain districts may temporarily retain electricity.

Players can restore local power using:

- generators
- batteries
- solar equipment
- repaired infrastructure

Electricity powers:

- lights
- refrigerators
- pumps
- equipment
- doors
- communications

---

# 19. WATER

Water is simulated as a strategic resource.

Sources:

- bottled water
- tanks
- municipal supply
- wells
- rainwater
- reservoirs

Water may become contaminated.

Water must sometimes be:

- filtered
- boiled
- chemically treated

---

# 20. FIRE

Fire spreads according to:

- combustible materials
- wind
- moisture
- fuel
- nearby structures

Fire produces:

- heat
- smoke
- light
- damage

Large uncontrolled fires can change parts of the map permanently.

---

# 21. PHYSICS

Use physically believable interactions.

Core physics:

- rigid bodies
- vehicle collisions
- ragdolls
- gravity
- projectiles
- doors
- movable objects
- debris
- falling objects

Not everything receives full physics simultaneously.

Physics activation radius surrounds the player.

Outside that radius objects become simplified or sleeping states.

---

# 22. PLAYER

Player starts as a normal human.

No classes.

No RPG character selection.

Skills develop through use.

Examples:

Running improves endurance.

Carrying increases practical strength.

Treating wounds improves medical ability.

Repairing vehicles improves mechanical ability.

Shooting improves weapon handling.

---

# 23. HEALTH

No simple:

100 HP

system.

Track:

- blood volume
- pain
- wounds
- fracture state
- infection
- body temperature
- hydration
- calories
- exhaustion
- consciousness

Different injuries affect different actions.

---

# 24. OPENING INJURY

The player's right leg begins with:

severe laceration and tissue damage.

Effects:

- major blood loss
- extreme pain
- limited weight bearing
- reduced movement
- dizziness
- unconsciousness risk

Lissie has stabilized the wound.

She has NOT magically healed it.

Recovery becomes part of the opening survival experience.

---

# 25. ZOMBIE INFECTION

Choose one scientific model and NEVER randomly change it.

Recommended model:

Neurotropic viral infection.

Transmission:

- bites
- infected blood entering open wounds
- contaminated bodily fluid exposure

NOT airborne during normal gameplay.

Incubation:

Variable.

Approximately several hours to two days depending on exposure.

Symptoms progress through predictable stages.

---

# 26. ZOMBIE BEHAVIOUR

Zombies detect using:

### Vision

Movement and contrast.

### Hearing

Gunshots.

Breaking glass.

Running.

Vehicles.

### Smell

Very close proximity only.

They do NOT magically know player position.

---

# 27. ZOMBIE STATES

Possible behaviour states:

Idle

↓

Investigate

↓

Alert

↓

Chase

↓

Attack

↓

Search

↓

Return/Wander

Zombie crowds can naturally form when many individuals respond to the same stimulus.

---

# 28. ZOMBIE SIMULATION LOD

Nearby zombies:

Full AI.

Farther zombies:

Simplified movement.

Very distant zombies:

Statistical simulation only.

Example:

Instead of simulating 4,000 individual zombies across the entire map:

District A stores:

Zombie Population = 2,416

Only the population near the player becomes physical AI agents.

---

# 29. NPC SYSTEM

Human NPCs must not exist merely to give quests.

Every important NPC stores:

- identity
- personality
- current goal
- fear
- skills
- relationships
- possessions
- location
- health
- memories
- opinion of player

NPCs can act independently.

---

# 30. LISSIE

Lissie is one of the most sophisticated NPCs.

Initial traits:

- cold
- observant
- guarded
- pragmatic
- distrustful
- emotionally controlled
- capable

She does NOT automatically like the player.

Relationship variables include:

Trust

Respect

Fear

Attachment

Resentment

Reliability

Familiarity

These values are hidden from the player.

---

# 31. RELATIONSHIP SYSTEM

Relationships develop from events.

Examples:

Keeping promises increases trust.

Repeated recklessness can reduce respect.

Saving someone can create gratitude.

Manipulating someone can create resentment.

Constant flirting does NOT automatically produce romance.

NPC personality determines reactions.

---

# 32. AI DIALOGUE

Use a hybrid AI architecture.

Do NOT allow an LLM to control the entire game.

Deterministic game simulation controls:

- health
- physics
- inventory
- location
- relationships
- world state
- combat

The AI narrative layer receives structured world information.

Example context:

NPC: Lissie
Trust: 17/100
Mood: annoyed
Player injury: severe
Location: abandoned office
Time: 03:41
Relationship: stranger
Recent event: player woke after unconsciousness

AI generates dialogue compatible with these facts.

The LLM cannot change game state directly.

It requests actions through validated game commands.

---

# 33. NPC MEMORY

NPC memories are event records.

Example:

EVENT:
Player shared food.

NPC:
Lissie

Time:
Day 4

Importance:
Medium

Emotional effect:
Trust +4

Memory can later influence dialogue.

Old trivial memories can be compressed.

Important memories persist indefinitely.

---

# 34. NPC SCHEDULES

NPCs continue living when the player leaves.

Possible activities:

- sleeping
- guarding
- scavenging
- repairing
- cooking
- talking
- travelling
- exploring
- fighting
- treating wounds

Distant NPC behaviour uses background simulation.

---

# 35. FACTIONS

Groups emerge dynamically.

Examples:

survivor communities

military remnants

criminal groups

medical groups

traders

isolated families

religious communities

neighbourhood defenders

Factions require:

- resources
- leadership
- territory
- relationships
- morale

They can split or collapse.

---

# 36. ECONOMY

No magical shop interface.

Trade happens between people.

Valuable resources change with circumstances.

Early apocalypse:

money may still have limited perceived value.

Later:

water
food
medicine
fuel
batteries
ammunition
tools

become more valuable.

---

# 37. BASE BUILDING

The player can claim existing buildings.

Examples:

house

warehouse

apartment

office

farm

school

Player can:

- barricade entrances
- repair doors
- reinforce windows
- install storage
- build beds
- install generators
- collect water
- establish lighting
- build defensive structures

---

# 38. VEHICLES

Eventually support:

- cars
- SUVs
- motorcycles
- trucks

Vehicles require:

- fuel
- battery
- intact tires
- functional engine
- maintenance

Abandoned vehicles are not automatically usable.

---

# 39. SOUND

Sound is gameplay.

Every significant event creates a sound radius.

Example:

Walking:
small radius.

Running:
larger.

Breaking glass:
large.

Gunfire:
extremely large.

Vehicle engine:
continuous sound source.

Zombies react accordingly.

---

# 40. AUDIO DESIGN

Environmental audio should include:

- distant gunshots
- aircraft
- thunder
- dogs
- alarms
- wind
- insects
- electrical buzzing
- zombie vocalizations
- falling objects
- distant survivor activity

The audio environment gradually changes as civilization collapses.

---

# 41. USER INTERFACE

Keep HUD minimal.

Do NOT display:

HP: 72/100

Use physical information.

Examples:

Blood loss:
screen desaturation and weakness.

Pain:
animation and breathing.

Thirst:
character behaviour and subtle indicator.

Inventory appears only when required.

---

# 42. GRAPHICS PIPELINE

Recommended rendering architecture:

Three.js

WebGPU-first rendering

WebGL2 fallback

PBR materials

glTF / GLB assets

Compressed GPU textures

LOD meshes

Instanced vegetation

Instanced debris

GPU particles

Dynamic shadows

Temporal-style anti-aliasing where viable

Screen-space atmospheric effects

Post-processing

---

# 43. PERFORMANCE PHILOSOPHY

Do NOT render everything.

Every system needs:

LOD.

This includes:

- buildings
- geometry
- textures
- vegetation
- animation
- NPC AI
- zombies
- physics
- audio
- shadows

High simulation fidelity exists around the player.

Increasing distance means decreasing simulation complexity.

---

# 44. WORLD WORKERS

Move heavy generation away from the primary rendering thread.

Workers should handle:

- chunk preparation
- procedural placement
- navigation preparation
- loot generation
- world simulation calculations

Main thread primarily handles:

- rendering
- input
- immediate gameplay

---

# 45. CACHE

Downloaded/generated chunks can be cached locally.

Use IndexedDB where useful.

Benefits:

Returning to areas becomes much faster.

Generated procedural metadata does not need to be recreated continuously.

---

# 46. SAVE SYSTEM

Save:

- player state
- current time
- weather
- injuries
- relationships
- inventory
- NPC status
- faction status
- looted locations
- opened doors
- destroyed objects
- vehicles
- world modifications
- base construction
- important memories

Autosave periodically.

Also save during important state transitions.

---

# 47. DEVELOPMENT PHASES

## PHASE 0 — Technical Benchmark

Build one highly detailed street.

Goal:

Prove browser rendering target.

Include:

- buildings
- realistic materials
- lighting
- vegetation
- abandoned vehicles
- wet road
- third-person character

Required result:

Stable performance before any open-world work.

---

# PHASE 1 — Player Controller

Implement:

- movement
- camera
- sprint
- crouch
- jumping
- basic climbing
- interaction
- footsteps
- stamina

Do NOT build zombies yet.

---

# PHASE 2 — World Streaming

This is the most important engineering milestone.

Create:

- 256 m macro cells
- 64 m sub-chunks
- asynchronous loading
- unloading
- caching
- LOD rings
- background generation
- memory budget

Player must travel continuously without loading screens.

---

# PHASE 3 — Custom City Generator

Build systems generating:

- roads
- intersections
- buildings
- vegetation
- utility objects
- debris
- parked vehicles

Create biome/district rules.

Example:

Old City generator behaves differently from Financial District generator.

---

# PHASE 4 — Weather + Time

Implement:

- sun movement
- dynamic sky
- clouds
- rain
- storms
- wet surfaces
- fog
- temperature
- day/night cycle

---

# PHASE 5 — Physics

Integrate Rapier.

Implement:

- collision
- rigid bodies
- doors
- movable props
- vehicle collision foundations
- ragdolls

Introduce physics LOD.

---

# PHASE 6 — Survival

Implement:

- hunger
- water
- fatigue
- temperature
- wounds
- bleeding
- pain
- infection
- unconsciousness

---

# PHASE 7 — Zombies

Implement:

- perception
- navigation
- states
- combat
- sounds
- crowds
- zombie LOD

Begin with approximately 10 physical zombies.

Then:

50.

Then:

100+ nearby entities using optimization.

---

# PHASE 8 — NPCs

Add human survivors.

Implement:

- movement
- schedules
- needs
- relationships
- inventory
- combat
- memory

Do NOT integrate LLM dialogue yet.

---

# PHASE 9 — AI NPC SYSTEM

Create structured NPC context.

Connect language model.

AI receives world state.

AI generates dialogue.

AI cannot directly manipulate the simulation.

Introduce:

Lissie.

---

# PHASE 10 — Opening Sequence

Build:

Helicopter audio/visual introduction.

Player jump.

Building collision.

Injury.

Escape.

Blackout.

Wake-up sequence.

First interaction with Lissie.

This becomes the polished opening.

---

# PHASE 11 — Persistent Simulation

Implement:

- faction simulation
- NPC travel
- off-screen deaths
- migration
- resource depletion
- zombie population movement
- community development

The world now continues independently.

---

# PHASE 12 — Degeneration

Implement time-driven changes.

Examples:

vegetation growth

dust

mold

rust

body decomposition

road obstruction

building damage

abandoned camps

---

# PHASE 13 — Vehicles

Implement:

- vehicle physics
- fuel
- damage
- maintenance
- sound
- storage
- zombie attraction

---

# PHASE 14 — Base Building

Implement:

- claiming structures
- storage
- barricades
- power
- water
- sleeping
- defensive structures

---

# PHASE 15 — CONTENT EXPANSION

Expand the open world district by district.

Never build the entire 64 km² simultaneously.

Recommended order:

Financial District

↓

Residential Belt

↓

Ground Zero

↓

Old City

↓

Industrial Zone

↓

Highways

↓

Rocky Hills

↓

Forest Belt

↓

Reservoir

↓

Military Zone

---

# 48. AI CODING AGENT MASTER RULES

Every coding-agent prompt should include:

You are working on a production browser-based 3D open-world survival game.

Never replace existing working systems unnecessarily.

Before changing architecture:

1. inspect the repository
2. understand current systems
3. identify dependencies
4. propose minimal compatible architecture
5. implement
6. test
7. profile

Prioritize:

performance

maintainability

modularity

visual quality

browser compatibility

Never sacrifice frame rate for invisible simulation.

Heavy work must be:

streamed

cached

LOD-controlled

worker-threaded where appropriate.

---

# 49. PHASE-BY-PHASE AI BUILD PROMPTS

## PROMPT — PHASE 0

Inspect the complete repository and create a browser-based high-fidelity 3D graphics benchmark.

Create one extremely polished abandoned urban Indian street that establishes the final game's visual language.

Include realistic buildings, damaged roads, abandoned cars, vegetation, debris, physically based materials, atmospheric lighting, shadows, wet surfaces and cinematic post-processing.

Use a WebGPU-first rendering architecture with graceful fallback.

Do not build gameplay systems yet.

Create FPS, draw-call, triangle-count, GPU timing and memory diagnostics.

Optimize until the environment remains smooth on modern desktop gaming hardware.

The result must look like the foundation of a premium open-world game rather than a generic Three.js demonstration.

---

## PROMPT — PHASE 1

Extend the existing project with a production-quality third-person player controller.

Implement walking, jogging, sprinting, crouching, jumping, slopes, stairs, collision, camera collision, acceleration/deceleration, stamina and contextual interaction.

Movement must feel weighted and realistic rather than arcade-like.

Keep character/controller logic separate from rendering.

Build the system so injuries can later modify movement speed, gait and stamina.

Preserve all existing systems.

---

## PROMPT — PHASE 2

Build the core open-world streaming system.

Divide the world into 256 × 256 metre macro cells containing 64 × 64 metre sub-chunks.

Create concentric rendering and simulation LOD rings around the player.

Chunks must asynchronously prepare before the player reaches them.

Use worker threads where appropriate.

Implement chunk activation, hibernation, unloading, caching and memory-budget management.

There must be no visible loading screen while travelling.

Add debugging visualization showing loaded, preparing, cached and unloaded chunks.

This system must be generic enough to support an eventual 8 × 8 km open world.

---

## PROMPT — PHASE 3

Create the procedural custom-city generation framework.

The game is set in a fictional city inspired by Hyderabad.

Create district definitions for:

Financial District
Old City
Residential Belt
Ground Zero
Industrial Zone
Outer Highway
Rocky Hills
Forest Belt
Reservoir
Military Zone

Each district must have unique generation rules for architecture, roads, vegetation, density, props and environmental storytelling.

Important landmarks remain handcrafted.

Minor structures should be procedurally composed from modular pieces.

Generation must be deterministic using world seeds.

---

## PROMPT — PHASE 4

Implement a physically believable time-of-day and weather framework.

Add continuously changing sun position, sky conditions, cloud coverage, fog, wind, rain and storms.

Rain must create convincing visual wetness and puddle behaviour.

Weather should affect visibility, audio and later gameplay systems.

Create regional seasonal states appropriate to the fictional Hyderabad-inspired environment.

Ensure weather transitions occur gradually rather than switching instantly.

---

## PROMPT — PHASE 5

Integrate production-quality 3D physics using Rapier.

Implement static collision, dynamic rigid bodies, doors, debris, movable furniture, falling objects and environmental collisions.

Create physics activation radii.

Nearby objects receive full physics.

Distant objects must sleep or use simplified states.

Prevent thousands of distant objects from consuming physics CPU time.

Add a comprehensive physics debug mode.

---

## PROMPT — PHASE 6

Build the survival physiology simulation.

Do not use a conventional 100 HP model.

Track wounds, bleeding, approximate blood loss, pain, hydration, energy, fatigue, body temperature, consciousness and infection.

Create body-location injuries.

The player's opening right-leg injury must severely affect walking and stamina.

Healing must require believable time, treatment and rest.

Design every variable as a modular simulation system so balancing can later be adjusted through configuration.

---

## PROMPT — PHASE 7

Implement the zombie simulation.

Create consistent biologically grounded infected humans.

Implement hearing, sight and close-range detection.

Use behaviour states:

idle
wander
investigate
alert
chase
attack
search

Sound events must attract infected realistically.

Create zombie simulation LOD.

Only nearby infected should use expensive navigation and animation.

Distant zombie populations should exist statistically until approaching the player.

---

## PROMPT — PHASE 8

Create autonomous survivor NPC architecture.

NPCs must possess:

identity
personality
goals
needs
skills
health
inventory
relationships
memory
location
schedule

NPCs must be able to perform basic behaviour without the player.

Do not use an LLM yet.

Build deterministic behaviour first.

Characters should be capable of disagreeing, refusing requests, leaving groups and acting according to their own priorities.

---

## PROMPT — PHASE 9

Integrate the AI dialogue layer.

The language model must NEVER become the authoritative game simulation.

The deterministic simulation provides structured context containing character state, relationship state, memories, current environment and recent events.

The model generates natural dialogue and limited high-level intentions.

Any requested action must pass through validated game commands before changing world state.

Implement memory summarization so important character experiences persist without unlimited context growth.

Create Lissie using the personality specification in the design documentation.

Her relationship with the player must develop gradually and must never default to romance.

---

## PROMPT — PHASE 10

Create the complete opening experience.

The sequence begins during the failed evacuation.

After the player's fall and desperate escape, transition into unconsciousness.

The playable game begins as the player regains consciousness inside an unfamiliar abandoned office/storage building.

The right leg is heavily bandaged.

Lissie is sitting nearby with her hood raised and mask on.

Build cinematic environmental storytelling using lighting, animation, breathing, rain, distant gunfire and environmental audio.

Avoid exposition.

Allow the player to regain control naturally.

---

# 50. VERTICAL SLICE DEFINITION

Do NOT attempt the complete game before proving this slice.

The first truly playable version contains:

Approximately 2 km × 2 km.

One financial district.

One residential zone.

One hospital.

One supermarket.

One police station.

One survivor hideout.

One highway segment.

Lissie.

Approximately 5–10 recurring NPCs.

Zombie population simulation.

Weather.

Day/night.

Basic survival.

Basic scavenging.

Persistent inventory.

Persistent environment.

Streaming.

One usable vehicle later in the slice.

This vertical slice should demonstrate the entire philosophy of AFTERFALL.

Only then should world expansion begin.

---

# 51. PERFORMANCE BUDGET

Target approximately:

60 FPS.

Frame budget at 60 FPS:

16.67 ms.

Approximate goal:

Game simulation:
2–4 ms

Physics:
1–3 ms

AI:
1–2 ms

Rendering preparation:
2–3 ms

GPU:
under approximately 12–14 ms

Actual budgets must be determined through profiling rather than assumptions.

---

# 52. CORE ARCHITECTURE

Recommended high-level architecture:

GameApp

├── Renderer
│   ├── WorldRenderer
│   ├── CharacterRenderer
│   ├── WeatherRenderer
│   └── PostProcessing
│
├── World
│   ├── ChunkManager
│   ├── DistrictManager
│   ├── ProceduralGenerator
│   ├── PersistenceManager
│   └── WorldClock
│
├── Simulation
│   ├── Weather
│   ├── Ecology
│   ├── ZombiePopulation
│   ├── Survivors
│   ├── Factions
│   └── Degeneration
│
├── Physics
│   └── RapierWorld
│
├── Player
│   ├── Controller
│   ├── Health
│   ├── Inventory
│   └── Skills
│
├── AI
│   ├── Navigation
│   ├── Behaviour
│   ├── Dialogue
│   ├── Memory
│   └── Relationships
│
├── Audio
│
├── UI
│
└── SaveSystem

Never create a single giant Game.ts file.

---

# 53. FIRST DEVELOPMENT GOAL

Do not begin by creating:

64 km².

Do not begin with:

1000 zombies.

Do not begin with:

LLM conversations.

Do not begin with:

vehicles.

The first milestone is:

**One street that looks incredible and runs smoothly.**

Then:

**One city block that feels alive.**

Then:

**One kilometre that streams correctly.**

Only after those systems work should the map grow.

The fundamental rule of AFTERFALL development is:

### BUILD DEPTH FIRST.

### SCALE SECOND.