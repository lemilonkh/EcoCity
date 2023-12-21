extends Node3D

@export var structures: Array[Structure] = []

var map: DataMap

var index: int = 0 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var decoration_grid:GridMap
@export var cash_display:Label
@export var population_display:Label
@export var structure_container:HBoxContainer

@export var happiness_bar:ProgressBar
@export var energy_bar:ProgressBar
@export var emissions_bar:ProgressBar
@export var waste_bar:ProgressBar

var plane: Plane # Used for raycasting mouse
var gridmap_position: Vector3

var happiness = 50:
	set(value):
		happiness = clampi(value, 0, 100)
		happiness_bar.value = happiness
var energy = 0:
	set(value):
		energy = clampi(value, 0, 100)
		energy_bar.value = energy
var emissions = 0:
	set(value):
		emissions = clampi(value, 0, 100)
		emissions_bar.value = emissions
var waste = 0:
	set(value):
		waste = clampi(value, 0, 100)
		waste_bar.value = waste

func _ready():
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	var structure_button: TextureButton = structure_container.get_child(0)
	structure_container.remove_child(structure_button)
	
	var mesh_library := gridmap.mesh_library
	print("Items ", mesh_library.get_item_list())
	for item in mesh_library.get_item_list():
		var icon := mesh_library.get_item_preview(item)
		var button := structure_button.duplicate()
		button.texture_normal = icon
		button.pressed.connect(_on_structure_button_pressed.bind(item))
		structure_container.add_child(button)
	
	structure_button.queue_free()
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	#var mesh_library = MeshLibrary.new()
	
	#for structure in structures:
		#var id = mesh_library.get_last_unused_item_id()
		#mesh_library.create_item(id)
		#mesh_library.set_item_mesh(id, get_mesh(structure.model))
		#mesh_library.set_item_mesh_transform(id, Transform3D())
	
	#gridmap.mesh_library = mesh_library
	#decoration_grid.mesh_library = mesh_library
	
	update_structure()
	update_cash()
	update_population()

func _on_structure_button_pressed(item: int) -> void:
	index = item
	update_structure()
	print("Item", index)
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, delta * 40)

# Controls
func _unhandled_input(event: InputEvent) -> void:
	# prevent double activation for released events
	if !event.is_pressed():
		return

	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures

	action_save() # Saving
	action_load() # Loading

	action_build(gridmap_position)
	action_demolish(gridmap_position)

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary
func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					
					return prop_value.duplicate()

# Build (place) a structure
func action_build(gridmap_position):
	if Input.is_action_just_pressed("build"):
		var structure: Structure = structures[index]
		var previous_tile: int
		var orientation := gridmap.get_orthogonal_index_from_basis(selector.basis)
		var was_built := false
		if structure.is_decoration:
			var item := gridmap.get_cell_item(gridmap_position)
			if item != -1:
				var base_structure: Structure = structures[item]
				if base_structure.can_decorate:
					gridmap_position.y = base_structure.decoration_height
					previous_tile = decoration_grid.get_cell_item(gridmap_position)
					decoration_grid.set_cell_item(gridmap_position, index, orientation)
					was_built = true
				else:
					pass # TODO play error sound
			else:
				pass # TODO play error sound
		else:
			previous_tile = gridmap.get_cell_item(gridmap_position)
			gridmap.set_cell_item(gridmap_position, index, orientation)
			was_built = true
		
		if was_built:
			if previous_tile != index:
				map.cash -= structure.price
				map.population += structure.inhabitants
				happiness += structure.happiness
				energy += structure.energy
				emissions += structure.emissions
				waste += structure.waste
				update_cash()
				update_population()

# Demolish (remove) a structure
func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		var previous_tile: int
		# delete decoration first
		if decoration_grid.get_cell_item(gridmap_position) != -1:
			previous_tile = decoration_grid.get_cell_item(gridmap_position)
			decoration_grid.set_cell_item(gridmap_position, -1)
		else:
			previous_tile = gridmap.get_cell_item(gridmap_position)
			gridmap.set_cell_item(gridmap_position, -1)
		
		var previous_structure: Structure = structures[previous_tile]
		map.population -= previous_structure.inhabitants
		happiness -= previous_structure.happiness
		energy -= previous_structure.energy
		emissions -= previous_structure.emissions
		waste -= previous_structure.waste
		update_population()

# Rotates the 'cursor' 90 degrees
func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))

# Toggle between structures to build
func action_structure_toggle():
	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, structures.size())
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size())

	update_structure()

# Update the structure visual in the 'cursor'
func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	_model.position.y += 0.25
	
	# Focus model on hotbar
	if index < structure_container.get_child_count():
		structure_container.get_child(index).grab_focus()

func update_cash():
	cash_display.text = "$" + str(map.cash)

func update_population():
	population_display.text = str(map.population)

# Saving/load
func action_save():
	if Input.is_action_just_pressed("save"):
		print("Saving map...")
		map.structures.clear()
		
		for cell in gridmap.get_used_cells():
			var data_structure: DataStructure = DataStructure.new()
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = gridmap.get_cell_item_orientation(cell)
			data_structure.structure = gridmap.get_cell_item(cell)
			data_structure.is_decoration = false
			map.structures.append(data_structure)
		
		for cell in decoration_grid.get_used_cells():
			var data_structure: DataStructure = DataStructure.new()
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = decoration_grid.get_cell_item_orientation(cell)
			data_structure.structure = decoration_grid.get_cell_item(cell)
			data_structure.is_decoration = true
			map.structures.append(data_structure)
		
		map.happiness = happiness
		map.energy = energy
		map.emissions = emissions
		map.waste = waste
		
		ResourceSaver.save(map, "user://map.res")
	
func action_load():
	if Input.is_action_just_pressed("load"):
		print("Loading map...")
		
		gridmap.clear()
		decoration_grid.clear()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			var pos := Vector3i(cell.position.x, 0, cell.position.y)
			if cell.is_decoration:
				decoration_grid.set_cell_item(pos, cell.structure, cell.orientation)
			else:
				gridmap.set_cell_item(pos, cell.structure, cell.orientation)
		
		happiness = map.happiness
		energy = map.energy
		emissions = map.emissions
		waste = map.waste
		
		update_cash()
		update_population()
