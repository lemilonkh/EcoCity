extends Resource
class_name Structure

@export_subgroup("Model")
@export var model: PackedScene ## Model of the structure

@export_subgroup("Gameplay")
@export var price: int ## Price of the structure when building
@export var emissions: int = 0 ## How much emissions the building generates (+) or reduces (-)
@export var energy: int = 0 ## How much energy the building generates (+) or consumes (-)
@export var happiness: int = 0 ## How happy the building makes the citizens
@export var waste: int = 0 ## How much waste this building produces (+) or consumes (-)

@export_subgroup("Decoration")
@export var is_decoration: bool = false
@export var can_decorate: bool = false
@export var decoration_height: int = 0
