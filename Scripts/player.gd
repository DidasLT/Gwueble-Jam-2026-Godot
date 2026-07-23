extends CharacterBody3D
var input_direction : Vector2
var speed : float

#player movement
@export var look_sensitivity : float = 0.005
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.0
@export var sneak_speed: float = 2.0
@export var acceleration: float = 60.0
@export var air_control: float = 5.0
@export var air_ressistance: float = 2.0

var death_angular_velocity : float = 0.0
@export var fall_gravity : float = 4.0 
@export var max_fall_angle : float = 90.0


#bobbing
@export var bob_amplitude : float = 0.08
@export var bob_speed : float
@export var walk_bob_amplitude : float = 0.08
@export var sneak_bob_amplitude : float = 0.05
@export var sprint_bob_amplitude : float = 0.1
@export var walk_bob_speed : float = 8.0
@export var sneak_bob_speed : float = 3.0
@export var sprint_bob_speed : float = 10.0

@export var hand_bob_amplitude : float
@export var hand_bob_speed : float
@export var hand_sway_amount : float = 0.01

@export var sprint_hand_bob_amplitude : float = 0.03
@export var sprint_hand_bob_speed : float = 6.0
@export var sneak_hand_bob_amplitude : float = 0.01
@export var sneak_hand_bob_speed : float = 2.0
@export var walk_hand_bob_amplitude : float = 0.02
@export var walk_hand_bob_speed : float = 4.0

@export var inventory_size : int = 2
@export var syringe_use_range : float = 2.0

var has_filled_syringe : bool = false
var dna_sample : String = ""

const DNA_BASES = ["A", "T", "C", "G"]

var inventory : Array = [null, null]
var current_slot : int = 0 

var hand_bob_time : float = 0.0
var hand_default_pos : Vector3
var left_hand_default_pos : Vector3
var hidden_position: Vector3

var bob_time : float = 0.0
var camera_start_y : float

var equipped_item : Item = null
var item_active : bool = false
var is_dying : bool = false


var death_start_head_y : float = 0.0
var death_target_head_y : float = 0.0

#animation
@export var sprite_frames : SpriteFrames
@export var death_head_drop : float = 0.1
@export var min_head_height : float = 0.0

enum MoveState { WALK, SNEAK, SPRINT }
var current_move_state : MoveState = MoveState.WALK

@onready var item_light = $Head/OmniLight3D
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var hand_sprite = $Head/Camera3D/Sprite3D
@onready var death_overlay = $DeathScreen/ColorRect
@onready var death_screen = $DeathScreen
@onready var death_sound = $DeathSound
@onready var item_pickup = $ItemPickup
@onready var prompt_label = $PromptUI/PromptLabel
@onready var use_sfx = $UseSFX
@onready var effects_material = $EffectsLayer/EffectsRect.material
@onready var effectLayer = $EffectsLayer
@onready var slot_icons = [$InventoryUI/Slot1Icon, $InventoryUI/Slot2Icon]
@onready var flicker_timer = $LighterFlickerTimer
@onready var timer_label = $Head/Camera3D/LeftHand/Label3D
@onready var left_hand: = $Head/Camera3D/LeftHand
@onready var dna_puzzle_ui = $DNAPuzzleUI


var death_screen_shown : bool = false

@export var interact_range : float = 3.0
var current_interactable = null

var held_item : String = ""

func pickup_item(item: Item) -> void:
	var empty_slot = inventory.find(null)
	if empty_slot != -1:
		inventory[empty_slot] = item
		current_slot = empty_slot
	else:
		inventory[current_slot] = item
	
	_equip_current_slot(true)   # true = play pickup animation
	_update_inventory_ui()
	
	equipped_item = item
	item_active = false
	hand_sprite.visible = true
	hand_sprite.play(item.pickup_animation)
	item_pickup.play()

