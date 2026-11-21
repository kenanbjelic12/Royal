class_name MonsterData
extends Resource
## Pure data for one card + the monster it summons.
## Add new cards by creating a new .tres in res://Data/Cards/ – no code changes
## are needed except a model builder script (or a GLB path) for its visuals.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum TargetType { ANY, BUILDINGS_ONLY }
enum ProjectileType { NONE, ICE_SHARD, POISON_ORB }

@export_group("Card")
@export var id: StringName = &""
@export var display_name: String = ""
@export var role: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var elixir_cost: int = 3
@export var accent_color: Color = Color.WHITE

@export_group("Combat (level 1 values)")
@export var max_hp: float = 500.0
@export var damage: float = 100.0
## Seconds between attacks.
@export var attack_speed: float = 1.2
## Attack reach measured edge-to-edge (world units, 1 tile ~= 1 unit).
@export var attack_range: float = 0.8
## How far the unit looks for enemies to lock on.
@export var sight_range: float = 5.5
## World units per second.
@export var move_speed: float = 1.5
@export var target_type: TargetType = TargetType.ANY
@export var can_hit_air: bool = false
@export var is_flying: bool = false
@export var splash_radius: float = 0.0
@export var projectile: ProjectileType = ProjectileType.NONE
@export var projectile_speed: float = 9.0

@export_group("Special effects")
## Fraction of speed removed from the target (0.35 = 35% slower).
@export var slow_amount: float = 0.0
@export var slow_duration: float = 0.0
@export var poison_dps: float = 0.0
@export var poison_duration: float = 0.0
## Bonus multiplier on the very first hit (assassin ambush).
@export var first_hit_multiplier: float = 1.0

@export_group("Body")
## Collision radius on the ground plane.
@export var radius: float = 0.45
## Pushing weight when units collide (heavier pushes lighter).
@export var mass: float = 1.0
@export var model_scale: float = 1.0
## Script that procedurally builds the stylised model (extends MonsterModel).
@export var model_script: Script
## Optional GLB from Meshy/Blender. If set and the file exists it replaces
## the procedural model (see Docs/MESHY_PIPELINE.md for animation names).
@export_file("*.glb", "*.gltf") var model_glb_path: String = ""
## Card illustration (rendered from the real in-game model).
@export var portrait: Texture2D

@export_group("Audio")
@export var sfx_attack: StringName = &"hit"
@export var sfx_deploy: StringName = &"deploy"

const LEVEL_SCALE := 0.10  # +10% hp / damage per level above 1

static func rarity_name(r: int) -> String:
	return ["Common", "Rare", "Epic", "Legendary"][r]

static func rarity_color(r: int) -> Color:
	return [Color("#9fb3c8"), Color("#ff9c2a"), Color("#c04dff"), Color("#3ff0d8")][r]

func hp_at(level: int) -> float:
	return roundf(max_hp * (1.0 + LEVEL_SCALE * (level - 1)))

func damage_at(level: int) -> float:
	return roundf(damage * (1.0 + LEVEL_SCALE * (level - 1)))

func dps_at(level: int) -> float:
	return damage_at(level) / attack_speed

func speed_label() -> String:
	if move_speed >= 2.6: return "Very Fast"
	if move_speed >= 1.8: return "Fast"
	if move_speed >= 1.2: return "Medium"
	return "Slow"

func range_label() -> String:
	if attack_range >= 2.0: return "%.1f" % attack_range
	return "Melee"

func targets_label() -> String:
	if target_type == TargetType.BUILDINGS_ONLY: return "Buildings"
	return "Air & Ground" if can_hit_air else "Ground"
