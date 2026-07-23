extends Resource
class_name Item

@export var item_name : String = ""
@export var idle_animation : String = ""
@export var pickup_animation : String = ""
@export var on_animation : String = ""
@export var is_toggleable : bool = false
@export var light_color : Color = Color(1, 0.6, 0.2)
@export var light_energy : float = 1.5
@export var light_range : float = 3.0
@export var use_sound : AudioStream
@export var icon : Texture2D
@export var is_syringe : bool = false

@export var is_consumable : bool = false     # true = used up on pickup, not held
@export var infection_relief : float = 0.15  # how much it reduces infection_level (0-1 range)