func _on_hand_animation_finished() -> void: 
	if equipped_item and hand_sprite.animation == equipped_item.pickup_animation:
		hand_sprite.play(equipped_item.idle_animation)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_start_y = camera.position.y
	InfectionManager.infection_stage_changed.connect(_on_stage_changed)
	InfectionManager.player_died.connect(_on_died)
	hand_default_pos = hand_sprite.position
	left_hand_default_pos = left_hand.position
	hand_sprite.visible = false
	flicker_timer.timeout.connect(_on_flicker_check)
	hand_sprite.animation_finished.connect(_on_hand_animation_finished)
	print("Signal connected: ", hand_sprite.animation_finished.get_connections())
	left_hand_default_pos = left_hand.position
	hidden_position = left_hand_default_pos + Vector3(0, -5, 0)
	left_hand.position = hidden_position

func _process(_delta: float) -> void:
	effects_material.set_shader_parameter("infection_level", InfectionManager.infection_level)
	_update_timer_ui()

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
	if is_dying:
		_process_death(delta)
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_action_just_pressed("item_use") and equipped_item and equipped_item.is_consumable:
		_use_consumable()
	
	if Input.is_action_pressed("tab"):
		left_hand.visible = true
	else:
		left_hand.visible = false
	
	if Input.is_action_just_pressed("item_use") and equipped_item and equipped_item.is_syringe and not has_filled_syringe:
		_try_collect_sample()
	
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact(self)
	
	if Input.is_action_pressed("sneak") and is_on_floor():
		speed = sneak_speed
		bob_speed = sneak_bob_speed
		bob_amplitude = sneak_bob_amplitude
		hand_bob_amplitude = sneak_hand_bob_amplitude
		hand_bob_speed = sneak_hand_bob_speed
		current_move_state = MoveState.SNEAK
	elif Input.is_action_pressed("sprint") and is_on_floor():
		speed = sprint_speed
		bob_speed = sprint_bob_speed
		bob_amplitude = sprint_bob_amplitude
		hand_bob_amplitude = sprint_hand_bob_amplitude
		hand_bob_speed = sprint_hand_bob_speed
		current_move_state = MoveState.SPRINT
	else:
		speed = walk_speed
		bob_speed = walk_bob_speed
		bob_amplitude = walk_bob_amplitude
		hand_bob_amplitude = walk_hand_bob_amplitude
		hand_bob_speed = walk_hand_bob_speed
		current_move_state = MoveState.WALK

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
	_update_hand_bob(delta)
	
	if Input.is_action_just_pressed("item_use") and equipped_item and equipped_item.is_toggleable:
		item_active = not item_active
		if item_active:
			hand_sprite.play(equipped_item.on_animation)
			if equipped_item.use_sound:
				use_sfx.stream = equipped_item.use_sound
				use_sfx.play()
		else:
			hand_sprite.play(equipped_item.idle_animation)
		item_light.visible = item_active
	
	
	if Input.is_action_just_pressed("slot_1"):
		current_slot = 0
		_equip_current_slot()
		_update_inventory_ui()
		item_light.visible = false
	if Input.is_action_just_pressed("slot_2"):
		current_slot = 1
		_equip_current_slot()
		_update_inventory_ui()
		item_light.visible = false
	
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact(self)
	
	# head bob
	if is_on_floor() and horizontal_velocity.length() > 0.2:
		bob_time += delta * bob_speed
		camera.position.y = camera_start_y + sin(bob_time) * bob_amplitude
	else:
		camera.position.y = lerp(camera.position.y, camera_start_y, delta * 5.0)

func _use_consumable() -> void:
	var item = inventory[current_slot]
	if item == null or not item.is_consumable:
		return

	if item.use_sound:
		use_sfx.stream = item.use_sound
		use_sfx.play()

	InfectionManager.reduce_infection(item.infection_relief)

	inventory[current_slot] = null
	_equip_current_slot()
	_update_inventory_ui()

func _on_consumable_finished(_item: Item) -> void:
	hand_sprite.visible = false

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

func _on_flicker_check() -> void:
	if item_active and equipped_item and equipped_item.is_toggleable:
		if randf() < 0.01:  # 1% chance
			item_active = false
			hand_sprite.play(equipped_item.idle_animation)
			item_light.visible = false

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

