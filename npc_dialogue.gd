class_name NPCDialogue
extends CanvasLayer

var _panel: PanelContainer
var _dialogue_root: CenterContainer
var _message: Label
var _heading: Label
var _give_button: Button
var _yes_button: Button
var _not_now_button: Button
var _friend_message: Label
var _friend_overlay: ColorRect
var _friend_tween: Tween
var _inventory: InventoryUI
var _open: bool = false
var _thank_you: bool = false
var _friend_made: bool = false
var _wood_help_prompt: bool = false
var _stoney_thank_you: bool = false
var _stoney_friend_made: bool = false
var _woodsman: IdleNPC
var _is_stoney: bool = false
var _is_farmer: bool = false
var _farmer_friend_made: bool = false
var _farmer_thank_you: bool = false


func _ready() -> void:
	add_to_group("npc_dialogue")
	layer = 6
	_build_panel()
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_woodsman = current_scene.get_node_or_null("Props/NPC") as IdleNPC
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_panel() -> void:
	_dialogue_root = CenterContainer.new()
	_dialogue_root.name = "DialogueRoot"
	_dialogue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_root.add_to_group("blocking_ui")
	_dialogue_root.visible = false
	add_child(_dialogue_root)
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.custom_minimum_size = Vector2(560.0, 250.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.border_color = Color(0.62, 0.48, 0.31, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24.0
	style.content_margin_top = 18.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", style)
	_dialogue_root.add_child(_panel)
	_friend_overlay = ColorRect.new()
	_friend_overlay.name = "FriendOverlay"
	_friend_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_overlay.color = Color(0.025, 0.055, 0.07, 0.93)
	_friend_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friend_overlay.visible = false
	add_child(_friend_overlay)
	var friend_center: CenterContainer = CenterContainer.new()
	friend_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_overlay.add_child(friend_center)
	_friend_message = Label.new()
	_friend_message.text = "You made a friend!"
	_friend_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friend_message.add_theme_font_size_override("font_size", 56)
	_friend_message.add_theme_color_override("font_color", Color(1.0, 0.83, 0.39, 1.0))
	_friend_message.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_friend_message.add_theme_constant_override("shadow_offset_x", 3)
	_friend_message.add_theme_constant_override("shadow_offset_y", 4)
	friend_center.add_child(_friend_message)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)
	_heading = Label.new()
	_heading.text = "Woodsman"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 23)
	content.add_child(_heading)
	_message = Label.new()
	_message.text = "Can you make me 1 cooked meat?"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 25)
	content.add_child(_message)
	_give_button = Button.new()
	_give_button.text = "Give 1 cooked meat"
	_give_button.custom_minimum_size = Vector2(0.0, 44.0)
	_give_button.pressed.connect(_on_give_pressed)
	content.add_child(_give_button)
	_yes_button = Button.new()
	_yes_button.text = "Yes"
	_yes_button.custom_minimum_size = Vector2(0.0, 44.0)
	_yes_button.pressed.connect(_on_wood_help_yes_pressed)
	content.add_child(_yes_button)
	_not_now_button = Button.new()
	_not_now_button.text = "Not right now"
	_not_now_button.custom_minimum_size = Vector2(0.0, 44.0)
	_not_now_button.pressed.connect(_on_wood_help_not_now_pressed)
	content.add_child(_not_now_button)
	var exit_button: Button = Button.new()
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(0.0, 40.0)
	exit_button.pressed.connect(close)
	content.add_child(exit_button)
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_panel.visible = false
	_yes_button.visible = false
	_not_now_button.visible = false


