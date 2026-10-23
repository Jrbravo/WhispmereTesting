class_name StoneVein
extends Node3D

@export var stone_yield: int = 5
@export var interaction_distance: float = 4.5

@onready var stone_label: Label = $PromptLayer/StoneLabel

var _player: Node3D
var _inventory: InventoryUI
var _veins: Array[Node3D] = []
var _harvested: Dictionary = {}
var _harvested_names: Array[String] = []

func get_harvested_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for rock: Node3D in _veins:
		if _harvested_names.has(String(rock.name)):
			result.append(rock)
	return result

func get_harvested_ids() -> Array[String]:
	return _harvested_names.duplicate()

func restore_harvested_ids(ids: Array) -> void:
	if _veins.is_empty():
		for child: Node in get_children():
			if child is Node3D and String(child.name).begins_with("StoneChunksLarge"):
				_veins.append(child as Node3D)
	for identifier: Variant in ids:
		if identifier is String and not _harvested_names.has(identifier):
			_harvested_names.append(identifier)
	for rock: Node3D in _veins:
		if _harvested_names.has(String(rock.name)):
			_harvested.erase(rock.get_instance_id())
			_harvested[rock.get_instance_id()] = true
			rock.queue_free()


func _enter_tree() -> void:
	add_to_group("stone_deposits")
	add_to_group("interactable")

func _ready() -> void:
	for child in get_children():
		if child is Node3D and String(child.name).begins_with("StoneChunksLarge"):
			_veins.append(child as Node3D)
	stone_label.visible = false
	stone_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stone_label.offset_top = 26.0
	stone_label.offset_bottom = 76.0
	stone_label.add_theme_font_size_override("font_size", 19)
	stone_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	stone_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	stone_label.add_theme_constant_override("shadow_offset_x", 2)
	stone_label.add_theme_constant_override("shadow_offset_y", 2)
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as Node3D
		_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI


func get_available_deposits() -> Array[Node3D]:
	var available: Array[Node3D] = []
	for candidate: Node in get_tree().get_nodes_in_group("stone_deposits"):
		var deposit_host: StoneVein = candidate as StoneVein
		if not is_instance_valid(deposit_host):
			continue
		for rock: Node3D in deposit_host._veins:
			if is_instance_valid(rock) and not deposit_host._harvested.has(rock.get_instance_id()):
				available.append(rock)
	return available


## Nearest un-harvested rock in this deposit that the player can reach.
func _nearest_rock() -> Node3D:
	if not is_instance_valid(_player):
		return null
	var target_vein: Node3D = null
	var closest_distance: float = interaction_distance
	for vein: Node3D in _veins:
		if not is_instance_valid(vein) or _harvested.has(vein.get_instance_id()):
			continue
		var vein_ground_position: Vector3 = Vector3(vein.global_position.x, _player.global_position.y, vein.global_position.z)
		var distance: float = vein_ground_position.distance_to(_player.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			target_vein = vein
	return target_vein


func interaction_point() -> Vector3:
	var rock: Node3D = _nearest_rock()
	return rock.global_position if is_instance_valid(rock) else global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return is_instance_valid(_inventory) and _inventory.is_pickaxe_equipped()


func is_interaction_available() -> bool:
	return _nearest_rock() != null


func mark_deposit_harvested(deposit: Node3D) -> void:
	if not is_instance_valid(deposit):
		return
	for candidate: Node in get_tree().get_nodes_in_group("stone_deposits"):
		var deposit_host: StoneVein = candidate as StoneVein
		if is_instance_valid(deposit_host) and deposit_host._veins.has(deposit):
			deposit_host._harvested[deposit.get_instance_id()] = true
			deposit_host._harvested_names.append(String(deposit.name))
			deposit.queue_free()
			return


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_player):
		stone_label.visible = false
		return
	var target_vein: Node3D = _nearest_rock()
	var selected: bool = target_vein != null and InteractionArbiter.is_selected(self)
	stone_label.visible = selected
	if not selected:
		return
	var has_pickaxe: bool = is_instance_valid(_inventory) and _inventory.is_pickaxe_equipped()
	stone_label.text = "Stone deposit (+%d Stone)\nPress E to mine" % stone_yield if has_pickaxe else "Stone deposit\nEquip a pickaxe to mine"
	if has_pickaxe and not SaveManager.is_restoring() and Input.is_action_just_pressed("pickup") and not _inventory.is_open():
		var added_amount: int = _inventory.add_stone(stone_yield)
		if added_amount == stone_yield:
			_harvested[target_vein.get_instance_id()] = true
			_harvested_names.append(String(target_vein.name))
			target_vein.queue_free()
