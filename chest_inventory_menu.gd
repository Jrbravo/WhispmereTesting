class_name ChestInventoryMenu
extends CanvasLayer

const SLOT_COUNT: int = 12
const SLOT_CAPACITY: int = 99
const ITEM_ICONS: Dictionary = {
	"Wood": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/wood-log.png"),
	"Fiber": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/plant-fiber.png"),
	"Raw Meat": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/raw-meat.png"),
	"Cooked Meat": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/cooked-meat.png"),
	"Axe": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/woodcutters-axe.png"),
	"Stone": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/stone-chunk.png"),
	"Pickaxe": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/mining-pickaxe.png"),
	"Campfire": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/campfire.png"),
	"Wild Berries": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/wild-berries.png"),
	"Wild Mushrooms": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/edible-mushroom.png"),
	"Wild Herbs": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/medicinal-herbs.png"),
	"Beef": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/raw-meat.png"),
	"Animal Hide": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/animal-hide.png"),
	"Animal Bone": preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/animal-bone.png"),
	"Herb-Roasted Beef": preload("res://assets/generated/recipe_herb_roasted_beef.png"),
	"Berry-Glazed Beef": preload("res://assets/generated/recipe_berry_glazed_beef.png"),
	"Mushroom-Roasted Chicken": preload("res://assets/generated/recipe_mushroom_roasted_chicken.png"),
	"Herb & Mushroom Chicken": preload("res://assets/generated/recipe_herb_mushroom_chicken.png"),
}

var _root: CenterContainer
var _panel: PanelContainer
var _storage_slots: GridContainer
var _storage_items: Array[Dictionary] = []
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _inventory: InventoryUI
var _storage_home: VBoxContainer
var _inventory_home: Node
var _inventory_window: Control
var _inventory_column: VBoxContainer
var _open: bool = false


## Returns the one shared chest storage for the scene, creating it if needed.
## The chest, the Woodsman, and Stoney all use this so they share the same items.
static func get_or_create(scene: Node) -> ChestInventoryMenu:
	var existing: ChestInventoryMenu = scene.get_tree().get_first_node_in_group("chest_storage") as ChestInventoryMenu
	if is_instance_valid(existing):
		return existing
	var menu: ChestInventoryMenu = ChestInventoryMenu.new()
	menu.name = "ChestInventoryMenu"
	scene.add_child(menu)
	return menu


func _ready() -> void:
	add_to_group("chest_storage")
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_storage_items.resize(SLOT_COUNT)
	for index in range(SLOT_COUNT):
		_storage_items[index] = {"item": "", "count": 0}
	_build_ui()


