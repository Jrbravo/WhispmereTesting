class_name ChestInteraction
extends Node3D

const INTERACTION_DISTANCE: float = 3.5

var _player: PlayerController
var _prompt_layer: CanvasLayer
var _prompt: Label
var _menu: ChestInventoryMenu


func _ready() -> void:
	add_to_group("interactable")
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "ChestPromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "ChestPrompt"
	_prompt.text = "Chest\nPress E to open"
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_top = 26.0
	_prompt.offset_bottom = 84.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 19)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57, 1.0))
	_prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	_prompt_layer.add_child(_prompt)
	_resolve_player()


func _process(_delta: float) -> void:
	if SaveManager.is_restoring(): return
	if not is_instance_valid(_player):
		_resolve_player()
	if not is_instance_valid(_player):
		_prompt.visible = false
		return
	var chest_pos: Vector3 = global_position
	var player_pos: Vector3 = _player.global_position
	player_pos.y = chest_pos.y
	var in_range: bool = chest_pos.distance_to(player_pos) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range and not (is_instance_valid(_menu) and _menu.is_open())
	if in_range and Input.is_action_just_pressed("pickup") and not _is_other_menu_open():
		_open_menu()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	return true


func _resolve_player() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_player = scene.get_node_or_null("Player") as PlayerController


func _is_other_menu_open() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var inventory: InventoryUI = scene.get_node_or_null("InventoryUI") as InventoryUI
	var crafting: CraftingMenu = scene.get_node_or_null("CraftingMenu") as CraftingMenu
	if (is_instance_valid(inventory) and inventory.is_open()) or (is_instance_valid(crafting) and crafting.is_open()):
		return true
	for ui_node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		if ui_node is Control and (ui_node as Control).is_visible_in_tree():
			return true
	return false


func _open_menu() -> void:
	if not is_instance_valid(_menu):
		_menu = ChestInventoryMenu.get_or_create(get_tree().current_scene)
	_menu.open()
