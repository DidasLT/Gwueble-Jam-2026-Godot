# DNAPuzzleUI.gd
extends CanvasLayer

@onready var sample_label = $Panel/SampleLabel
@onready var answer_label = $Panel/AnswerLabel
@onready var result_label = $Panel/ResultLabel

var target_sample : String = ""
var player_answer : String = ""
var pair_map = {"A": "T", "T": "A", "C": "G", "G": "C"}

func _ready() -> void:
	visible = false
	$Panel/ButtonA.pressed.connect(_on_base_pressed.bind("A"))
	$Panel/ButtonT.pressed.connect(_on_base_pressed.bind("T"))
	$Panel/ButtonC.pressed.connect(_on_base_pressed.bind("C"))
	$Panel/ButtonG.pressed.connect(_on_base_pressed.bind("G"))
	$Panel/SubmitButton.pressed.connect(_on_submit)
	$Panel/CloseButton.pressed.connect(close_puzzle)

func open_puzzle(sample: String) -> void:
	target_sample = sample
	player_answer = ""
	sample_label.text = "Sample: " + target_sample
	answer_label.text = "Your answer: "
	result_label.text = ""
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # so UI still works while paused

func _on_base_pressed(base: String) -> void:
	if player_answer.length() >= target_sample.length():
		return
	player_answer += base
	answer_label.text = "Your answer: " + player_answer

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("esc"):
		close_puzzle()

func _on_submit() -> void:
	var correct_answer = ""
	for c in target_sample:
		correct_answer += pair_map[c]

	if player_answer == correct_answer:
		result_label.text = "Match confirmed. Antidote synthesized."
		result_label.modulate = Color.GREEN
		_grant_antidote()
	else:
		result_label.text = "Sequence mismatch. Try again."
		result_label.modulate = Color.RED
		player_answer = ""
		answer_label.text = "Your answer: "

func _grant_antidote() -> void:
	var player = get_tree().get_first_node_in_group("player")
	# give player an antidote item — reuse your inventory/pickup pattern
	# e.g. player.pickup_item(antidote_item_resource) or a dedicated flag
	await get_tree().create_timer(1.5).timeout
	visible = false
	get_tree().paused = false

func close_puzzle() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_clear_pressed() -> void:
	player_answer = ""
	answer_label.text = "Your answer: "
