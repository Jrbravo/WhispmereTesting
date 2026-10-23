class_name TreeResource
extends Node3D

@export var wood_yield: int = 5
@export var interaction_distance: float = 4.5

var _player: Node3D
var _inventory: InventoryUI
var _prompt_layer: CanvasLayer
var _prompt_label: Label
var _trees: Array[Node3D] = []
var _harvested: Dictionary = {}
var _harvested_names: Array[String] = []

func get_harvested_ids() -> Array[String]:
	return _harvested_names.duplicate()

func restore_harvested_ids(ids: Array) -> void:
	if _trees.is_empty():
		for child: Node in get_children():
			if child is Node3D and String(child.name).begins_with("EA03_Nature_Tree"):
				_trees.append(child as Node3D)
	for identifier: Variant in ids:
		if identifier is String and not _harvested_names.has(identifier):
			_harvested_names.append(identifier)
	for tree: Node3D in _trees:
		if _harvested_names.has(String(tree.name)):
			_harvested[tree.get_instance_id()] = true
			tree.queue_free()


func _enter_tree() -> void:
	add_to_group("persistent_world_objects")
	add_to_group("tree_resources")
	add_to_group("interactable")

func _ready() -> void:
	for child in get_children():
		if child is Node3D and String(child.name).begins_with("EA03_Nature_Tree"):
			_trees.append(child as Node3D)
	_player = get_tree().current_scene.get_node_or_null("Player") as Node3D
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "TreePromptLayer"
	add_child(_prompt_layer)
	_prompt_label = Label.new()
	_prompt_label.name = "TreePrompt"
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt_label.offset_top = 26.0
	_prompt_label.offset_bottom = 76.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 19)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_layer.add_child(_prompt_label)
	_prompt_label.visible = false


func get_available_trees() -> Array[Node3D]:
	var available: Array[Node3D] = []
	for tree: Node3D in _trees:
		if is_instance_valid(tree) and not _harvested.has(tree.get_instance_id()):
			available.append(tree)
	return available


func mark_tree_harvested(tree: Node3D) -> void:
	if not is_instance_valid(tree) or not _trees.has(tree):
		return
	_harvested[tree.get_instance_id()] = true
	_harvested_names.append(String(tree.name))
	tree.queue_free()


## Nearest un-harvested tree that the player is close enough to interact with.
func _nearest_tree() -> Node3D:
	if not is_instance_valid(_player):
		return null
	var target_tree: Node3D = null
	var closest_distance: float = interaction_distance
	for tree: Node3D in _trees:
		if not is_instance_valid(tree) or _harvested.has(tree.get_instance_id()):
			continue
		var distance: float = tree.global_position.distance_to(_player.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			target_tree = tree
	return target_tree


func interaction_point() -> Vector3:
	var tree: Node3D = _nearest_tree()
	return tree.global_position if is_instance_valid(tree) else global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return is_instance_valid(_inventory) and _inventory.is_axe_equipped()


func is_interaction_available() -> bool:
	return _nearest_tree() != null


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_player):
		_prompt_label.visible = false
		return
	var target_tree: Node3D = _nearest_tree()
	_prompt_label.visible = target_tree != null and InteractionArbiter.is_selected(self)
	if target_tree == null or not InteractionArbiter.is_selected(self):
		return
	var has_axe: bool = is_instance_valid(_inventory) and _inventory.is_axe_equipped()
	_prompt_label.text = "Tree (+%d Wood)\nPress E to chop" % wood_yield if has_axe else "Tree\nEquip an axe to chop"
	if has_axe and Input.is_action_just_pressed("pickup") and not _inventory.is_open():
		var added_amount: int = _inventory.add_wood(wood_yield)
		if added_amount == wood_yield:
			_harvested[target_tree.get_instance_id()] = true
			_harvested_names.append(String(target_tree.name))
			target_tree.queue_free()
