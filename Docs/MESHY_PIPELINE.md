# Meshy AI → Godot pipeline (manual)

## Status

Meshy AI was **not** used to generate the current models. Meshy's API requires a
paid plan / API key; no key exists in this environment, and the brief says not to
buy credits or work around limits. Instead, all five monsters (and the towers) are
**original, procedurally built stylised models** (`Scripts/Models/*Model.gd`) with
procedural animations. They are real in-game models, not coloured copies of one mesh.

The game is ready to swap any monster for a Meshy model without code changes.

## How to replace a monster with a Meshy model

1. Generate the model on meshy.ai (free web tier) with the prompt below
   (Text to 3D → *Cartoon* / *Stylized* art style, PBR textures on).
2. Rig it in Meshy (Animate → humanoid / quadruped auto-rig) and add the
   animations listed for the monster. For the dragon, export the base mesh and
   rig in Blender if Meshy's auto-rig fails on wings.
3. Optimise: target 8–15k triangles, 1024² textures (2048² max for the dragon).
4. Export **GLB** (embedded textures) and save it as
   `Assets/Monsters/<id>/<id>.glb`, e.g. `Assets/Monsters/fire_knight/fire_knight.glb`.
5. Open the card in `Data/Cards/<id>.tres` and set **Model Glb Path** to that file.
6. Name the animations so `GLBMonsterModel` can map them (case-insensitive,
   partial match): `Idle`, `Walk` / `Run` / `Fly`, `Attack` / `Cast`, `Hit`,
   `Death`, `Select` (special card-selection animation).
7. Model orientation: facing **-Z**, feet at y = 0, about 1.3 m tall
   (golem about 2.2 m). The game scales models by `UNIT_VISUAL_SCALE` (1.45).
8. Re-render the card art from the new model:
   `godot --path . res://Tools/PortraitRenderer.tscn`
9. QA: `godot --path . res://Tools/ModelViewer.tscn -- id=<id> pose=attack`
   and check it in a real battle (`Tools/Snapshot.tscn`).

## Prompts (visual direction: cute but powerful, big eyes, big head, chibi)

Common suffix for every prompt:
`stylized 3D mobile game character, chibi proportions, oversized head, big expressive
eyes, clean hand-painted PBR textures, bright saturated colours, readable silhouette,
premium collectible game quality, T-pose, full body, no background`

| Card | Prompt |
|---|---|
| Fire Knight | small brave knight in crimson and gold armour, round helmet with open face, determined eyebrows and confident grin, flame plume on the helmet, short cape, holding a huge two-handed greatsword with a glowing orange fire blade |
| Shadow Assassin | cool mysterious ninja in a dark indigo hood with little fox ears, face hidden in shadow except big glowing cyan eyes, mask over the mouth, long magenta scarf, two curved violet daggers held in reverse grip, agile crouched pose, not scary |
| Stone Golem | huge round boulder golem in slate blue-grey stone, small head sunk into the body, big goofy amber eyes, thick stone brow, moss cap with tiny pink flowers on top, cyan crystals on its back, gigantic stone fists, short stubby legs, funny and lovable |
| Frost Dragon | tiny chubby sky-blue baby dragon, huge round eyes, pale belly, small white ice horns and ice spikes down the back, translucent blue wings, crystal tip on the tail, little fangs, cute but powerful |
| Poison Witch | mischievous little witch with a giant bent purple hat with a green band, mint-green hair, cheeky grin, purple robe with glowing green trim, crooked wooden staff topped with a bubbling green poison orb, potion bottle on the belt |

## Animation list per monster

| Card | Animations |
|---|---|
| Fire Knight | Idle, Walk, Attack (overhead cleave), Hit, Death, Select (raise sword) |
| Shadow Assassin | Idle, Run, Attack (double slash), Hit, Death, Select (spin twirl) |
| Stone Golem | Idle, Walk, Attack (double-fist slam), Hit, Death, Select (chest pound) |
| Frost Dragon | Fly, Idle (hover), Attack (ice breath), Hit, Death, Select (loop) |
| Poison Witch | Idle, Walk, Cast (staff thrust), Hit, Death, Select (staff twirl) |
