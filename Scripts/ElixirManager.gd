class_name ElixirManager
extends Node
## Elixir pool for one side. Max 10, regenerates automatically
## (1 elixir every 2.8 s, twice as fast during double elixir time).

signal changed(value: float)

const MAX_ELIXIR := 10.0
const REGEN_SECONDS := 2.8
const START_ELIXIR := 5.0

var team := 0
var elixir := START_ELIXIR
var multiplier := 1.0
var running := true
var total_spent := 0

func _process(delta: float) -> void:
	if not running:
		return
	var before := elixir
	elixir = minf(MAX_ELIXIR, elixir + delta * multiplier / REGEN_SECONDS)
	if elixir != before:
		changed.emit(elixir)

func can_afford(cost: int) -> bool:
	return elixir + 0.0001 >= float(cost)

func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	elixir -= cost
	total_spent += cost
	changed.emit(elixir)
	return true

func whole() -> int:
	return int(floor(elixir + 0.0001))
