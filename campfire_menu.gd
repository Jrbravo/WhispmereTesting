class_name CampfireMenu
extends CanvasLayer

var _root: CenterContainer
var _panel: PanelContainer
var _open: bool = false
var _inventory: InventoryUI
const RAW_SLOT: int = 0
const COOKED_SLOT: int = 1
const RAW_CAPACITY: int = 99
const COOKED_CAPACITY: int = 99
var _raw_count: int = 0
var _cooked_count: int = 0
var _raw_cook_remaining: float = 0.0
var _world_timer: Label3D
var _campfire_world_position: Vector3 = Vector3.ZERO
var _slot_labels: Array[Label] = []
var _slot_icons: Array[TextureRect] = []
const RAW_MEAT_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/raw-meat.png")
const COOKED_MEAT_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/cooked-meat.png")
const COOK_TIME_SECONDS: float = 15.0

## Campfire recipes. The recipe "name" is also the inventory item it produces.
## Ingredient names must match the inventory item names exactly. Ingredients are
## consumed the moment cooking starts, and only one recipe cooks at a time.
const RECIPE_COOK_TIME_SECONDS: float = 30.0
const RECIPES: Array[Dictionary] = [
	{"id": "herb_roasted_beef", "name": "Herb-Roasted Beef", "ingredients": {"Beef": 1, "Wild Herbs": 1}},
	{"id": "berry_glazed_beef", "name": "Berry-Glazed Beef", "ingredients": {"Beef": 1, "Wild Berries": 1}},
	{"id": "mushroom_roasted_chicken", "name": "Mushroom-Roasted Chicken", "ingredients": {"Raw Meat": 1, "Wild Mushrooms": 1}},
	{"id": "herb_mushroom_chicken", "name": "Herb & Mushroom Chicken", "ingredients": {"Raw Meat": 1, "Wild Mushrooms": 1, "Wild Herbs": 1}},
]
const RECIPE_ICONS: Dictionary = {
	"Herb-Roasted Beef": preload("res://assets/generated/recipe_herb_roasted_beef.png"),
	"Berry-Glazed Beef": preload("res://assets/generated/recipe_berry_glazed_beef.png"),
	"Mushroom-Roasted Chicken": preload("res://assets/generated/recipe_mushroom_roasted_chicken.png"),
	"Herb & Mushroom Chicken": preload("res://assets/generated/recipe_herb_mushroom_chicken.png"),
}

## Campfire stock: a few general slots the Chef can fill with recipe ingredients.
## The player can also drop ingredients in, take them back out, or just cook
## straight from them. One item type per slot, capped like every other stack.
const STOCK_SLOT_COUNT: int = 3
const STOCK_CAPACITY: int = 99
## Icons for the items that can sit in stock (recipe ingredients).
const ITEM_ICONS: Dictionary = {
	"Beef": InventoryUI.BEEF_ICON,
	"Raw Meat": InventoryUI.RAW_MEAT_ICON,
	"Wild Berries": InventoryUI.BERRIES_ICON,
	"Wild Mushrooms": InventoryUI.MUSHROOM_ICON,
	"Wild Herbs": InventoryUI.HERB_ICON,
}

var _active_recipe_id: String = ""
var _active_recipe_name: String = ""
var _recipe_remaining: float = 0.0
var _ready_dishes: Dictionary = {}
var _recipe_rows: Array[Dictionary] = []
var _cooking_status: Label
var _ready_label: Label
var _collect_button: Button
var _stock: Dictionary = {}
var _stock_panels: Array[Panel] = []
var _stock_icons: Array[TextureRect] = []
var _stock_labels: Array[Label] = []


