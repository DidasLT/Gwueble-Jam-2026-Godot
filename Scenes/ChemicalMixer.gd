extends StaticBody3D

@export var prompt_text : String = "Press E to analyze sample"

func interact(player: Node3D) -> void:
	if not player.has_filled_syringe:
		# nothing to analyze yet — could show a quick message instead of opening the puzzle
		print("No sample to analyze")
		return

	var dna_puzzle_ui = get_tree().get_first_node_in_group("dna_puzzle_ui")
	if dna_puzzle_ui:
		dna_puzzle_ui.open_puzzle(player.dna_sample)
