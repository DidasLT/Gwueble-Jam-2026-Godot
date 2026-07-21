extends Node

signal infection_stage_changed(stage: int)
signal player_died



@export var time_to_death : float = 30.0
var infection_level : float = 0.0
var current_stage : int = 0
var stage_thresholds : Array[float] = [0.25, 0.5, 0.75, 1.0]
var is_dead : bool = false

func _process(delta: float) -> void:
	if is_dead:
		return

	infection_level += delta / time_to_death
	infection_level = clamp(infection_level, 0.0, 1.0)

	_check_stage()

	if infection_level >= 1.0:
		die()

func _check_stage() -> void:
	for i in range(stage_thresholds.size()):
		if infection_level >= stage_thresholds[i] and current_stage <= i:
			current_stage = i + 1
			infection_stage_changed.emit(current_stage)

func die() -> void:
	is_dead = true
	player_died.emit()

func reduce_infection(amount: float) -> void:
	infection_level = clamp(infection_level - amount, 0.0, 1.0)
	# recalculate current_stage in case we dropped back down a threshold
	_recalculate_stage()

func _recalculate_stage() -> void:
	var new_stage = 0
	for i in range(stage_thresholds.size()):
		if infection_level >= stage_thresholds[i]:
			new_stage = i + 1
	if new_stage != current_stage:
		current_stage = new_stage
		infection_stage_changed.emit(current_stage)
