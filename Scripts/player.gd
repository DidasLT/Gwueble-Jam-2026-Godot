extends CharacterBody3D
var input_direction : Vector2
var speed : float

#player movement
@export var look_sensitivity : float = 0.005
@export var walk_speed = 5.0
@export var sneak_speed = 2.0
@export var acceleration = 60.0
@export var air_control = 5.0
@export var air_ressistance = 2.0

@export var bob_amplitude : float = 0.08
@export var bob_speed : float

@export var walk_bob_amplitude : float = 0.08
@export var sneak_bob_amplitude : float = 0.05

@export var walk_bob_speed : float = 8.0
@export var sneak_bob_speed : float = 3.0

var bob_time : float = 0.0
var camera_start_y : float



@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_start_y = camera.position.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_pressed("sneak") and is_on_floor():
		speed = sneak_speed
		bob_speed = sneak_bob_speed
		bob_amplitude = sneak_bob_amplitude
	else:
		speed = walk_speed
		bob_speed = walk_bob_speed
		bob_amplitude = walk_bob_amplitude

	input_direction = Input.get_vector("left", "right", "forward", "Back")
	var direction = (head.transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()

	var target_velocity = direction * speed
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)

	if is_on_floor():
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	else:
		if direction:
			horizontal_velocity = horizontal_velocity.move_toward(target_velocity, air_control * delta)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, air_ressistance * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	move_and_slide()

	# head bob
	if is_on_floor() and horizontal_velocity.length() > 0.2:
		bob_time += delta * bob_speed
		camera.position.y = camera_start_y + sin(bob_time) * bob_amplitude
	else:
		camera.position.y = lerp(camera.position.y, camera_start_y, delta * 5.0)
