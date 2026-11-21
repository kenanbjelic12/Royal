class_name MonsterAI
extends RefCounted
## Per-unit brain: target acquisition and lane/bridge navigation.
## Kept separate from MonsterController (which handles HP, attacks, animation).

const RETARGET_INTERVAL := 0.2

var unit: Node  # MonsterController
var target: Combatant
var _retarget_timer := 0.0

func _init(owner_unit: Node) -> void:
	unit = owner_unit

func can_target(c: Combatant) -> bool:
	if c == null or not c.is_alive() or c.team == unit.team:
		return false
	var d: MonsterData = unit.data
	if d.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
		return c.is_building
	if c.is_flying and not d.can_hit_air:
		return false
	return true

func edge_distance(c: Combatant) -> float:
	return unit.ground_pos().distance_to(c.ground_pos()) - unit.radius - c.radius

func in_attack_range(c: Combatant, extra := 0.0) -> bool:
	return edge_distance(c) <= unit.data.attack_range + extra

## Called every frame; re-evaluates targets on an interval.
func update(delta: float) -> void:
	_retarget_timer -= delta
	var valid := target != null and is_instance_valid(target) and can_target(target)
	if not valid:
		target = null
		_retarget_timer = 0.0
	if _retarget_timer > 0.0:
		return
	_retarget_timer = RETARGET_INTERVAL
	# Locked on a troop or attacking a building -> keep it (Clash-style lock-on).
	if target != null:
		if not target.is_building:
			if edge_distance(target) <= unit.data.sight_range * 1.4:
				return
		elif in_attack_range(target, 0.2):
			return
	var best := find_troop_target()
	if best == null:
		best = find_building_target()
	target = best

func find_troop_target() -> Combatant:
	if unit.data.target_type == MonsterData.TargetType.BUILDINGS_ONLY:
		return null
	var best: Combatant = null
	var best_d := INF
	for c: Combatant in unit.battle.get_enemies_of(unit.team):
		if not can_target(c):
			continue
		var d := edge_distance(c)
		if d <= unit.data.sight_range and d < best_d:
			best_d = d
			best = c
	return best

## Lane princess tower if alive, otherwise the king tower (or anything left).
func find_building_target() -> Combatant:
	var lane := ArenaLayout.lane_of(unit.ground_pos().x)
	var lane_tower: Combatant = null
	var king: Combatant = null
	var any: Combatant = null
	var any_d := INF
	for t: Combatant in unit.battle.get_towers(1 - unit.team):
		if not t.is_alive():
			continue
		if t.get("kind") == &"king":
			king = t
		elif t.get("lane") == lane:
			lane_tower = t
		var d: float = unit.ground_pos().distance_to(t.ground_pos())
		if d < any_d:
			any_d = d
			any = t
	if lane_tower:
		return lane_tower
	if king:
		return king
	return any

## Next point to walk toward, taking bridges into account.
func next_waypoint(dest: Vector3) -> Vector3:
	var pos: Vector3 = unit.ground_pos()
	if unit.is_flying:
		return dest
	var on_bridge_band := absf(pos.z) < ArenaLayout.RIVER_HALF + 0.3
	var side := 0.0 if on_bridge_band else signf(pos.z)
	var dside := signf(dest.z)
	if absf(dest.z) < ArenaLayout.RIVER_HALF + 0.3:
		dside = 0.0
	if side == dside or (side != 0.0 and dside == 0.0 and ArenaLayout.in_bridge_corridor(dest.x)):
		return dest
	var bx := _choose_bridge(pos, dest)
	var exit_z := (dside if dside != 0.0 else -side) * (ArenaLayout.RIVER_HALF + 1.3)
	if side == 0.0:
		# on the bridge: go straight across, staying inside the corridor
		var cx := clampf(pos.x, bx - ArenaLayout.BRIDGE_HALF_W + 0.4, bx + ArenaLayout.BRIDGE_HALF_W - 0.4)
		return Vector3(cx, 0, exit_z)
	var approach := Vector3(bx, 0, side * (ArenaLayout.RIVER_HALF + 1.1))
	var corridor := absf(pos.x - bx) < ArenaLayout.BRIDGE_HALF_W - 0.35
	if corridor and absf(pos.z) < ArenaLayout.RIVER_HALF + 1.6:
		return Vector3(clampf(pos.x, bx - 0.6, bx + 0.6), 0, exit_z)
	return approach

func _choose_bridge(pos: Vector3, dest: Vector3) -> float:
	var best: float = ArenaLayout.BRIDGE_X[0]
	var best_cost := INF
	for bx: float in ArenaLayout.BRIDGE_X:
		var cost := Vector2(pos.x - bx, absf(pos.z)).length() + Vector2(dest.x - bx, absf(dest.z)).length()
		if cost < best_cost:
			best_cost = cost
			best = bx
	return best
