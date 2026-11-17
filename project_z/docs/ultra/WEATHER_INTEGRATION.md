# Weather integration

The city state owns the time and weather selection. The atmosphere controller follows that state and publishes shader globals without visiting every material or streamed block.

- `pz_weather` contains rain intensity, accumulated wetness, cloud coverage and puddle retention.
- `pz_wind` contains planar direction, wind strength and approximate daylight.
- `pz_quality` selects Low, Medium or High shader workloads.

Wetness increases in rain and dries faster in daylight. Procedural puddles use a longer drying curve and fade with camera distance. Exterior materials opt in using `wet_exposure`. Indoor floor presets use zero exposure. A periodic upward collision ray checks shelter for camera-local rain particles, while the existing weather selection drives rain audio integration.