func _ready() -> void:
	layer = 5
	add_to_group("campfire_menu")
	_build_world_timer()
	_root = CenterContainer.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This full-screen layout container must not block the lower-layer inventory.
	# Its child Panel and slots still receive mouse input.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	_root.add_to_group("blocking_ui")
	add_child(_root)
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_panel = PanelContainer.new()
	_panel.name = "Window"
	_panel.custom_minimum_size = Vector2(430.0, 300.0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.95)
	panel_style.border_color = Color(0.65, 0.57, 0.39, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 16.0
	panel_style.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Campfire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	content.add_child(_build_meat_slots())
	content.add_child(_build_stock_section())
	content.add_child(HSeparator.new())
	content.add_child(_build_recipe_section())
	content.add_child(HSeparator.new())
	content.add_child(_build_ready_section())
	var footer: Label = Label.new()
	footer.text = "Press E or Esc to close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color(0.77, 0.77, 0.77, 1.0))
	content.add_child(footer)
	_refresh_campfire_slots()
	_refresh_stock()
	_refresh_recipe_rows()
	_refresh_ready()


## The two original meat slots, kept for the Chef loop and meat drag-and-drop.
func _build_meat_slots() -> HBoxContainer:
	var slots: HBoxContainer = HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	for slot_index in range(2):
		var slot: Panel = Panel.new()
		slot.name = "Slot%d" % (slot_index + 1)
		slot.custom_minimum_size = Vector2(92.0, 72.0)
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.17, 0.18, 0.21, 1.0)
		slot_style.border_color = Color(0.4, 0.42, 0.45, 1.0)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", slot_style)
		slots.add_child(slot)
		var slot_icon: TextureRect = TextureRect.new()
		slot_icon.name = "ItemIcon"
		slot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_icon.offset_left = 8.0
		slot_icon.offset_top = 6.0
		slot_icon.offset_right = -8.0
		slot_icon.offset_bottom = -20.0
		slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_icon)
		_slot_icons.append(slot_icon)
		var slot_label: Label = Label.new()
		slot_label.name = "Count"
		slot_label.text = "Empty"
		slot_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_label)
		_slot_labels.append(slot_label)
		slot.set_drag_forwarding(Callable(self, "_campfire_drag_data").bind(slot_index), Callable(self, "_campfire_can_drop").bind(slot_index), Callable(self, "_campfire_drop").bind(slot_index))
	return slots


## Stock slots the Chef fills with ingredients. Clicking one takes the whole
## stack back into the player's inventory.
func _build_stock_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header: Label = Label.new()
	header.text = "Stock (Chef fills these)"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, 1.0))
	section.add_child(header)
	var slots: HBoxContainer = HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 12)
	section.add_child(slots)
	for slot_index: int in range(STOCK_SLOT_COUNT):
		var slot: Panel = Panel.new()
		slot.name = "StockSlot%d" % (slot_index + 1)
		slot.custom_minimum_size = Vector2(92.0, 64.0)
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.17, 0.18, 0.21, 1.0)
		slot_style.border_color = Color(0.55, 0.5, 0.32, 1.0)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", slot_style)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.tooltip_text = "Click to take this ingredient"
		slot.gui_input.connect(_on_stock_slot_gui_input.bind(slot_index))
		slots.add_child(slot)
		_stock_panels.append(slot)
		var slot_icon: TextureRect = TextureRect.new()
		slot_icon.name = "ItemIcon"
		slot_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_icon.offset_left = 8.0
		slot_icon.offset_top = 4.0
		slot_icon.offset_right = -8.0
		slot_icon.offset_bottom = -18.0
		slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_icon)
		_stock_icons.append(slot_icon)
		var slot_label: Label = Label.new()
		slot_label.name = "Count"
		slot_label.text = "Empty"
		slot_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot_label.add_theme_font_size_override("font_size", 13)
		slot_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_label)
		_stock_labels.append(slot_label)
	return section


func _build_recipe_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header: Label = Label.new()
	header.text = "Recipes (30s each)"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, 1.0))
	section.add_child(header)
	for recipe: Dictionary in RECIPES:
		section.add_child(_build_recipe_row(recipe))
	_cooking_status = Label.new()
	_cooking_status.name = "CookingStatus"
	_cooking_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooking_status.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 1.0))
	section.add_child(_cooking_status)
	return section


func _build_recipe_row(recipe: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.texture = RECIPE_ICONS.get(String(recipe["name"]), null)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var info: Label = Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 15)
	row.add_child(info)
	var cook_button: Button = Button.new()
	cook_button.text = "Cook"
	cook_button.custom_minimum_size = Vector2(76.0, 30.0)
	cook_button.pressed.connect(_on_cook_pressed.bind(recipe))
	row.add_child(cook_button)
	_recipe_rows.append({"recipe": recipe, "info": info, "button": cook_button})
	return row


