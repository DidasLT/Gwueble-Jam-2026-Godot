extends StaticBody3D

@export var item_data : Item

func interact(player: Node3D) -> void:
	print("INTERACT CALLED, frame: ", Engine.get_process_frames())   # <- ADD THIS LINE
	player.pickup_item(item_data)
	queue_free()
