class_name FiberBush
extends Node3D

@export var fiber_amount: int = 1
@export var interaction_distance: float = 4.5

@onready var fiber_label: Label = $PromptLayer/FiberLabel

var _player: Node3D
var _inventory: InventoryUI


func _enter_tree() -> void:
	add_to_group("fiber_pickups")
	add_to_group("interactable")

func _ready() -> void:
	fiber_label.visible = false
	_player = get_tree().current_scene.get_node_or_null("Player") as Node3D
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	fiber_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fiber_label.offset_top = 26.0
	fiber_label.offset_bottom = 86.0
	fiber_label.add_theme_font_size_override("font_size", 19)
	fiber_label.add_theme_color_override("font_color", Color(0.76, 1.0, 0.63, 1.0))
	fiber_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	fiber_label.add_theme_constant_override("shadow_offset_x", 2)
	fiber_label.add_theme_constant_override("shadow_offset_y", 2)


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
	if not is_instance_valid(_player):
		fiber_label.visible = false
		return
	var in_range: bool = global_position.distance_to(_player.global_position) <= interaction_distance and InteractionArbiter.is_selected(self)
	fiber_label.visible = in_range
	if in_range and Input.is_action_just_pressed("pickup") and is_instance_valid(_inventory) and not _inventory.is_open():
		var added_amount: int = _inventory.add_fiber(fiber_amount)
		if added_amount == fiber_amount:
			queue_free()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return true


func is_interaction_available() -> bool:
	return is_instance_valid(_inventory)