func _build_ready_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var header: Label = Label.new()
	header.text = "Ready to collect"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, 1.0))
	section.add_child(header)
	_ready_label = Label.new()
	_ready_label.name = "ReadyList"
	_ready_label.add_theme_font_size_override("font_size", 15)
	_ready_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_ready_label)
	_collect_button = Button.new()
	_collect_button.name = "CollectButton"
	_collect_button.text = "Collect"
	_collect_button.custom_minimum_size = Vector2(120.0, 30.0)
	_collect_button.pressed.connect(_on_collect_pressed)
	section.add_child(_collect_button)
	return section


func _build_world_timer() -> void:
	_world_timer = Label3D.new()
	_world_timer.name = "CookingCountdown"
	_world_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_world_timer.font_size = 64
	_world_timer.outline_size = 12
	_world_timer.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	_world_timer.modulate = Color(1.0, 0.84, 0.42, 1.0)
	_world_timer.pixel_size = 0.003
	_world_timer.no_depth_test = true
	_world_timer.position = Vector3(0.0, 2.6, 0.0)
	_world_timer.visible = false
	get_tree().current_scene.add_child(_world_timer)


func _process(delta: float) -> void:
	if SaveManager.is_restoring(): return
	if _recipe_remaining > 0.0:
		_recipe_remaining = maxf(0.0, _recipe_remaining - delta)
		if _recipe_remaining <= 0.0:
			_finish_recipe()
	if _raw_count > 0 and _raw_cook_remaining > 0.0:
		_raw_cook_remaining = maxf(0.0, _raw_cook_remaining - delta)
		if _raw_cook_remaining <= 0.0:
			# The whole raw stack finishes at once and moves to the cooked stack.
			_cooked_count = mini(_cooked_count + _raw_count, COOKED_CAPACITY)
			_raw_count = 0
			_raw_cook_remaining = 0.0
	if _recipe_remaining > 0.0:
		_show_world_timer("%d" % ceili(_recipe_remaining))
	elif _raw_count > 0 and _raw_cook_remaining > 0.0:
		_show_world_timer("%d" % ceili(_raw_cook_remaining))
	else:
		_world_timer.visible = false
	_refresh_campfire_slots()
	_refresh_stock()
	_refresh_recipe_rows()
	_refresh_ready()


func get_save_state() -> Dictionary:
	return {
		"raw": _raw_count,
		"cooked": _cooked_count,
		"remaining": _raw_cook_remaining,
		"recipe": _active_recipe_id,
		"recipe_remaining": _recipe_remaining,
		"ready": _ready_dishes.duplicate(),
		"stock": _stock.duplicate(),
	}

func set_save_state(state: Dictionary) -> void:
	_raw_count = int(state["raw"])
	_cooked_count = int(state["cooked"])
	_raw_cook_remaining = clampf(float(state["remaining"]), 0.0, COOK_TIME_SECONDS)
	_active_recipe_id = ""
	_active_recipe_name = ""
	var saved_recipe: Dictionary = _recipe_by_id(String(state.get("recipe", "")))
	if not saved_recipe.is_empty():
		_active_recipe_id = String(saved_recipe["id"])
		_active_recipe_name = String(saved_recipe["name"])
	_recipe_remaining = clampf(float(state.get("recipe_remaining", 0.0)), 0.0, RECIPE_COOK_TIME_SECONDS)
	if _active_recipe_id.is_empty():
		_recipe_remaining = 0.0
	_ready_dishes = {}
	var saved_ready: Variant = state.get("ready", {})
	if saved_ready is Dictionary:
		for item_value: Variant in (saved_ready as Dictionary).keys():
			var item_name: String = String(item_value)
			var count: int = int((saved_ready as Dictionary)[item_value])
			if count > 0:
				_ready_dishes[item_name] = count
	_stock = {}
	var saved_stock: Variant = state.get("stock", {})
	if saved_stock is Dictionary:
		for item_value: Variant in (saved_stock as Dictionary).keys():
			var item_name: String = String(item_value)
			var count: int = int((saved_stock as Dictionary)[item_value])
			if count > 0 and is_cookable_ingredient(item_name) and _stock.size() < STOCK_SLOT_COUNT:
				_stock[item_name] = mini(count, STOCK_CAPACITY)
	_refresh_campfire_slots()
	_refresh_stock()
	_refresh_recipe_rows()
	_refresh_ready()