func _update_hand_bob(delta: float) -> void:
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var is_moving = horizontal_speed > 0.2 and is_on_floor()

	if is_moving:
		hand_bob_time += delta * hand_bob_speed
		var bob_offset = Vector3.ZERO
		bob_offset.y = sin(hand_bob_time * 2.0) * hand_bob_amplitude
		bob_offset.x = cos(hand_bob_time) * hand_sway_amount
		hand_sprite.position = hand_default_pos.lerp(hand_default_pos + bob_offset, 1.0)
		left_hand.position = left_hand_default_pos.lerp(left_hand_default_pos + bob_offset, 1.0)
	else:
		hand_bob_time += delta * 1.5
		var idle_offset = Vector3(0, sin(hand_bob_time) * 0.005, 0)
		hand_sprite.position = hand_sprite.position.lerp(hand_default_pos + idle_offset, delta * 5.0)
		left_hand.position = left_hand.position.lerp(left_hand_default_pos + idle_offset, delta * 5.0)

func _equip_current_slot(just_picked_up: bool = false) -> void:
	var item = inventory[current_slot]
	if item == null:
		hand_sprite.visible = false
		equipped_item = null
		return

	equipped_item = item
	item_active = false
	hand_sprite.visible = true

	if just_picked_up:
		hand_sprite.play(item.pickup_animation)
	else:
		hand_sprite.play(item.idle_animation)

func _update_inventory_ui() -> void:
	for i in range(inventory.size()):
		var item = inventory[i]
		slot_icons[i].texture = item.icon if item else null
		slot_icons[i].modulate = Color.WHITE if i == current_slot else Color(0.5, 0.5, 0.5)

func _update_timer_ui() -> void:
	var time_remaining = InfectionManager.time_to_death * (1.0 - InfectionManager.infection_level)
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	timer_label.modulate = Color.WHITE.lerp(Color.RED, InfectionManager.infection_level)

func _on_died() -> void:
	is_dying = true
	death_angular_velocity = 0.0
	death_sound.play()
	effectLayer.visible = false
	hand_sprite.visible = false

func _show_death_screen() -> void:
	if death_screen_shown:
		return
	death_screen_shown = true
	death_screen.visible = true
	var tween = create_tween()
	tween.tween_property(death_overlay, "modulate:a", 1.0, 2.0)

func _process_death(delta: float) -> void:
	death_angular_velocity += fall_gravity * delta
	camera.rotation.z += death_angular_velocity * delta
	
	var max_rad = deg_to_rad(max_fall_angle)
	if camera.rotation.z >= max_rad:
		camera.rotation.z = max_rad
		_show_death_screen()
		
	head.position.y = lerp(head.position.y, death_target_head_y, delta * 2.0)

func _check_for_interactable() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * interact_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.is_in_group("interactable"):
		current_interactable = result.collider
	
		if "item_data" in current_interactable and current_interactable.item_data:
			prompt_label.text = current_interactable.item_data.item_name + "\nPress E to pick up"
		elif "prompt_text" in current_interactable:
			prompt_label.text = current_interactable.prompt_text
		else:
			prompt_label.text = "Press E to interact"

		prompt_label.visible = true
	else:
		current_interactable = null
		prompt_label.visible = false
func _try_collect_sample() -> void:
	var monster = get_tree().get_first_node_in_group("monster")
	if not monster:
		return

	var distance = global_position.distance_to(monster.global_position)
	if distance <= syringe_use_range:
		dna_sample = _generate_dna_sample()
		has_filled_syringe = true
		print("Collected sample: ", dna_sample)
		if has_filled_syringe:
			hand_sprite.play(equipped_item.on_animation)

func _on_mixer_opened(sample: String) -> void:
	dna_puzzle_ui.open_puzzle(sample)

func _generate_dna_sample(length: int = 8) -> String:
	var sample = ""
	for i in range(length):
		sample += DNA_BASES[randi() % DNA_BASES.size()]
	return sample
