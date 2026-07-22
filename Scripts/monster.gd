extends CharacterBody3D

enum State { PATROL, INVESTIGATE, CHASE, FLEE }
var state : State = State.PATROL

@export var wander_radius : float = 8.0
@export var wander_pause_min : float = 1.0
@export var wander_pause_max : float = 4.0
var wander_target : Vector3
var wander_timer : float = 0.0
var home_position : Vector3

@onready var nav_agent = $NavigationAgent3D

@export var patrol_points : Array[Node3D] = []
var current_patrol_index : int = 0
@export var patrol_speed : float = 2.0

@export var bite_range : float = 1.5
@export var bite_time_penalty : float = 60.0   # seconds removed from InfectionManager's timer
@export var flee_duration : float = 5.0        # how long it runs away after biting
var can_bite : bool = true
var flee_timer : float = 0.0

@export var vision_fov_degrees : float = 40.0
@export var vision_range : float = 30.0
@export var hearing_range_walk : float = 6.0
@export var hearing_range_run : float = 14.0
@export var hearing_range_sprint : float = 24.0
@export var gravity_amount : float = 9.8

@export var speed_vs_walk : float = 1.5
@export var speed_vs_run : float = 1.2
@export var speed_vs_sprint : float = 0.5

var player : CharacterBody3D = null
var last_known_position : Vector3

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	home_position = global_position
	call_deferred("_start_patrol")
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("After frame delay, picking wander target")
	_pick_new_wander_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_amount * delta
	else:
		velocity.y = 0

	match state:
		State.PATROL:
			if _can_see_player() or _can_hear_player():
				state = State.CHASE
				last_known_position = player.global_position
				_patrol_movement(delta)
		State.CHASE:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var current_speed = _get_current_speed()

			var direction = (next_path_position - global_position)
			direction.y = 0
			direction = direction.normalized()

			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			move_and_slide()

			# check for bite
			var distance_to_player = global_position.distance_to(player.global_position)
			if distance_to_player <= bite_range and can_bite:
				_bite_player()
			
		State.FLEE:
			_flee_movement(delta)
		State.INVESTIGATE:
			# move toward last_known_position, then give up back to PATROL after a timer
			pass

func _can_see_player() -> bool:
	if not player:
		print("No player reference!")
		return false

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	print("Distance to player: ", distance, " / vision_range: ", vision_range)

	if distance > vision_range:
		return false

	var forward = -global_transform.basis.z
	var angle_to_player = rad_to_deg(forward.angle_to(to_player.normalized()))

	print("Angle to player: ", angle_to_player, " / max allowed: ", vision_fov_degrees / 2.0)

	if angle_to_player > vision_fov_degrees / 2.0:
		return false

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, player.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	print("Raycast result: ", result)

	return result.is_empty() or result.collider == player

func _can_hear_player() -> bool:
	if not player:
		return false

	var distance = global_position.distance_to(player.global_position)
	var required_range = hearing_range_walk

	match player.current_move_state:
		player.MoveState.WALK:
			required_range = hearing_range_walk
		player.MoveState.SNEAK:
			required_range = hearing_range_run
		player.MoveState.SPRINT:
			required_range = hearing_range_sprint

	return distance <= required_range

func _get_current_speed() -> float:

	if not player:
		return 3.0

	match player.current_move_state:
		player.MoveState.SNEAK:
			return player.sneak_speed * speed_vs_walk
		player.MoveState.WALK:
			return player.walk_speed * speed_vs_run  # tune base multiplier to your actual run speed var
		player.MoveState.SPRINT:
			return player.sprint_speed * speed_vs_sprint

	return player.walk_speed

func _start_patrol() -> void:
	await get_tree().physics_frame
	_pick_new_wander_target()

func _patrol_movement(delta: float) -> void:
	nav_agent.target_position = wander_target
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position)
	direction.y = 0

	if direction.length() < 0.3:
		wander_timer -= delta
		if wander_timer <= 0:
			_pick_new_wander_target()
		return

	direction = direction.normalized()
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	move_and_slide()

func _bite_player() -> void:
	
	can_bite = false
	InfectionManager.apply_time_penalty(bite_time_penalty)

	# play a bite sound/animation here if you have one

	state = State.FLEE
	flee_timer = flee_duration

func _flee_movement(delta: float) -> void:
	flee_timer -= delta

	var direction = (global_position - player.global_position)
	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * _get_current_speed()
	velocity.z = direction.z * _get_current_speed()
	move_and_slide()

	if flee_timer <= 0:
		state = State.PATROL
		can_bite = true   # reset so it can bite again next encounter

func _pick_new_wander_target() -> void:
	var angle = randf() * TAU
	var dist = randf_range(2.0, wander_radius)
	var offset = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	wander_target = home_position + offset
	wander_timer = randf_range(wander_pause_min, wander_pause_max)