func get_campfire_position() -> Vector3:
	return _campfire_world_position

func set_campfire_position(world_position: Vector3) -> void:
	_campfire_world_position = world_position
	if is_instance_valid(_world_timer):
		_world_timer.global_position = world_position + Vector3(0.0, 2.6, 0.0)


func open() -> void:
	if not is_node_ready():
		await ready
	_open = true
	_root.visible = true
	if is_instance_valid(_inventory):
		_inventory.set_open_beside_campfire(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_open = false
	_root.visible = false
	if is_instance_valid(_inventory):
		_inventory.set_open_beside_campfire(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("pickup") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## True when this item can be stored in stock (it is used by some recipe).
func is_cookable_ingredient(item_name: String) -> bool:
	for recipe: Dictionary in RECIPES:
		if (recipe["ingredients"] as Dictionary).has(item_name):
			return true
	return false


## Current stock contents as item name -> count.
func get_stock() -> Dictionary:
	return _stock.duplicate()


## Puts up to `amount` of an ingredient into stock. Returns the amount accepted.
## Refuses a new item type once every stock slot is taken.
func stock_item(item_name: String, amount: int) -> int:
	if amount <= 0 or not is_cookable_ingredient(item_name):
		return 0
	var current: int = int(_stock.get(item_name, 0))
	if current == 0 and _stock.size() >= STOCK_SLOT_COUNT:
		return 0
	var accepted: int = mini(amount, STOCK_CAPACITY - current)
	if accepted <= 0:
		return 0
	_stock[item_name] = current + accepted
	_refresh_stock()
	return accepted


## Removes up to `amount` of an ingredient from stock. Returns the amount removed.
func take_stock(item_name: String, amount: int) -> int:
	var current: int = int(_stock.get(item_name, 0))
	var removed: int = mini(maxi(amount, 0), current)
	if removed <= 0:
		return 0
	if current - removed <= 0:
		_stock.erase(item_name)
	else:
		_stock[item_name] = current - removed
	_refresh_stock()
	return removed


## Ingredients available to this campfire: its own stock plus the player's bag.
func available_count(item_name: String) -> int:
	if not is_instance_valid(_inventory):
		_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	var total: int = int(_stock.get(item_name, 0))
	if is_instance_valid(_inventory):
		total += _inventory.get_total_for_item(item_name)
	return total


## True when stock and inventory together cover the recipe's ingredients.
func can_cook_recipe(recipe_id: String) -> bool:
	var recipe: Dictionary = _recipe_by_id(recipe_id)
	if recipe.is_empty():
		return false
	var ingredients: Dictionary = recipe["ingredients"]
	for item_value: Variant in ingredients.keys():
		if available_count(String(item_value)) < int(ingredients[item_value]):
			return false
	return true


## Spends a recipe's ingredients, taking from stock first and then the player's
## inventory. Nothing is spent unless the whole recipe is covered.
func _consume_for_recipe(recipe: Dictionary) -> bool:
	if not can_cook_recipe(String(recipe["id"])):
		return false
	var ingredients: Dictionary = recipe["ingredients"]
	for item_value: Variant in ingredients.keys():
		var item_name: String = String(item_value)
		var needed: int = int(ingredients[item_name])
		var from_stock: int = take_stock(item_name, needed)
		needed -= from_stock
		if needed > 0 and is_instance_valid(_inventory):
			_inventory.remove_item(item_name, needed)
	return true


func _on_stock_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var items: Array = _stock.keys()
	if slot_index < 0 or slot_index >= items.size():
		return
	if not is_instance_valid(_inventory):
		_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_inventory):
		return
	var item_name: String = String(items[slot_index])
	var added: int = _inventory.add_item(item_name, int(_stock[item_name]))
	take_stock(item_name, added)
	get_viewport().set_input_as_handled()


func _refresh_stock() -> void:
	if _stock_panels.is_empty():
		return
	var items: Array = _stock.keys()
	for slot_index: int in range(_stock_panels.size()):
		if slot_index < items.size():
			var item_name: String = String(items[slot_index])
			_stock_icons[slot_index].texture = ITEM_ICONS.get(item_name, null)
			_stock_labels[slot_index].text = "%s x%d" % [_short_name(item_name), int(_stock[item_name])]
			_stock_labels[slot_index].add_theme_color_override("font_color", Color(1.0, 0.9, 0.78, 1.0))
		else:
			_stock_icons[slot_index].texture = null
			_stock_labels[slot_index].text = "Empty"
			_stock_labels[slot_index].add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))


