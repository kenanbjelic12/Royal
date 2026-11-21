class_name ArenaLayout
extends RefCounted
## Single source of truth for arena geometry. Team 0 = player (bottom, +Z),
## team 1 = enemy (top, -Z). 1 world unit ~= 1 tile.

const HALF_W := 9.0          # playable x in [-9, 9]
const HALF_L := 16.0         # playable z in [-16, 16]
const RIVER_HALF := 1.0      # river occupies z in [-1, 1]
const BRIDGE_X := [-5.5, 5.5]
const BRIDGE_HALF_W := 1.15
const BRIDGE_HALF_LEN := 1.7
const DEPLOY_MIN_Z := 1.6    # own-half deploy starts this far from the centre line
const FLY_HEIGHT := 2.4
## Monsters are drawn bigger than their collision circle for readability.
const UNIT_VISUAL_SCALE := 1.45

const PRINCESS_Z := 10.5
const KING_Z := 13.6
const PRINCESS_RADIUS := 1.25
const KING_RADIUS := 1.6

## Sign of "forward" for a team (player attacks toward -Z).
static func forward_sign(team: int) -> float:
	return -1.0 if team == 0 else 1.0

## Home side sign of a team (player lives on +Z).
static func home_sign(team: int) -> float:
	return 1.0 if team == 0 else -1.0

static func tower_positions(team: int) -> Array:
	var s := home_sign(team)
	return [
		{"kind": &"princess", "pos": Vector3(-5.5, 0, PRINCESS_Z * s), "lane": -1},
		{"kind": &"princess", "pos": Vector3(5.5, 0, PRINCESS_Z * s), "lane": 1},
		{"kind": &"king", "pos": Vector3(0, 0, KING_Z * s), "lane": 0},
	]

static func lane_of(x: float) -> int:
	return -1 if x < 0.0 else 1

static func nearest_bridge_x(x: float) -> float:
	return BRIDGE_X[0] if x < 0.0 else BRIDGE_X[1]

static func in_bridge_corridor(x: float, margin := 0.0) -> bool:
	for bx in BRIDGE_X:
		if absf(x - bx) <= BRIDGE_HALF_W - margin:
			return true
	return false

static func clamp_to_arena(p: Vector3, r: float) -> Vector3:
	p.x = clampf(p.x, -HALF_W + r, HALF_W - r)
	p.z = clampf(p.z, -HALF_L + r, HALF_L - r)
	return p

## Deploy rule: own half, plus the enemy "pocket" of a lane whose enemy
## princess tower is destroyed. `enemy_lane_open` = {-1: bool, 1: bool}.
static func is_valid_deploy(team: int, p: Vector3, enemy_lane_open: Dictionary = {}) -> bool:
	if absf(p.x) > HALF_W - 0.4 or absf(p.z) > HALF_L - 0.4:
		return false
	var s := home_sign(team)
	var local_z := p.z * s  # positive = own half
	var ok := local_z >= DEPLOY_MIN_Z
	if not ok:
		var lane := lane_of(p.x)
		if enemy_lane_open.get(lane, false) and local_z >= -(PRINCESS_Z - 4.0) and absf(p.z) > RIVER_HALF + 0.2:
			ok = true
	return ok

static func clamp_deploy(team: int, p: Vector3, enemy_lane_open: Dictionary = {}) -> Vector3:
	p.x = clampf(p.x, -HALF_W + 0.5, HALF_W - 0.5)
	p.z = clampf(p.z, -HALF_L + 0.5, HALF_L - 0.5)
	if is_valid_deploy(team, p, enemy_lane_open):
		return p
	var s := home_sign(team)
	p.z = DEPLOY_MIN_Z * s
	return p
