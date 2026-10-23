class_name PlacedCampfire
extends MeshInstance3D

const INTERACTION_DISTANCE: float = 3.5

var _player: PlayerController
var _menu: CampfireMenu
var _prompt_layer: CanvasLayer
var _prompt: Label


func _ready() -> void:
	add_to_group("placed_campfires")
	add_to_group("interactable")
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "CampfirePromptLayer"
	add_child(_prompt_layer)
	_prompt = Label.new()
	_prompt.name = "CampfirePrompt"
	_prompt.text = "Campfire\nPress E to use"
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
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as PlayerController
	_ensure_menu()


## The cooking state lives in CampfireMenu. Create it up front so cooking runs
## whether or not the player has opened the campfire, and Chef can feed it.
func _ensure_menu() -> void:
	if not is_instance_valid(_menu):
		_menu = CampfireMenu.new()
		# Keep this name: the inventory finds the campfire menu by it when dragging meat out.
		_menu.name = "CampfireMenu"
		get_tree().current_scene.add_child(_menu)
	_menu.set_campfire_position(global_position)


## Chef hands over raw meat. Returns true if the campfire accepted it.
func accept_raw_meat_from_npc() -> bool:
	_ensure_menu()
	return _menu.add_raw_meat_from_npc()


## Chef drops a recipe ingredient into the campfire's stock. Returns how many
## were accepted (0 when there is no room).
func accept_ingredient_from_npc(item_name: String) -> int:
	_ensure_menu()
	return _menu.stock_item(item_name, 1)


## Chef takes back any finished cooked meat. Returns how many were collected.
func collect_cooked_meat_for_npc() -> int:
	_ensure_menu()
	return _menu.take_cooked_meat_for_npc()


## Number of meat slots still cooking or holding meat (used by Chef to know when it is done).
func meat_still_cooking() -> bool:
	return is_instance_valid(_menu) and _menu.has_meat_in_progress()


func get_save_state() -> Dictionary:
	_ensure_menu()
	return _menu.get_save_state()

func set_save_state(state: Dictionary) -> void:
	_ensure_menu()
	_menu.set_save_state(state)

func _process(_delta: float) -> void:
	if SaveManager.is_restoring(): return
	if not is_instance_valid(_player):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as PlayerController
	if not is_instance_valid(_player):
		_prompt.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= INTERACTION_DISTANCE and InteractionArbiter.is_selected(self)
	_prompt.visible = in_range and not (is_instance_valid(_menu) and _menu.is_open())
	if in_range and Input.is_action_just_pressed("pickup") and not _is_other_menu_open():
		_open_menu()


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return INTERACTION_DISTANCE


func is_interaction_actionable() -> bool:
	return true


func _is_other_menu_open() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	var inventory: InventoryUI = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	var crafting: CraftingMenu = current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
	return (is_instance_valid(inventory) and inventory.is_open()) or (is_instance_valid(crafting) and crafting.is_open())


func _open_menu() -> void:
	_ensure_menu()
	_menu.open()