func _short_name(item_name: String) -> String:
	match item_name:
		"Wild Berries": return "Berries"
		"Wild Mushrooms": return "Mushrooms"
		"Wild Herbs": return "Herbs"
	return item_name


## Starts a recipe if nothing else is cooking and the ingredients are available.
## Ingredients are consumed immediately. Returns true when cooking started.
func start_recipe(recipe_id: String) -> bool:
	if not _active_recipe_id.is_empty():
		return false
	var recipe: Dictionary = _recipe_by_id(recipe_id)
	if recipe.is_empty():
		return false
	if not _consume_for_recipe(recipe):
		return false
	_active_recipe_id = String(recipe["id"])
	_active_recipe_name = String(recipe["name"])
	_recipe_remaining = RECIPE_COOK_TIME_SECONDS
	_refresh_recipe_rows()
	return true


func is_cooking_recipe() -> bool:
	return not _active_recipe_id.is_empty()


func get_ready_dishes() -> Dictionary:
	return _ready_dishes.duplicate()


## Moves as many ready dishes into the inventory as fit. Returns the number moved.
func collect_ready_dishes() -> int:
	if not is_instance_valid(_inventory):
		_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_inventory):
		return 0
	var moved: int = 0
	for item_value: Variant in _ready_dishes.keys():
		var item_name: String = String(item_value)
		var remaining: int = int(_ready_dishes[item_name])
		if remaining <= 0:
			continue
		var added: int = _inventory.add_cooked_dish(item_name, remaining)
		moved += added
		remaining -= added
		if remaining <= 0:
			_ready_dishes.erase(item_name)
		else:
			_ready_dishes[item_name] = remaining
	_refresh_ready()
	return moved


func _recipe_by_id(recipe_id: String) -> Dictionary:
	for recipe: Dictionary in RECIPES:
		if String(recipe["id"]) == recipe_id:
			return recipe
	return {}


func _finish_recipe() -> void:
	if _active_recipe_name.is_empty():
		return
	_ready_dishes[_active_recipe_name] = int(_ready_dishes.get(_active_recipe_name, 0)) + 1
	_active_recipe_id = ""
	_active_recipe_name = ""
	_recipe_remaining = 0.0
	_refresh_recipe_rows()
	_refresh_ready()


func _on_cook_pressed(recipe: Dictionary) -> void:
	start_recipe(String(recipe["id"]))


func _on_collect_pressed() -> void:
	collect_ready_dishes()


func _refresh_recipe_rows() -> void:
	if _recipe_rows.is_empty():
		return
	if not is_instance_valid(_inventory):
		var scene: Node = get_tree().current_scene
		if scene != null:
			_inventory = scene.get_node_or_null("InventoryUI") as InventoryUI
	for row: Dictionary in _recipe_rows:
		var recipe: Dictionary = row["recipe"]
		var info: Label = row["info"]
		var cook_button: Button = row["button"]
		var ingredients: Dictionary = recipe["ingredients"]
		var description: String = _describe_ingredients(ingredients)
		var can_cook: bool = can_cook_recipe(String(recipe["id"]))
		if _active_recipe_id == String(recipe["id"]):
			info.text = "%s\nCooking... %ds" % [String(recipe["name"]), ceili(_recipe_remaining)]
		elif can_cook:
			info.text = "%s\n%s" % [String(recipe["name"]), description]
		else:
			info.text = "%s\n%s (missing)" % [String(recipe["name"]), description]
		info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0) if can_cook else Color(0.62, 0.55, 0.55, 1.0))
		cook_button.disabled = not can_cook or not _active_recipe_id.is_empty()
	if is_instance_valid(_cooking_status):
		if _active_recipe_id.is_empty():
			_cooking_status.text = ""
		else:
			_cooking_status.text = "Cooking %s: %ds left" % [_active_recipe_name, ceili(_recipe_remaining)]


