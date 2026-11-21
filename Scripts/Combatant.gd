class_name Combatant
extends Node3D
## Shared interface for everything that can be targeted and damaged:
## monsters (MonsterController) and towers (TowerController).

signal died(who: Combatant)
signal damaged(who: Combatant, amount: float)

var team := 0
var max_hp := 100.0
var hp := 100.0
var radius := 0.5
var mass := 1.0
var is_building := false
var is_flying := false
var level := 1
var display_name := ""
var battle: Node  # BattleManager

# status effects
var slow_amount := 0.0
var slow_time := 0.0
var poison_dps := 0.0
var poison_time := 0.0
var _poison_tick := 0.0
var _poison_source: Combatant

func is_alive() -> bool:
	return hp > 0.0 and is_inside_tree() and not is_queued_for_deletion()

## Ground-plane position (y = 0) used by all gameplay logic.
func ground_pos() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## Point projectiles should fly to.
func aim_point() -> Vector3:
	return ground_pos() + Vector3(0, (ArenaLayout.FLY_HEIGHT + 0.3) if is_flying else 0.7, 0)

func take_damage(amount: float, _source: Combatant = null) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(self, amount)
	_on_damaged(amount)
	if hp <= 0.0:
		_die()

func apply_slow(amount: float, duration: float) -> void:
	if amount <= 0.0 or is_building:
		return
	slow_amount = maxf(slow_amount, amount)
	slow_time = maxf(slow_time, duration)

func apply_poison(dps: float, duration: float, source: Combatant = null) -> void:
	if dps <= 0.0:
		return
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)
	_poison_source = source

func speed_factor() -> float:
	return 1.0 - (slow_amount if slow_time > 0.0 else 0.0)

func _tick_status(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_amount = 0.0
	if poison_time > 0.0:
		poison_time -= delta
		_poison_tick += delta
		if _poison_tick >= 0.5:
			_poison_tick -= 0.5
			take_damage(poison_dps * 0.5, _poison_source if is_instance_valid(_poison_source) else null)
		if poison_time <= 0.0:
			poison_dps = 0.0
			_poison_tick = 0.0

func _on_damaged(_amount: float) -> void:
	pass

func _die() -> void:
	died.emit(self)