func _build_ui() -> void:
	var screen_root: Control = Control.new()
	screen_root.name = "ScreenRoot"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.visible = false
	screen_root.add_to_group("blocking_ui")
	add_child(screen_root)
	var columns_center: CenterContainer = CenterContainer.new()
	columns_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(columns_center)
	_root = CenterContainer.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_to_group("blocking_ui")
	columns_center.add_child(_root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(410.0, 390.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
	style.border_color = Color(0.65, 0.57, 0.39, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 15.0
	style.content_margin_bottom = 15.0
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Chest Storage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	content.add_child(columns)
	var chest_column: VBoxContainer = VBoxContainer.new()
	chest_column.add_theme_constant_override("separation", 6)
	columns.add_child(chest_column)
	var chest_title: Label = Label.new()
	chest_title.text = "Chest"
	chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_column.add_child(chest_title)
	_storage_slots = GridContainer.new()
	_storage_slots.columns = 3
	_storage_slots.add_theme_constant_override("h_separation", 5)
	_storage_slots.add_theme_constant_override("v_separation", 5)
	chest_column.add_child(_storage_slots)
	_storage_home = chest_column
	for slot_index in range(SLOT_COUNT):
		var slot: Panel = _make_slot("ChestSlot%d" % slot_index)
		_storage_slots.add_child(slot)
		var icon: TextureRect = _make_icon(slot)
		var count: Label = _make_count_label(slot)
		_slot_icons.append(icon)
		_slot_labels.append(count)
		slot.set_drag_forwarding(Callable(self, "_storage_drag_data").bind(slot_index), Callable(self, "_storage_can_drop").bind(slot_index), Callable(self, "_storage_drop").bind(slot_index))
	_inventory_column = VBoxContainer.new()
	_inventory_column.add_theme_constant_override("separation", 6)
	columns.add_child(_inventory_column)
	var inventory_title: Label = Label.new()
	inventory_title.text = "Inventory"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_column.add_child(inventory_title)
	var inventory_slots: Control = _inventory.slots if is_instance_valid(_inventory) else null
	if inventory_slots != null:
		_inventory_home = inventory_slots.get_parent()
		_inventory_window = inventory_slots.get_parent_control()
	var footer: Label = Label.new()
	footer.text = "Drag items between slots • E or Esc to close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
	content.add_child(footer)
	_refresh_storage()


func _make_slot(slot_name: String) -> Panel:
	var slot: Panel = Panel.new()
	slot.name = slot_name
	slot.custom_minimum_size = Vector2(64.0, 64.0)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.18, 0.21, 1.0)
	style.border_color = Color(0.4, 0.42, 0.45, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _make_icon(slot: Panel) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "ItemIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5.0
	icon.offset_top = 4.0
	icon.offset_right = -5.0
	icon.offset_bottom = -18.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	return icon


func _make_count_label(slot: Panel) -> Label:
	var count: Label = Label.new()
	count.name = "Count"
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 13)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)
	return count


func open() -> void:
	if not is_node_ready():
		await ready
	_open = true
	get_node("ScreenRoot").visible = true
	_root.visible = true
	if is_instance_valid(_inventory):
		_storage_slots.reparent(_storage_home)
		_inventory.slots.reparent(_inventory_column)
		_inventory.slots.custom_minimum_size = Vector2(0.0, 0.0)
		_inventory.slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_inventory.root.offset_left = 0.0
		_inventory.root.offset_right = 0.0
		_inventory_window.visible = false
		_inventory.root.visible = false
		_storage_slots.queue_sort()
		_inventory.slots.queue_sort()
		_storage_slots.queue_sort()
		_inventory.slots.queue_sort()
	var crafting: CraftingMenu = get_tree().current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
	if is_instance_valid(crafting):
		crafting.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_open = false
	_root.visible = false
	get_node("ScreenRoot").visible = false
	if is_instance_valid(_inventory):
		_inventory.slots.reparent(_inventory_home)
		_storage_slots.reparent(_storage_home)
		_inventory.slots.custom_minimum_size = Vector2(0.0, 0.0)
		_inventory.slots.size_flags_horizontal = Control.SIZE_FILL
		_inventory.root.offset_left = 0.0
		_inventory.root.offset_right = 0.0
		_inventory_window.visible = true
		_inventory.root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_save_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in _storage_items:
		result.append({"item": String(slot["item"]), "count": int(slot["count"])})
	return result

func set_save_state(items: Array) -> void:
	_storage_items.clear()
	for index: int in range(SLOT_COUNT):
		var item: Dictionary = items[index] as Dictionary
		_storage_items.append({"item": str(item["item"]), "count": int(item["count"])})
	_refresh_storage()

func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed("pickup") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func get_storage_item_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return ""
	return str(_storage_items[slot_index]["item"])


func add_stone(amount: int) -> int:
	return _add_storage_item("Stone", amount)


func add_wood(amount: int) -> int:
	return _add_storage_item("Wood", amount)


func add_berry(amount: int) -> int:
	return _add_storage_item("Wild Berries", amount)


func get_berry_count() -> int:
	var total: int = 0
	for item: Dictionary in _storage_items:
		if str(item["item"]) == "Wild Berries":
			total += int(item["count"])
	return total


func can_add_berry(amount: int) -> bool:
	var capacity: int = 0
	for item: Dictionary in _storage_items:
		if str(item["item"]) == "Wild Berries":
			capacity += SLOT_CAPACITY - int(item["count"])
		elif str(item["item"]).is_empty():
			capacity += SLOT_CAPACITY
	return amount >= 0 and capacity >= amount


func remove_berry(amount: int) -> bool:
	if amount < 0 or get_berry_count() < amount:
		return false
	var remaining: int = amount
	for index in range(_storage_items.size()):
		var item: Dictionary = _storage_items[index]
		if str(item["item"]) != "Wild Berries":
			continue
		var removed: int = mini(remaining, int(item["count"]))
		item["count"] = int(item["count"]) - removed
		remaining -= removed
		if int(item["count"]) == 0:
			item["item"] = ""
		_storage_items[index] = item
		if remaining == 0:
			break
	_refresh_storage()
	return true


func _add_storage_item(item_name: String, amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(SLOT_COUNT):
		var item: Dictionary = _storage_items[slot_index]
		if str(item["item"]) == item_name and int(item["count"]) < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - int(item["count"]))
			item["count"] = int(item["count"]) + added
			_storage_items[slot_index] = item
			remaining -= added
			if remaining <= 0:
				_refresh_storage()
				return starting_amount
	for slot_index in range(SLOT_COUNT):
		var item: Dictionary = _storage_items[slot_index]
		if str(item["item"]).is_empty():
			var added: int = mini(remaining, SLOT_CAPACITY)
			item["item"] = item_name
			item["count"] = added
			_storage_items[slot_index] = item
			remaining -= added
			if remaining <= 0:
				break
	_refresh_storage()
	return starting_amount - remaining


func deposit_inventory_slot(source: int, destination: int) -> void:
	if not is_instance_valid(_inventory) or source < 0 or source >= InventoryUI.SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return
	var item_name: String = _inventory.get_slot_item_name(source)
	var target: Dictionary = _storage_items[destination]
	if item_name.is_empty() or (not str(target["item"]).is_empty() and str(target["item"]) != item_name):
		return
	var transfer: int = mini(_inventory.get_slot_item_count(source, item_name), SLOT_CAPACITY - int(target["count"]))
	if transfer > 0 and _inventory.remove_slot_item(source, item_name, transfer):
		target["item"] = item_name
		target["count"] = int(target["count"]) + transfer
		_storage_items[destination] = target
		_refresh_storage()


func withdraw_to_inventory(source: int, destination: int) -> void:
	if not is_instance_valid(_inventory) or source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= InventoryUI.SLOT_COUNT:
		return
	var item: Dictionary = _storage_items[source]
	var item_name: String = str(item["item"])
	var target_name: String = _inventory.get_slot_item_name(destination)
	if item_name.is_empty() or (not target_name.is_empty() and target_name != item_name):
		return
	var amount: int = mini(int(item["count"]), SLOT_CAPACITY - _inventory.get_slot_item_count(destination, item_name))
	var added: int = _inventory.add_item_to_slot(destination, item_name, amount)
	if added > 0:
		item["count"] = int(item["count"]) - added
		if int(item["count"]) == 0:
			item["item"] = ""
		_storage_items[source] = item
		_refresh_storage()


func _storage_drag_data(_position: Vector2, slot_index: int) -> Variant:
	if not _open or slot_index < 0 or slot_index >= SLOT_COUNT or int(_storage_items[slot_index]["count"]) <= 0:
		return null
	return {"kind": "chest_item", "source_slot": slot_index}


func _storage_can_drop(_position: Vector2, data: Variant, slot_index: int) -> bool:
	if not _open or not data is Dictionary or slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	var drag: Dictionary = data as Dictionary
	if drag.get("kind", "") == "inventory_item" or drag.get("kind", "") == "raw_meat":
		var target: Dictionary = _storage_items[slot_index]
		var item_name: String = str(drag.get("item", ""))
		return not item_name.is_empty() and (str(target["item"]).is_empty() or (str(target["item"]) == item_name and int(target["count"]) < SLOT_CAPACITY))
	if drag.get("kind", "") == "chest_item":
		return slot_index >= 0 and slot_index < SLOT_COUNT
	return false


func _storage_drop(_position: Vector2, data: Variant, slot_index: int) -> void:
	if not _storage_can_drop(_position, data, slot_index):
		return
	var drag: Dictionary = data as Dictionary
	if drag.get("kind", "") == "inventory_item" or drag.get("kind", "") == "raw_meat":
		deposit_inventory_slot(int(drag.get("source_slot", -1)), slot_index)
	else:
		_swap_storage_slots(int(drag["source_slot"]), slot_index)
	_refresh_storage()


func _transfer_from_inventory(drag: Dictionary, destination: int) -> void:
	var item_name: String = str(drag.get("item", ""))
	var source: int = int(drag.get("source_slot", -1))
	if not is_instance_valid(_inventory) or source < 0 or source >= InventoryUI.SLOT_COUNT:
		return
	var source_count: int = _inventory.get_slot_item_count(source, item_name)
	if source_count <= 0:
		return
	var target: Dictionary = _storage_items[destination]
	if not str(target["item"]).is_empty() and str(target["item"]) != item_name:
		return
	var transfer: int = mini(source_count, SLOT_CAPACITY - int(target["count"]))
	if transfer <= 0 or not _inventory.remove_slot_item(source, item_name, transfer):
		return
	target["item"] = item_name
	target["count"] = int(target["count"]) + transfer
	_storage_items[destination] = target


func _swap_storage_slots(source: int, destination: int) -> void:
	if source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return
	if source == destination:
		return
	var source_item: Dictionary = _storage_items[source]
	var target_item: Dictionary = _storage_items[destination]
	if not str(target_item["item"]).is_empty() and str(target_item["item"]) == str(source_item["item"]):
		var moved: int = mini(int(source_item["count"]), SLOT_CAPACITY - int(target_item["count"]))
		target_item["count"] = int(target_item["count"]) + moved
		source_item["count"] = int(source_item["count"]) - moved
		if int(source_item["count"]) == 0:
			source_item["item"] = ""
		_storage_items[source] = source_item
		_storage_items[destination] = target_item
		return
	_storage_items[source] = target_item
	_storage_items[destination] = source_item


func _refresh_storage() -> void:
	for index in range(SLOT_COUNT):
		var item: String = str(_storage_items[index]["item"])
		var count: int = int(_storage_items[index]["count"])
		_slot_icons[index].texture = ITEM_ICONS.get(item, null)
		_slot_labels[index].text = str(count) if count > 0 else ""
