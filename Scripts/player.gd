extends CharacterBody3D
var input_direction : Vector2
var speed : float

#player movement
@export var look_sensitivity : float = 0.005
@export var walk_speed: float = 5.0
@export var sneak_speed: float = 2.0
@export var acceleration: float = 60.0
@export var air_control: float = 5.0
@export var air_ressistance: float = 2.0

#bobbing
@export var bob_amplitude : float = 0.08
@export var bob_speed : float
@export var walk_bob_amplitude : float = 0.08
@export var sneak_bob_amplitude : float = 0.05
@export var walk_bob_speed : float = 8.0
@export var sneak_bob_speed : float = 3.0

var bob_time : float = 0.0
var camera_start_y : float

var equipped_item : Item = null
var item_active : bool = false

#animation
@export var sprite_frames : SpriteFrames
@export var anim_off : String = "idle"
@export var anim_on : String = "lit"

@onready var item_light = $Head/Camera3D/Sprite3D/OmniLight3D
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hand_sprite = $Head/Camera3D/Sprite3D

func pickup_item(item: Item) -> void:
	equipped_item = item
	item_active = false
	hand_sprite.texture = item.texture_off
	hand_sprite.visible = true
	item_light.visible = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_start_y = camera.position.y
	InfectionManager.infection_stage_changed.connect(_on_stage_changed)
	InfectionManager.player_died.connect(_on_died)

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
	
	_check_for_interactable()
	
	if Input.is_action_just_pressed("item_use") and equipped_item and equipped_item.is_toggleable:
		item_active = not item_active
		_apply_item_state()
	
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact(self)

	# head bob
	if is_on_floor() and horizontal_velocity.length() > 0.2:
		bob_time += delta * bob_speed
		camera.position.y = camera_start_y + sin(bob_time) * bob_amplitude
	else:
		camera.position.y = lerp(camera.position.y, camera_start_y, delta * 5.0)
		

@export var interact_range : float = 3.0
var current_interactable = null

var held_item : String = ""


func _apply_item_state() -> void:
	hand_sprite.texture = equipped_item.texture_on if item_active else equipped_item.texture_off

	if equipped_item.has_light:
		item_light.visible = item_active
		item_light.light_color = equipped_item.light_color
		item_light.light_energy = equipped_item.light_energy
		item_light.omni_range = equipped_item.light_range
	else:
		item_light.visible = false

	if equipped_item.use_sound:
		pass

func _on_stage_changed(stage: int) -> void:
	match stage:
		1:
			pass # subtle changes
		2:
			pass # more noticeable
		3:
			walk_speed *= 0.8
			sneak_speed *= 0.8
			walk_bob_amplitude *= 1.5
			sneak_bob_amplitude *= 1.5
		4:
			pass # near-death effects

func _on_died() -> void:
	get_tree().paused = true
	# show death/game over screen here


func _check_for_interactable() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * interact_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	if result and result.collider.is_in_group("interactable"):
		current_interactable = result.collider
	else:
		current_interactable = null
