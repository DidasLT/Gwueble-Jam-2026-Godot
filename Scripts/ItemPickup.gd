extends StaticBody3D

@export var item_data : Item

func interact(player: Node3D) -> void:
	player.pickup_item(item_data)
	queue_free()
