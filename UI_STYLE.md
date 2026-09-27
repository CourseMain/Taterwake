# Taterland interface direction

Use objects from the village as the basis for menus: seed packets, price tags,
painted workbenches, stock bins and ruled ledgers. Details should explain a
function or belong to that object. Do not scatter scratches, tape or bolts.

| Place | Solid background | Reading surface | Accent |
| --- | --- | --- | --- |
| Mara's seeds | Canvas `#ddc084` | Packet `#e7c78b` | Crop label colours |
| Bram's tools | Navy `#213a4d` | Label `#eee1c5` | Copper `#d8955f` |
| Nell's barn | Barn red `#723e32` | Stock bin `#e6c89f` | Ochre `#ebc781` |

- Panel fills stay the same colour from top to bottom. No gradient washes or
  simulated ambient lighting on shop panels.
- Use dark ink on inventory labels and price tags. Light lettering belongs on
  dark signs, with enough contrast to read at phone scale.
- Frames and buttons use 2–5 px corners. Separate quantities with ruled cells
  and explicit labels, rather than slashes or long strings of inline metadata.
- Seed selection shows the packet, crop name, growth time, seeds and barn count.
  Price tracking belongs in the exchange, not above the planting controls.
- Keep charts, prices, warning states and selected actions easy to distinguish.
  Colour never replaces labels, borders or selection state.
- Fit short shop dialogs to their contents. Long inventories scroll; do not
  shrink readable text or touch targets to fit everything on one screen.

The world can still have real lighting and the furnace can glow. These rules
apply to interface surfaces, not to the farm's weather or day/night lighting.