func _refresh_ready() -> void:
	if not is_instance_valid(_ready_label) or not is_instance_valid(_collect_button):
		return
	if _ready_dishes.is_empty():
		_ready_label.text = "Nothing waiting."
		_collect_button.disabled = true
		return
	var parts: Array[String] = []
	for item_value: Variant in _ready_dishes.keys():
		parts.append("%s x%d" % [String(item_value), int(_ready_dishes[item_value])])
	_ready_label.text = ", ".join(parts)
	_collect_button.disabled = false


func _describe_ingredients(ingredients: Dictionary) -> String:
	var parts: Array[String] = []
	for item_value: Variant in ingredients.keys():
		parts.append("%d %s" % [int(ingredients[item_value]), String(item_value)])
	return " + ".join(parts)


func _show_world_timer(text: String) -> void:
	_world_timer.global_position = _campfire_world_position + Vector3(0.0, 2.6, 0.0)
	_world_timer.text = text
	_world_timer.visible = true


func _campfire_drag_data(_at_position: Vector2, slot_index: int) -> Variant:
	if not _open or _raw_count + _cooked_count == 0:
		return null
	if slot_index == RAW_SLOT and _raw_count > 0 and _raw_cook_remaining <= 0.0:
		return null
	if slot_index == COOKED_SLOT and _cooked_count > 0:
		return {"kind": "campfire_meat", "source_slot": slot_index, "meat_state": 2}
	if slot_index == RAW_SLOT and _raw_count > 0:
		return {"kind": "campfire_meat", "source_slot": slot_index, "meat_state": 1}
	return null


## Used by Chef: adds one raw meat to the raw stack. The whole raw stack cooks together.
func add_raw_meat_from_npc() -> bool:
	if _raw_count >= RAW_CAPACITY:
		return false
	if _raw_count == 0:
		_raw_cook_remaining = COOK_TIME_SECONDS
	_raw_count += 1
	_refresh_campfire_slots()
	return true


## Used by Chef: removes the cooked stack. Returns how many were taken.
func take_cooked_meat_for_npc() -> int:
	var taken: int = _cooked_count
	_cooked_count = 0
	_refresh_campfire_slots()
	return taken


## Used by Chef: true while raw meat is still cooking.
func has_meat_in_progress() -> bool:
	return _raw_count > 0


## Used by Chef: true when the raw stack has room for more meat.
func has_raw_room() -> bool:
	return _raw_count < RAW_CAPACITY


func remove_meat_from_slot(slot_index: int) -> bool:
	if slot_index == COOKED_SLOT and _cooked_count > 0:
		_cooked_count = 0
		_refresh_campfire_slots()
		return true
	return false


func _campfire_can_drop(_at_position: Vector2, data: Variant, slot_index: int) -> bool:
	if not _open or not data is Dictionary or slot_index != RAW_SLOT:
		return false
	var drag_data: Dictionary = data as Dictionary
	return drag_data.get("kind", "") == "raw_meat" and _raw_count < RAW_CAPACITY


func _campfire_drop(_at_position: Vector2, data: Variant, slot_index: int) -> void:
	if not _campfire_can_drop(_at_position, data, slot_index) or not is_instance_valid(_inventory):
		return
	var drag_data: Dictionary = data as Dictionary
	var source_slot: int = int(drag_data.get("source_slot", -1))
	if _inventory.remove_raw_meat_from_slot(source_slot, 1):
		add_raw_meat_from_npc()


func _refresh_campfire_slots() -> void:
	for slot_index in range(_slot_labels.size()):
		if slot_index == RAW_SLOT:
			_slot_icons[slot_index].texture = RAW_MEAT_ICON if _raw_count > 0 else null
			_slot_labels[slot_index].text = "%d raw (%ds)" % [_raw_count, ceili(_raw_cook_remaining)] if _raw_count > 0 else "Empty"
		else:
			_slot_icons[slot_index].texture = COOKED_MEAT_ICON if _cooked_count > 0 else null
			_slot_labels[slot_index].text = "%d cooked" % _cooked_count if _cooked_count > 0 else "Empty"
		var has_items: bool = (_raw_count > 0) if slot_index == RAW_SLOT else (_cooked_count > 0)
		_slot_labels[slot_index].add_theme_color_override("font_color", Color(1.0, 0.9, 0.78, 1.0) if has_items else Color(0.78, 0.78, 0.78, 1.0))