func configure_for_stoney(is_stoney: bool, is_farmer: bool = false) -> void:
	_is_stoney = is_stoney
	if is_farmer:
		_is_farmer = true
	if is_inside_tree():
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
			_woodsman = current_scene.get_node_or_null("Props/NPC") as IdleNPC
	if is_inside_tree():
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_woodsman = current_scene.get_node_or_null("Props/NPC") as IdleNPC
	if is_instance_valid(_heading):
		_heading.text = "Stoney" if _is_stoney else ("Farmer" if _is_farmer else "Woodsman")
	if is_instance_valid(_message):
		_message.text = "Can you give me 1 stone?" if _is_stoney else ("Can you build a plot?" if _is_farmer else "Can you make me 1 cooked meat?")
	if is_instance_valid(_give_button):
		_give_button.text = "Give 1 Stone" if _is_stoney else ("Build Plot" if _is_farmer else "Give 1 cooked meat")
		_give_button.visible = true
	if is_instance_valid(_yes_button):
		_yes_button.visible = false
		_not_now_button.visible = false


func _process(_delta: float) -> void:
	_update_give_button()

func is_configured_for_stoney() -> bool:
	return _is_stoney

func has_completed_friendship() -> bool:
	return _stoney_friend_made if _is_stoney else (_friend_made if _is_farmer else _friend_made)

func merge_save_state(state: Dictionary) -> void:
	if _is_stoney:
		_stoney_thank_you = _stoney_thank_you or bool(state.get("stoney_thanked", false))
		_stoney_friend_made = _stoney_friend_made or bool(state.get("stoney_friend", false))
		if _stoney_friend_made:
			_stoney_thank_you = false
	else:
		_thank_you = _thank_you or bool(state.get("woodsman_thanked", false))
		_friend_made = _friend_made or bool(state.get("woodsman_friend", false))
		if _friend_made:
			_thank_you = false

func reset_dialogue_view() -> void:
	_wood_help_prompt = false
	_open = false
	if is_instance_valid(_dialogue_root):
		_dialogue_root.visible = false
	if is_instance_valid(_friend_overlay):
		_friend_overlay.visible = false

func has_pending_thank_you() -> bool:
	return _stoney_thank_you if _is_stoney else _thank_you


func _update_give_button() -> void:
	if not is_instance_valid(_give_button):
		return
	if _is_stoney:
		_give_button.disabled = _stoney_thank_you or not is_instance_valid(_inventory) or _inventory.get_total_stone() < 1
	else:
		_give_button.disabled = _thank_you or not is_instance_valid(_inventory) or _inventory.get_total_cooked_meat() < 1


func _on_give_pressed() -> void:
	if not is_instance_valid(_inventory):
		return
	if _is_stoney:
		if _stoney_thank_you or _stoney_friend_made:
			return
		if _inventory.remove_stone(1):
			_stoney_thank_you = true
			_message.text = "Thank you!"
			_give_button.visible = false
		return
	if _thank_you or _friend_made:
		return
	if _inventory.remove_cooked_meat(1):
		_thank_you = true
		_message.text = "Thank you!"
		_give_button.visible = false


func _current_npc() -> IdleNPC:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Props/StoneMinerNPC" if _is_stoney else "Props/NPC") as IdleNPC


func open() -> void:
	_open = true
	_panel.visible = true
	_dialogue_root.visible = true
	var npc: IdleNPC = _current_npc()
	if _is_stoney and _stoney_friend_made:
		if is_instance_valid(npc) and npc.is_working():
			_show_working_message()
		else:
			_show_stone_help_prompt()
	elif _is_stoney:
		_wood_help_prompt = false
		_message.text = "Can you give me 1 stone?"
		_give_button.text = "Give 1 Stone"
		_give_button.visible = true
		_yes_button.visible = false
		_not_now_button.visible = false
		_update_give_button()
	elif _friend_made:
		if is_instance_valid(npc) and npc.is_working():
			_show_working_message()
		else:
			_show_wood_help_prompt()
	else:
		_wood_help_prompt = false
		_message.text = "Can you make me 1 cooked meat?"
		_give_button.visible = true
		_yes_button.visible = false
		_not_now_button.visible = false
		_update_give_button()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_stone_help_prompt() -> void:
	_wood_help_prompt = true
	_message.text = "Do you need help with collecting stone?"
	_give_button.visible = false
	_yes_button.visible = true
	_not_now_button.visible = true


func _show_working_message() -> void:
	_wood_help_prompt = false
	_message.text = "I'm already out gathering stone for you." if _is_stoney else "I'm already out gathering wood for you."
	_give_button.visible = false
	_yes_button.visible = false
	_not_now_button.visible = false


