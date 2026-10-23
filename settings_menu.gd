class_name SettingsMenu
extends CanvasLayer

## Top-left dropdown settings menu. Lets the player start a new game, load the
## save, or delete the save without restarting the project by hand.
##
## Opens by clicking the button (when the cursor is visible) or by pressing the
## "settings" action. It only calls existing SaveManager methods; it never
## manipulates world state itself.

const NEW_GAME_ID: int = 0
const LOAD_ID: int = 1
const DELETE_ID: int = 2

var _button: MenuButton
var _popup: PopupMenu
var _dialog: ConfirmationDialog
var _pending: Callable
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_button = MenuButton.new()
	_button.name = "SettingsButton"
	_button.text = "Settings"
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.anchor_left = 0.0
	_button.anchor_top = 0.0
	_button.anchor_right = 0.0
	_button.anchor_bottom = 0.0
	_button.offset_left = 16.0
	_button.offset_top = 12.0
	_button.offset_right = 130.0
	_button.offset_bottom = 48.0
	_button.add_theme_font_size_override("font_size", 17)
	_button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.62, 1.0))
	_button.add_theme_stylebox_override("normal", _box_style(Color(0.07, 0.08, 0.1, 0.85), Color(0.62, 0.48, 0.31, 1.0)))
	_button.add_theme_stylebox_override("hover", _box_style(Color(0.12, 0.13, 0.16, 0.92), Color(0.78, 0.66, 0.42, 1.0)))
	_button.add_theme_stylebox_override("pressed", _box_style(Color(0.16, 0.17, 0.2, 0.95), Color(0.78, 0.66, 0.42, 1.0)))
	add_child(_button)
	_popup = _button.get_popup()
	_popup.add_item("New Game", NEW_GAME_ID)
	_popup.add_item("Load Save", LOAD_ID)
	_popup.add_item("Delete Save", DELETE_ID)
	_popup.id_pressed.connect(_on_id_pressed)
	_popup.about_to_popup.connect(_on_about_to_popup)
	_popup.popup_hide.connect(_on_popup_hide)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.anchor_left = 0.0
	_toast.anchor_top = 0.0
	_toast.anchor_right = 0.0
	_toast.anchor_bottom = 0.0
	_toast.offset_left = 16.0
	_toast.offset_top = 54.0
	_toast.offset_right = 300.0
	_toast.offset_bottom = 82.0
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62, 1.0))
	_toast.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_toast.add_theme_constant_override("shadow_offset_x", 1)
	_toast.add_theme_constant_override("shadow_offset_y", 1)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)


func _show_toast(message_text: String) -> void:
	if message_text.is_empty():
		return
	_toast.text = message_text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _box_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("settings"):
		_toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _popup.visible:
		_popup.hide()
		get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	if _popup.visible:
		_popup.hide()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rect: Rect2 = _button.get_global_rect()
	_popup.position = Vector2i(int(rect.position.x), int(rect.position.y + rect.size.y + 4.0))
	_popup.popup()


func _on_about_to_popup() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_popup_hide() -> void:
	if not _any_blocking_ui_visible():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _any_blocking_ui_visible() -> bool:
	for node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		if node is Control and (node as Control).is_visible_in_tree():
			return true
	return false


func _on_id_pressed(id: int) -> void:
	match id:
		NEW_GAME_ID:
			_confirm("Start a new game?\nThis replaces your current progress.", _do_new_game)
		LOAD_ID:
			await SaveManager.load_game()
			_show_toast(SaveManager.get_status())
		DELETE_ID:
			_confirm("Delete your saved game?\nThis cannot be undone.", _do_delete)


func _do_new_game() -> void:
	SaveManager.start_new_game()


func _do_delete() -> void:
	SaveManager.delete_save()
	_show_toast(SaveManager.get_status())


func _confirm(message_text: String, action: Callable) -> void:
	_pending = action
	if not is_instance_valid(_dialog):
		_dialog = ConfirmationDialog.new()
		_dialog.title = "Settings"
		_dialog.confirmed.connect(_on_confirmed)
		add_child(_dialog)
	_dialog.dialog_text = message_text
	_dialog.get_ok_button().text = "Confirm"
	_dialog.get_cancel_button().text = "Cancel"
	_dialog.popup_centered()
	_dialog.get_ok_button().grab_focus()


func _on_confirmed() -> void:
	if _pending.is_valid():
		_pending.call()
	_pending = Callable()