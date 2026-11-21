class_name CardManager
extends Node
## Player hand + placement. Supports tap card -> tap arena, and drag & drop.
## While a card is selected a ghost of the monster performs its special
## "select" animation at the (clamped) placement point.

signal selection_changed(index: int)
signal deployed(index: int, data: MonsterData)
signal deploy_failed(reason: String)

var battle: BattleManager
var team := 0
var hand: Array[MonsterData] = []
var selected := -1
var _ghost: Node3D
var _ghost_model: MonsterModel
var _ghost_ring: MeshInstance3D
var _ghost_ring_mat: StandardMaterial3D
var _ghost_range: MeshInstance3D
var _last_ghost_pos := Vector3.ZERO
var _hover_valid := false

func setup(p_battle: BattleManager, p_team: int) -> void:
	battle = p_battle
	team = p_team
	hand = CardDatabase.deck()

func can_play(i: int) -> bool:
	return i >= 0 and i < hand.size() and battle.elixir[team].can_afford(hand[i].elixir_cost) and not battle.is_finished()

func select(i: int) -> void:
	if i == selected or i < 0 or i >= hand.size():
		deselect()
		return
	selected = i
	AudioManager.play(&"card_select")
	_make_ghost(hand[i])
	battle.arena.show_deploy_overlay(true, battle.open_enemy_lanes(team))
	selection_changed.emit(selected)

func deselect() -> void:
	if selected == -1:
		return
	selected = -1
	_clear_ghost()
	battle.arena.show_deploy_overlay(false)
	selection_changed.emit(-1)

## Moves the ghost under the pointer (screen coordinates).
func update_hover(screen_pos: Vector2) -> void:
	if selected < 0 or _ghost == null:
		return
	var g = battle.screen_to_ground(screen_pos)
	if g == null:
		_ghost.visible = false
		return
	var p: Vector3 = g
	var lanes := battle.open_enemy_lanes(team)
	_hover_valid = ArenaLayout.is_valid_deploy(team, p, lanes)
	var clamped := ArenaLayout.clamp_deploy(team, p, lanes)
	_ghost.visible = true
	_last_ghost_pos = clamped
	_ghost.position = clamped
	_ghost_ring_mat.albedo_color = Color(1, 1, 1, 0.8) if _hover_valid else Color(1, 0.85, 0.3, 0.8)

func hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false

## Attempts to place the selected card at a screen position (clamped onto the
## nearest valid tile of the player's half, like in most lane battlers).
func try_deploy(screen_pos: Vector2) -> bool:
	if selected < 0:
		return false
	var g = battle.screen_to_ground(screen_pos)
	if g == null:
		return false
	return try_deploy_world(g)

func try_deploy_world(world: Vector3) -> bool:
	if selected < 0:
		return false
	var data := hand[selected]
	if not battle.elixir[team].can_afford(data.elixir_cost):
		AudioManager.play(&"error")
		deploy_failed.emit("Not enough elixir!")
		return false
	var p := ArenaLayout.clamp_deploy(team, world, battle.open_enemy_lanes(team))
	if battle.deploy_card(team, data, p):
		var idx := selected
		deselect()
		deployed.emit(idx, data)
		return true
	AudioManager.play(&"error")
	deploy_failed.emit("Can't deploy there!")
	return false

func _unhandled_input(event: InputEvent) -> void:
	if selected < 0:
		return
	if event is InputEventMouseMotion:
		update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			update_hover(event.position)
			try_deploy(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			deselect()

# ------------------------------------------------------------------ ghost
func _make_ghost(data: MonsterData) -> void:
	_clear_ghost()
	_ghost = Node3D.new()
	_ghost.name = "DeployGhost"
	battle.add_child(_ghost)
	_ghost.visible = false
	_ghost_model = MonsterFactory.create_model(data)
	_ghost_model.team_color = battle.team_color(team)
	_ghost.add_child(_ghost_model)
	_ghost_model.scale = Vector3.ONE * data.model_scale * ArenaLayout.UNIT_VISUAL_SCALE
	_ghost_model.position.y = ArenaLayout.FLY_HEIGHT if data.is_flying else 0.0
	_ghost_model.rotation.y = 0.0 if team == 0 else PI
	_ghost_model.status_tint = Color(1, 1, 1, 0.25)
	_ghost_model.play_select()
	_ghost_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = data.radius * 1.1
	tm.outer_radius = data.radius * 1.35
	tm.rings = 32
	_ghost_ring.mesh = tm
	_ghost_ring.scale = Vector3(1, 0.05, 1)
	_ghost_ring.position.y = 0.06
	_ghost_ring_mat = StandardMaterial3D.new()
	_ghost_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ring_mat.albedo_color = Color(1, 1, 1, 0.8)
	_ghost_ring.material_override = _ghost_ring_mat
	_ghost.add_child(_ghost_ring)
	# attack range preview for ranged monsters
	if data.attack_range >= 2.0:
		_ghost_range = MeshInstance3D.new()
		var rm := TorusMesh.new()
		var r := data.attack_range + data.radius
		rm.inner_radius = r - 0.06
		rm.outer_radius = r
		rm.rings = 64
		_ghost_range.mesh = rm
		_ghost_range.scale = Vector3(1, 0.05, 1)
		_ghost_range.position.y = 0.05
		var m := _ghost_ring_mat.duplicate() as StandardMaterial3D
		m.albedo_color = Color(1, 1, 1, 0.35)
		_ghost_range.material_override = m
		_ghost.add_child(_ghost_range)

func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_ghost_model = null

func _process(_delta: float) -> void:
	# loop the special animation while the card stays selected
	if _ghost_model and _ghost_model.select_t < 0.0:
		_ghost_model.play_select()