func _show_wood_help_prompt() -> void:
	_wood_help_prompt = true
	_message.text = "Do you want help collecting wood?"
	_give_button.visible = false
	_yes_button.visible = true
	_not_now_button.visible = true


func _on_wood_help_yes_pressed() -> void:
	if _is_stoney:
		if not _stoney_friend_made:
			return
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			var stoney: IdleNPC = current_scene.get_node_or_null("Props/StoneMinerNPC") as IdleNPC
			if is_instance_valid(stoney):
				stoney.start_stone_collection()
		_wood_help_prompt = false
		close()
		return
	if _is_farmer:
		## Farmer plot flow: check if plot exists, say thank you, trigger friend popup
		var current_scene: Node = get_tree().current_scene
		var plot_exists: bool = false
		if current_scene != null:
			var plots: Array = current_scene.get_tree().get_nodes_in_group("farm_plots")
			plot_exists = not plots.is_empty()
		if plot_exists:
			_farmer_thank_you = true
			_message.text = "Thank you!"
			_give_button.visible = false
		close()
		return
	if not _wood_help_prompt:
		return
	_wood_help_prompt = false
	if is_instance_valid(_woodsman):
		_woodsman.start_wood_collection()
	close()


func _on_wood_help_not_now_pressed() -> void:
	if _is_stoney:
		_wood_help_prompt = false
		close()
		return
	if _wood_help_prompt:
		_wood_help_prompt = false
		close()


func close() -> void:
	var became_friend: bool = false
	_open = false
	_dialogue_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _is_stoney and _stoney_thank_you and not _stoney_friend_made:
		_stoney_friend_made = true
		_stoney_thank_you = false
		became_friend = true
	elif _is_farmer and _friend_made and not _farmer_friend_made:
		_farmer_friend_made = true
		became_friend = true
	elif not _is_stoney and not _is_farmer and _thank_you and not _friend_made:
		_friend_made = true
		_thank_you = false
		became_friend = true
	if became_friend:
		_wood_help_prompt = false
		_show_friend_message()
	elif _wood_help_prompt:
		_wood_help_prompt = false


func _show_friend_message() -> void:
	if is_instance_valid(_friend_tween):
		_friend_tween.kill()
	_friend_overlay.visible = true
	_friend_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_friend_message.scale = Vector2(0.82, 0.82)
	_friend_tween = create_tween()
	_friend_tween.set_trans(Tween.TRANS_BACK)
	_friend_tween.set_ease(Tween.EASE_OUT)
	_friend_tween.tween_property(_friend_overlay, "modulate:a", 1.0, 0.35)
	_friend_tween.parallel().tween_property(_friend_message, "scale", Vector2.ONE, 0.45)
	_friend_tween.tween_interval(2.2)
	_friend_tween.tween_property(_friend_overlay, "modulate:a", 0.0, 0.8)
	_friend_tween.tween_callback(_hide_friend_message)


func _hide_friend_message() -> void:
	_friend_overlay.visible = false


func get_save_state() -> Dictionary:
	return {"woodsman_thanked": _thank_you or _friend_made, "woodsman_friend": _friend_made, "stoney_thanked": _stoney_thank_you or _stoney_friend_made, "stoney_friend": _stoney_friend_made, "farmer_friend": _farmer_friend_made or _farmer_thank_you}

func get_own_save_state() -> Dictionary:
	if _is_stoney:
		return {"thanked": _stoney_thank_you or _stoney_friend_made, "friend": _stoney_friend_made}
	return {"thanked": _thank_you or _friend_made, "friend": _friend_made}

func set_save_state(state: Dictionary) -> void:
	if _is_stoney:
		_stoney_thank_you = bool(state["stoney_thanked"]) and not bool(state["stoney_friend"])
		_stoney_friend_made = bool(state["stoney_friend"])
	else:
		_thank_you = bool(state["woodsman_thanked"]) and not bool(state["woodsman_friend"])
		_friend_made = bool(state["woodsman_friend"])
	reset_dialogue_view()

func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
