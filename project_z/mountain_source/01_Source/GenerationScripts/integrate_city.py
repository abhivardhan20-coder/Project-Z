"""Verify the built-in integration; no second project or copied addon is needed."""
from pathlib import Path
game=Path(__file__).resolve().parents[3]
assert 'kaldran_world.gd' in (game/'scenes/world/kaldran_city.tscn').read_text()
for name in ('scripts/city/mountain_world.gd','scenes/editable_sector.tscn','Data/world.json'):
    assert (game/name).is_file(),name
print('City integration is built in; one canonical set of mountain assets.')
