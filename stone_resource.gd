class_name StoneResource
extends Node3D

@export var stone_amount: int = 1
@export var interaction_distance: float = 4.0

@onready var prompt_label: Label = $PromptLayer/StoneLabel

var _player: Node3D
var _inventory: InventoryUI


func _enter_tree() -> void:
	add_to_group("stone_pickups")
	add_to_group("interactable")

func _ready() -> void:
	prompt_label.visible = false
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	prompt_label.offset_top = 26.0
	prompt_label.offset_bottom = 76.0
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as Node3D
		_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_player):
		prompt_label.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= interaction_distance and InteractionArbiter.is_selected(self)
	prompt_label.visible = in_range
	if not in_range:
		return
	prompt_label.text = "Stone (+%d)\nPress E to pick up" % stone_amount
	if Input.is_action_just_pressed("pickup") and is_instance_valid(_inventory) and not _inventory.is_open():
		if _inventory.add_stone(stone_amount) == stone_amount:
			queue_free()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return true


func is_interaction_available() -> bool:
	return is_instance_valid(_inventory)
