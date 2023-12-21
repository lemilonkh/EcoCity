extends Resource
class_name Structure

@export_subgroup("Model")
@export var model:PackedScene # Model of the structure

@export_subgroup("Gameplay")
@export var price: int # Price of the structure when building
@export var is_decoration: bool = false
@export var can_decorate: bool = false
@export var decoration_height: int = 0
