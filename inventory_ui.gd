class_name InventoryUI
extends CanvasLayer

const WOOD_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/wood-log.png")
const FIBER_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/plant-fiber.png")
const RAW_MEAT_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/raw-meat.png")
const COOKED_MEAT_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/cooked-meat.png")
const AXE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/woodcutters-axe.png")
const STONE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/stone-chunk.png")
const PICKAXE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/mining-pickaxe.png")
const CAMPFIRE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/campfire.png")
const BERRIES_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/wild-berries.png")
const MUSHROOM_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/edible-mushroom.png")
const HERB_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/medicinal-herbs.png")
const BEEF_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/raw-meat.png")
const HIDE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/animal-hide.png")
const BONE_ICON: Texture2D = preload("res://Wilderness-Survival-Crafting-Essentials/PNG/128/animal-bone.png")
const HERB_BEEF_ICON: Texture2D = preload("res://assets/generated/recipe_herb_roasted_beef.png")
const BERRY_BEEF_ICON: Texture2D = preload("res://assets/generated/recipe_berry_glazed_beef.png")
const MUSHROOM_CHICKEN_ICON: Texture2D = preload("res://assets/generated/recipe_mushroom_roasted_chicken.png")
const HERB_MUSHROOM_CHICKEN_ICON: Texture2D = preload("res://assets/generated/recipe_herb_mushroom_chicken.png")

## Minimal 3x3 inventory with wood stacks capped at 99 per slot.
## Open / close with the "inventory" input action (Tab or I).

@export var toggle_action: StringName = &"inventory"

const SLOT_CAPACITY: int = 99
const SLOT_COUNT: int = 9

@onready var root: CenterContainer = $Root
@onready var slots: GridContainer = $Root/Window/Grid

var wood_stacks: Array[int] = []
var fiber_stacks: Array[int] = []
var raw_meat_stacks: Array[int] = []
var cooked_meat_stacks: Array[int] = []
var axe_stacks: Array[int] = []
var pickaxe_stacks: Array[int] = []
var campfire_stacks: Array[int] = []
var stone_stacks: Array[int] = []
var berry_stacks: Array[int] = []
var mushroom_stacks: Array[int] = []
var herb_stacks: Array[int] = []
var beef_stacks: Array[int] = []
var hide_stacks: Array[int] = []
var bone_stacks: Array[int] = []
var herb_beef_stacks: Array[int] = []
var berry_beef_stacks: Array[int] = []
var mushroom_chicken_stacks: Array[int] = []
var herb_mushroom_chicken_stacks: Array[int] = []
var _equipped_pickaxe: bool = false
var _equipped_campfire: bool = false
var _slot_labels: Array[Label] = []
var _slot_icons: Array[TextureRect] = []
var _slot_panels: Array[Panel] = []
var _equipped_axe: bool = false
var _campfire_placement: CampfirePlacement
var _farm_plot_placement: FarmPlotPlacement
var _farm_plot_crafting: FarmPlotCrafting
var _equipped_box: PanelContainer
var _equipped_icon: TextureRect
var _equipped_label: Label


func _ready() -> void:
	# Lets the player (and future code) know a blocking UI is on screen.
	root.add_to_group("blocking_ui")
	root.visible = false
	_create_equipped_display()
	_campfire_placement = CampfirePlacement.new()
	_campfire_placement.name = "CampfirePlacement"
	add_child(_campfire_placement)
	_campfire_placement.setup(get_tree().current_scene.get_node("Player") as PlayerController, self)
	_farm_plot_placement = FarmPlotPlacement.new()
	_farm_plot_placement.name = "FarmPlotPlacement"
	add_child(_farm_plot_placement)
	_farm_plot_placement.setup(get_tree().current_scene.get_node("Player") as PlayerController, self)
	_farm_plot_crafting = FarmPlotCrafting.new()
	_farm_plot_crafting.name = "FarmPlotCrafting"
	_farm_plot_crafting.setup(self, _farm_plot_placement)
	add_child(_farm_plot_crafting)
	# Build one count label per slot while retaining the existing empty grid.
	for slot_index in range(SLOT_COUNT):
		wood_stacks.append(0)
		fiber_stacks.append(0)
		raw_meat_stacks.append(0)
		cooked_meat_stacks.append(0)
		axe_stacks.append(0)
		pickaxe_stacks.append(0)
		campfire_stacks.append(0)
		stone_stacks.append(0)
		berry_stacks.append(0)
		mushroom_stacks.append(0)
		herb_stacks.append(0)
		beef_stacks.append(0)
		hide_stacks.append(0)
		bone_stacks.append(0)
		herb_beef_stacks.append(0)
		berry_beef_stacks.append(0)
		mushroom_chicken_stacks.append(0)
		herb_mushroom_chicken_stacks.append(0)
		var slot: Panel = slots.get_child(slot_index) as Panel
		var icon: TextureRect = TextureRect.new()
		icon.name = "ItemIcon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 4.0
		icon.offset_right = -8.0
		icon.offset_bottom = -20.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_slot_icons.append(icon)
		var count_label: Label = Label.new()
		count_label.name = "Count"
		count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.offset_bottom = -2.0
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count_label)
		_slot_labels.append(count_label)
		_slot_panels.append(slot)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(slot_index))
		slot.set_drag_forwarding(Callable(self, "_inventory_drag_data").bind(slot_index), Callable(self, "_inventory_can_drop").bind(slot_index), Callable(self, "_inventory_drop").bind(slot_index))
	# Start with one cooked meat for the Woodsman friendship quest.
	add_cooked_meat(1)
	# Keep the toggle working even if the game is paused later on.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _create_equipped_display() -> void:
	_equipped_box = PanelContainer.new()
	_equipped_box.name = "EquippedBox"
	_equipped_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_equipped_box.offset_left = 18.0
	_equipped_box.offset_top = -96.0
	_equipped_box.offset_right = 118.0
	_equipped_box.offset_bottom = -18.0
	_equipped_box.add_theme_stylebox_override("panel", _make_box_style(Color(0.07, 0.08, 0.1, 0.88), Color(0.68, 0.72, 0.78, 1.0)))
	add_child(_equipped_box)
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_equipped_box.add_child(content)
	_equipped_icon = TextureRect.new()
	_equipped_icon.name = "EquippedIcon"
	_equipped_icon.custom_minimum_size = Vector2(48.0, 48.0)
	_equipped_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_equipped_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_equipped_icon)
	_equipped_label = Label.new()
	_equipped_label.name = "EquippedName"
	_equipped_label.text = "Nothing equipped"
	_equipped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_equipped_label)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not is_open() or not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if pickaxe_stacks[slot_index] > 0:
		_equipped_pickaxe = not _equipped_pickaxe
		_equipped_axe = false
		_equipped_campfire = false
	elif axe_stacks[slot_index] > 0:
		_equipped_axe = not _equipped_axe
		_equipped_pickaxe = false
		_equipped_campfire = false
	elif campfire_stacks[slot_index] > 0:
		_equipped_campfire = not _equipped_campfire
		_equipped_axe = false
		_equipped_pickaxe = false
	else:
		_equipped_axe = false
		_equipped_pickaxe = false
		_equipped_campfire = false
	_refresh_slots()
	get_viewport().set_input_as_handled()


func _make_box_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


func is_open() -> bool:
	return root != null and root.visible


func set_open(open: bool) -> void:
	if root == null:
		return
	root.visible = open
	root.offset_left = 0.0
	root.offset_right = 0.0
	if open:
		var crafting_menu: CraftingMenu = get_tree().current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
		if is_instance_valid(crafting_menu):
			crafting_menu.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func set_open_beside_campfire(open: bool) -> void:
	if root == null:
		return
	root.visible = open
	root.offset_left = -285.0 if open else 0.0
	root.offset_right = -285.0 if open else 0.0
	if open:
		var crafting_menu: CraftingMenu = get_tree().current_scene.get_node_or_null("CraftingMenu") as CraftingMenu
		if is_instance_valid(crafting_menu):
			crafting_menu.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _inventory_drag_data(_at_position: Vector2, slot_index: int) -> Variant:
	if not is_open() and not _is_chest_interactive():
		return null
	var item_name: String = get_slot_item_name(slot_index)
	if item_name.is_empty():
		return null
	var kind: String = "raw_meat" if item_name == "Raw Meat" else "inventory_item"
	return {"kind": kind, "item": item_name, "source_slot": slot_index}


func _is_chest_interactive() -> bool:
	var chest: ChestInventoryMenu = get_tree().current_scene.get_node_or_null("ChestInventoryMenu") as ChestInventoryMenu
	return is_instance_valid(chest) and chest.is_open()


func _inventory_can_drop(_at_position: Vector2, data: Variant, slot_index: int) -> bool:
	if (not is_open() and not _is_chest_interactive()) or not data is Dictionary or slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	var drag_data: Dictionary = data as Dictionary
	if drag_data.get("kind", "") == "chest_item":
		var chest: ChestInventoryMenu = get_tree().current_scene.get_node_or_null("ChestInventoryMenu") as ChestInventoryMenu
		if not is_instance_valid(chest):
			return false
		var chest_item: String = chest.get_storage_item_name(int(drag_data.get("source_slot", -1)))
		var inventory_item: String = get_slot_item_name(slot_index)
		return chest_item == inventory_item or inventory_item.is_empty()
	if drag_data.get("kind", "") == "inventory_item":
		var chest_target: ChestInventoryMenu = get_tree().current_scene.get_node_or_null("ChestInventoryMenu") as ChestInventoryMenu
		if not is_instance_valid(chest_target):
			return false
		var target_item: String = chest_target.get_storage_item_name(slot_index)
		return target_item.is_empty() or target_item == str(drag_data.get("item", ""))
	if drag_data.get("kind", "") != "campfire_meat":
		return false
	if int(drag_data.get("meat_state", 0)) == 2:
		return cooked_meat_stacks[slot_index] < SLOT_CAPACITY and (cooked_meat_stacks[slot_index] > 0 or _is_slot_empty(slot_index))
	return raw_meat_stacks[slot_index] < SLOT_CAPACITY and (raw_meat_stacks[slot_index] > 0 or _is_slot_empty(slot_index))


func _inventory_drop(_at_position: Vector2, data: Variant, slot_index: int) -> void:
	if not _inventory_can_drop(_at_position, data, slot_index):
		return
	var drag_data: Dictionary = data as Dictionary
	if drag_data.get("kind", "") == "chest_item":
		var chest_menu: ChestInventoryMenu = get_tree().current_scene.get_node_or_null("ChestInventoryMenu") as ChestInventoryMenu
		if is_instance_valid(chest_menu):
			chest_menu.withdraw_to_inventory(int(drag_data.get("source_slot", -1)), slot_index)
		return
	var source_slot: int = int(drag_data.get("source_slot", -1))
	var meat_state: int = int(drag_data.get("meat_state", 0))
	var campfire_menu: CampfireMenu = get_tree().current_scene.get_node_or_null("CampfireMenu") as CampfireMenu
	if not is_instance_valid(campfire_menu):
		return
	if meat_state == 2:
		# Cooked stack: take the whole stack at once.
		var cooked_taken: int = campfire_menu.take_cooked_meat_for_npc()
		if cooked_taken > 0:
			cooked_meat_stacks[slot_index] += cooked_taken
			_refresh_slots()
		return
	# Raw stack: the campfire is not allowed to hand raw meat back while it is cooking.
	if not campfire_menu.remove_meat_from_slot(source_slot):
		return
	raw_meat_stacks[slot_index] += 1
	_refresh_slots()


func remove_raw_meat_from_slot(slot_index: int, amount: int) -> bool:
	if slot_index < 0 or slot_index >= raw_meat_stacks.size() or amount <= 0 or raw_meat_stacks[slot_index] < amount:
		return false
	raw_meat_stacks[slot_index] -= amount
	_refresh_slots()
	return true


## Adds as much wood as fits, spilling into the next empty slots. Returns amount added.
func add_wood(amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(wood_stacks.size()):
		if remaining <= 0:
			break
		if wood_stacks[slot_index] > 0 and wood_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - wood_stacks[slot_index])
			wood_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(wood_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			wood_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_fiber(amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(fiber_stacks.size()):
		if remaining <= 0:
			break
		if fiber_stacks[slot_index] > 0 and fiber_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - fiber_stacks[slot_index])
			fiber_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(fiber_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			fiber_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_raw_meat(amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(raw_meat_stacks.size()):
		if remaining <= 0:
			break
		if raw_meat_stacks[slot_index] > 0 and raw_meat_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - raw_meat_stacks[slot_index])
			raw_meat_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(raw_meat_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			raw_meat_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func get_total_cooked_meat() -> int:
	return _total(cooked_meat_stacks)


func remove_cooked_meat(amount: int) -> bool:
	if amount <= 0 or get_total_cooked_meat() < amount:
		return false
	_remove_items(cooked_meat_stacks, amount)
	_refresh_slots()
	return true


func add_cooked_meat(amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(cooked_meat_stacks.size()):
		if remaining <= 0:
			break
		if cooked_meat_stacks[slot_index] > 0 and cooked_meat_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - cooked_meat_stacks[slot_index])
			cooked_meat_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(cooked_meat_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			cooked_meat_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_axe(amount: int = 1) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(axe_stacks.size()):
		if remaining <= 0:
			break
		if axe_stacks[slot_index] > 0 and axe_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - axe_stacks[slot_index])
			axe_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(axe_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			axe_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_pickaxe(amount: int = 1) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(pickaxe_stacks.size()):
		if remaining <= 0:
			break
		if pickaxe_stacks[slot_index] > 0 and pickaxe_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - pickaxe_stacks[slot_index])
			pickaxe_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(pickaxe_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			pickaxe_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_campfire(amount: int = 1) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(campfire_stacks.size()):
		if remaining <= 0:
			break
		if campfire_stacks[slot_index] > 0 and campfire_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - campfire_stacks[slot_index])
			campfire_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(campfire_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			campfire_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_stone(amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(stone_stacks.size()):
		if remaining <= 0:
			break
		if stone_stacks[slot_index] > 0 and stone_stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - stone_stacks[slot_index])
			stone_stacks[slot_index] += added
			remaining -= added
	for slot_index in range(stone_stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			stone_stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func add_berry(amount: int) -> int:
	return _add_to_stacks(berry_stacks, amount)


func add_mushroom(amount: int) -> int:
	return _add_to_stacks(mushroom_stacks, amount)


func add_herb(amount: int) -> int:
	return _add_to_stacks(herb_stacks, amount)


func add_beef(amount: int) -> int:
	return _add_to_stacks(beef_stacks, amount)


func add_animal_hide(amount: int) -> int:
	return _add_to_stacks(hide_stacks, amount)


func add_animal_bone(amount: int) -> int:
	return _add_to_stacks(bone_stacks, amount)


func add_herb_roasted_beef(amount: int) -> int:
	return _add_to_stacks(herb_beef_stacks, amount)


func add_berry_glazed_beef(amount: int) -> int:
	return _add_to_stacks(berry_beef_stacks, amount)


func add_mushroom_roasted_chicken(amount: int) -> int:
	return _add_to_stacks(mushroom_chicken_stacks, amount)


func add_herb_mushroom_chicken(amount: int) -> int:
	return _add_to_stacks(herb_mushroom_chicken_stacks, amount)


## Adds any supported item by name, spilling across slots. Returns the amount added.
func add_item(item_name: String, amount: int) -> int:
	if not _supports_item(item_name):
		return 0
	return _add_to_stacks(_stacks_for_item(item_name), amount)


## Removes exactly `amount` of an item across all slots. Returns false (and
## removes nothing) when the inventory does not hold that many.
func remove_item(item_name: String, amount: int) -> bool:
	if amount <= 0 or not _supports_item(item_name):
		return false
	if _total_for_item(item_name) < amount:
		return false
	_remove_items(_stacks_for_item(item_name), amount)
	_refresh_slots()
	return true


## Adds a cooked campfire dish by item name. Returns the amount actually added.
func add_cooked_dish(item_name: String, amount: int) -> int:
	return add_item(item_name, amount)


## Total count of any supported item across all slots.
func get_total_for_item(item_name: String) -> int:
	return _total_for_item(item_name)


## True when every required ingredient is present in the counts given.
func can_consume_items(requirements: Dictionary) -> bool:
	for item_value: Variant in requirements.keys():
		var item_name: String = String(item_value)
		var amount: int = int(requirements[item_name])
		if amount < 0 or not _supports_item(item_name):
			return false
		if _total_for_item(item_name) < amount:
			return false
	return true


## Removes all listed ingredients at once, but only if every one is available.
## Nothing is removed when any requirement is unmet, so a failed craft is safe.
func consume_items(requirements: Dictionary) -> bool:
	if not can_consume_items(requirements):
		return false
	for item_value: Variant in requirements.keys():
		var item_name: String = String(item_value)
		_remove_items(_stacks_for_item(item_name), int(requirements[item_name]))
	_refresh_slots()
	return true


func _stacks_for_item(item_name: String) -> Array[int]:
	match item_name:
		"Wood": return wood_stacks
		"Fiber": return fiber_stacks
		"Raw Meat": return raw_meat_stacks
		"Cooked Meat": return cooked_meat_stacks
		"Axe": return axe_stacks
		"Stone": return stone_stacks
		"Pickaxe": return pickaxe_stacks
		"Campfire": return campfire_stacks
		"Wild Berries": return berry_stacks
		"Wild Mushrooms": return mushroom_stacks
		"Wild Herbs": return herb_stacks
		"Beef": return beef_stacks
		"Animal Hide": return hide_stacks
		"Animal Bone": return bone_stacks
		"Herb-Roasted Beef": return herb_beef_stacks
		"Berry-Glazed Beef": return berry_beef_stacks
		"Mushroom-Roasted Chicken": return mushroom_chicken_stacks
		"Herb & Mushroom Chicken": return herb_mushroom_chicken_stacks
	var empty: Array[int] = []
	return empty


func add_cow_harvest_yield(beef_amount: int, hide_amount: int, bone_amount: int) -> bool:
	var additions: Dictionary = {"Beef": beef_amount, "Animal Hide": hide_amount, "Animal Bone": bone_amount}
	if not can_add_item_bundle(additions):
		return false
	_add_to_stacks(beef_stacks, beef_amount)
	_add_to_stacks(hide_stacks, hide_amount)
	_add_to_stacks(bone_stacks, bone_amount)
	return true


func can_add_item_bundle(additions: Dictionary) -> bool:
	var empty_slots: int = 0
	var required_new_slots: int = 0
	for slot_index: int in range(SLOT_COUNT):
		if _is_slot_empty(slot_index):
			empty_slots += 1
	for item_value: Variant in additions.keys():
		var item_name: String = String(item_value)
		var amount: int = int(additions[item_name])
		if amount < 0 or not _supports_item(item_name):
			return false
		var stack_room: int = 0
		for slot_index: int in range(SLOT_COUNT):
			if get_slot_item_name(slot_index) == item_name:
				stack_room += maxi(0, SLOT_CAPACITY - get_slot_item_count(slot_index, item_name))
		var overflow: int = maxi(0, amount - stack_room)
		required_new_slots += ceili(float(overflow) / float(SLOT_CAPACITY))
	return required_new_slots <= empty_slots


func _supports_item(item_name: String) -> bool:
	return ["Wood", "Fiber", "Raw Meat", "Cooked Meat", "Axe", "Pickaxe", "Campfire", "Stone", "Wild Berries", "Wild Mushrooms", "Wild Herbs", "Beef", "Animal Hide", "Animal Bone", "Herb-Roasted Beef", "Berry-Glazed Beef", "Mushroom-Roasted Chicken", "Herb & Mushroom Chicken"].has(item_name)


func _total_for_item(item_name: String) -> int:
	match item_name:
		"Wood": return _total(wood_stacks)
		"Fiber": return _total(fiber_stacks)
		"Raw Meat": return _total(raw_meat_stacks)
		"Cooked Meat": return _total(cooked_meat_stacks)
		"Axe": return _total(axe_stacks)
		"Pickaxe": return _total(pickaxe_stacks)
		"Campfire": return _total(campfire_stacks)
		"Stone": return _total(stone_stacks)
		"Wild Berries": return _total(berry_stacks)
		"Wild Mushrooms": return _total(mushroom_stacks)
		"Wild Herbs": return _total(herb_stacks)
		"Beef": return _total(beef_stacks)
		"Animal Hide": return _total(hide_stacks)
		"Animal Bone": return _total(bone_stacks)
		"Herb-Roasted Beef": return _total(herb_beef_stacks)
		"Berry-Glazed Beef": return _total(berry_beef_stacks)
		"Mushroom-Roasted Chicken": return _total(mushroom_chicken_stacks)
		"Herb & Mushroom Chicken": return _total(herb_mushroom_chicken_stacks)
	return 0


func _add_to_stacks(stacks: Array[int], amount: int) -> int:
	var remaining: int = maxi(amount, 0)
	var starting_amount: int = remaining
	for slot_index in range(stacks.size()):
		if remaining <= 0:
			break
		if stacks[slot_index] > 0 and stacks[slot_index] < SLOT_CAPACITY:
			var added: int = mini(remaining, SLOT_CAPACITY - stacks[slot_index])
			stacks[slot_index] += added
			remaining -= added
	for slot_index in range(stacks.size()):
		if remaining <= 0:
			break
		if _is_slot_empty(slot_index):
			var added: int = mini(remaining, SLOT_CAPACITY)
			stacks[slot_index] = added
			remaining -= added
	_refresh_slots()
	return starting_amount - remaining


func get_slot_item_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return ""
	if wood_stacks[slot_index] > 0:
		return "Wood"
	if fiber_stacks[slot_index] > 0:
		return "Fiber"
	if raw_meat_stacks[slot_index] > 0:
		return "Raw Meat"
	if cooked_meat_stacks[slot_index] > 0:
		return "Cooked Meat"
	if axe_stacks[slot_index] > 0:
		return "Axe"
	if stone_stacks[slot_index] > 0:
		return "Stone"
	if pickaxe_stacks[slot_index] > 0:
		return "Pickaxe"
	if campfire_stacks[slot_index] > 0:
		return "Campfire"
	if berry_stacks[slot_index] > 0:
		return "Wild Berries"
	if mushroom_stacks[slot_index] > 0:
		return "Wild Mushrooms"
	if herb_stacks[slot_index] > 0:
		return "Wild Herbs"
	if beef_stacks[slot_index] > 0:
		return "Beef"
	if hide_stacks[slot_index] > 0:
		return "Animal Hide"
	if bone_stacks[slot_index] > 0:
		return "Animal Bone"
	if herb_beef_stacks[slot_index] > 0:
		return "Herb-Roasted Beef"
	if berry_beef_stacks[slot_index] > 0:
		return "Berry-Glazed Beef"
	if mushroom_chicken_stacks[slot_index] > 0:
		return "Mushroom-Roasted Chicken"
	if herb_mushroom_chicken_stacks[slot_index] > 0:
		return "Herb & Mushroom Chicken"
	return ""


func get_slot_item_count(slot_index: int, item_name: String) -> int:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return 0
	match item_name:
		"Wood": return wood_stacks[slot_index]
		"Fiber": return fiber_stacks[slot_index]
		"Raw Meat": return raw_meat_stacks[slot_index]
		"Cooked Meat": return cooked_meat_stacks[slot_index]
		"Axe": return axe_stacks[slot_index]
		"Stone": return stone_stacks[slot_index]
		"Pickaxe": return pickaxe_stacks[slot_index]
		"Campfire": return campfire_stacks[slot_index]
		"Wild Berries": return berry_stacks[slot_index]
		"Wild Mushrooms": return mushroom_stacks[slot_index]
		"Wild Herbs": return herb_stacks[slot_index]
		"Beef": return beef_stacks[slot_index]
		"Animal Hide": return hide_stacks[slot_index]
		"Animal Bone": return bone_stacks[slot_index]
		"Herb-Roasted Beef": return herb_beef_stacks[slot_index]
		"Berry-Glazed Beef": return berry_beef_stacks[slot_index]
		"Mushroom-Roasted Chicken": return mushroom_chicken_stacks[slot_index]
		"Herb & Mushroom Chicken": return herb_mushroom_chicken_stacks[slot_index]
	return 0


func remove_slot_item(slot_index: int, item_name: String, amount: int) -> bool:
	if amount <= 0 or get_slot_item_count(slot_index, item_name) < amount:
		return false
	match item_name:
		"Wood": wood_stacks[slot_index] -= amount
		"Fiber": fiber_stacks[slot_index] -= amount
		"Raw Meat": raw_meat_stacks[slot_index] -= amount
		"Cooked Meat": cooked_meat_stacks[slot_index] -= amount
		"Axe": axe_stacks[slot_index] -= amount
		"Stone": stone_stacks[slot_index] -= amount
		"Pickaxe": pickaxe_stacks[slot_index] -= amount
		"Campfire": campfire_stacks[slot_index] -= amount
		"Wild Berries": berry_stacks[slot_index] -= amount
		"Wild Mushrooms": mushroom_stacks[slot_index] -= amount
		"Wild Herbs": herb_stacks[slot_index] -= amount
		"Beef": beef_stacks[slot_index] -= amount
		"Animal Hide": hide_stacks[slot_index] -= amount
		"Animal Bone": bone_stacks[slot_index] -= amount
		"Herb-Roasted Beef": herb_beef_stacks[slot_index] -= amount
		"Berry-Glazed Beef": berry_beef_stacks[slot_index] -= amount
		"Mushroom-Roasted Chicken": mushroom_chicken_stacks[slot_index] -= amount
		"Herb & Mushroom Chicken": herb_mushroom_chicken_stacks[slot_index] -= amount
		_: return false
	_refresh_slots()
	return true


func add_item_to_slot(slot_index: int, item_name: String, amount: int) -> int:
	if slot_index < 0 or slot_index >= SLOT_COUNT or amount <= 0:
		return 0
	if not _is_slot_empty(slot_index) and get_slot_item_name(slot_index) != item_name:
		return 0
	var accepted: int = mini(amount, SLOT_CAPACITY - get_slot_item_count(slot_index, item_name))
	match item_name:
		"Wood": wood_stacks[slot_index] += accepted
		"Fiber": fiber_stacks[slot_index] += accepted
		"Raw Meat": raw_meat_stacks[slot_index] += accepted
		"Cooked Meat": cooked_meat_stacks[slot_index] += accepted
		"Axe": axe_stacks[slot_index] += accepted
		"Stone": stone_stacks[slot_index] += accepted
		"Pickaxe": pickaxe_stacks[slot_index] += accepted
		"Campfire": campfire_stacks[slot_index] += accepted
		"Wild Berries": berry_stacks[slot_index] += accepted
		"Wild Mushrooms": mushroom_stacks[slot_index] += accepted
		"Wild Herbs": herb_stacks[slot_index] += accepted
		"Beef": beef_stacks[slot_index] += accepted
		"Animal Hide": hide_stacks[slot_index] += accepted
		"Animal Bone": bone_stacks[slot_index] += accepted
		"Herb-Roasted Beef": herb_beef_stacks[slot_index] += accepted
		"Berry-Glazed Beef": berry_beef_stacks[slot_index] += accepted
		"Mushroom-Roasted Chicken": mushroom_chicken_stacks[slot_index] += accepted
		"Herb & Mushroom Chicken": herb_mushroom_chicken_stacks[slot_index] += accepted
		_: return 0
	_refresh_slots()
	return accepted


func get_total_wood() -> int:
	return _total(wood_stacks)


func get_total_stone() -> int:
	return _total(stone_stacks)


func remove_stone(amount: int) -> bool:
	if amount <= 0 or get_total_stone() < amount:
		return false
	_remove_items(stone_stacks, amount)
	_refresh_slots()
	return true


func get_total_fiber() -> int:
	return _total(fiber_stacks)


func get_save_state() -> Dictionary:
	var stacks: Dictionary = {}
	for item: String in SaveManager.ALL_ITEM_NAMES:
		var values: Array[int] = []
		for slot: int in range(SLOT_COUNT):
			values.append(get_slot_item_count(slot, item))
		stacks[item] = values
	return {"stacks": stacks, "axe": _equipped_axe, "pickaxe": _equipped_pickaxe, "campfire": _equipped_campfire}

func set_save_state(state: Dictionary) -> void:
	var stacks: Dictionary = state["stacks"]
	var arrays: Dictionary = {"Wood": wood_stacks, "Fiber": fiber_stacks, "Raw Meat": raw_meat_stacks, "Cooked Meat": cooked_meat_stacks, "Axe": axe_stacks, "Pickaxe": pickaxe_stacks, "Campfire": campfire_stacks, "Stone": stone_stacks, "Wild Berries": berry_stacks, "Wild Mushrooms": mushroom_stacks, "Wild Herbs": herb_stacks, "Beef": beef_stacks, "Animal Hide": hide_stacks, "Animal Bone": bone_stacks, "Herb-Roasted Beef": herb_beef_stacks, "Berry-Glazed Beef": berry_beef_stacks, "Mushroom-Roasted Chicken": mushroom_chicken_stacks, "Herb & Mushroom Chicken": herb_mushroom_chicken_stacks}
	for item: String in SaveManager.ALL_ITEM_NAMES:
		var target: Array = arrays[item]
		var saved: Variant = stacks.get(item)
		if not saved is Array:
			# Save predates this item; leave the stack empty.
			for slot: int in range(SLOT_COUNT):
				target[slot] = 0
			continue
		for slot: int in range(SLOT_COUNT):
			target[slot] = int(saved[slot])
	_equipped_axe = bool(state["axe"]) and _total(axe_stacks) > 0
	_equipped_pickaxe = bool(state["pickaxe"]) and _total(pickaxe_stacks) > 0
	_equipped_campfire = bool(state["campfire"]) and _total(campfire_stacks) > 0
	_refresh_slots()


func is_axe_equipped() -> bool:
	return _equipped_axe and _total(axe_stacks) > 0


func is_pickaxe_equipped() -> bool:
	return _equipped_pickaxe and _total(pickaxe_stacks) > 0


func is_campfire_equipped() -> bool:
	return _equipped_campfire and _total(campfire_stacks) > 0


func consume_equipped_campfire() -> void:
	if not is_campfire_equipped():
		return
	_remove_items(campfire_stacks, 1)
	_equipped_campfire = false
	_refresh_slots()


func cancel_campfire_equipped() -> void:
	_equipped_campfire = false
	_refresh_slots()


func has_crafting_resources(wood_cost: int, fiber_cost: int) -> bool:
	return _total(wood_stacks) >= wood_cost and _total(fiber_stacks) >= fiber_cost


func craft_axe() -> bool:
	if not has_crafting_resources(1, 1):
		return false
	if add_axe(1) != 1:
		return false
	_remove_items(wood_stacks, 1)
	_remove_items(fiber_stacks, 1)
	_refresh_slots()
	return true


func craft_pickaxe() -> bool:
	if _total(wood_stacks) < 1 or _total(stone_stacks) < 1:
		return false
	if add_pickaxe(1) != 1:
		return false
	_remove_items(wood_stacks, 1)
	_remove_items(stone_stacks, 1)
	_refresh_slots()
	return true


func craft_farm_plot() -> bool:
	return is_instance_valid(_farm_plot_crafting) and _farm_plot_crafting.craft()


func craft_campfire() -> bool:
	if _total(wood_stacks) < 1 or _total(fiber_stacks) < 1 or _total(stone_stacks) < 1:
		return false
	if add_campfire(1) != 1:
		return false
	_remove_items(wood_stacks, 1)
	_remove_items(fiber_stacks, 1)
	_remove_items(stone_stacks, 1)
	_refresh_slots()
	return true


func _total(stacks: Array[int]) -> int:
	var total: int = 0
	for amount in stacks:
		total += amount
	return total


func _is_slot_empty(slot_index: int) -> bool:
	return wood_stacks[slot_index] == 0 and fiber_stacks[slot_index] == 0 and raw_meat_stacks[slot_index] == 0 and cooked_meat_stacks[slot_index] == 0 and axe_stacks[slot_index] == 0 and pickaxe_stacks[slot_index] == 0 and campfire_stacks[slot_index] == 0 and stone_stacks[slot_index] == 0 and berry_stacks[slot_index] == 0 and mushroom_stacks[slot_index] == 0 and herb_stacks[slot_index] == 0 and beef_stacks[slot_index] == 0 and hide_stacks[slot_index] == 0 and bone_stacks[slot_index] == 0 and herb_beef_stacks[slot_index] == 0 and berry_beef_stacks[slot_index] == 0 and mushroom_chicken_stacks[slot_index] == 0 and herb_mushroom_chicken_stacks[slot_index] == 0


func _remove_items(stacks: Array[int], amount: int) -> void:
	var remaining: int = amount
	for slot_index in range(stacks.size()):
		if remaining <= 0:
			break
		var removed: int = mini(stacks[slot_index], remaining)
		stacks[slot_index] -= removed
		remaining -= removed


func _refresh_slots() -> void:
	if _slot_labels.is_empty() or _equipped_icon == null or _equipped_label == null:
		return
	for slot_index in range(_slot_labels.size()):
		var wood_count: int = wood_stacks[slot_index]
		var fiber_count: int = fiber_stacks[slot_index]
		var raw_meat_count: int = raw_meat_stacks[slot_index]
		var cooked_meat_count: int = cooked_meat_stacks[slot_index]
		var axe_count: int = axe_stacks[slot_index]
		var pickaxe_count: int = pickaxe_stacks[slot_index]
		var campfire_count: int = campfire_stacks[slot_index]
		var stone_count: int = stone_stacks[slot_index]
		var berry_count: int = berry_stacks[slot_index]
		var mushroom_count: int = mushroom_stacks[slot_index]
		var herb_count: int = herb_stacks[slot_index]
		var beef_count: int = beef_stacks[slot_index]
		var hide_count: int = hide_stacks[slot_index]
		var bone_count: int = bone_stacks[slot_index]
		var herb_beef_count: int = herb_beef_stacks[slot_index]
		var berry_beef_count: int = berry_beef_stacks[slot_index]
		var mushroom_chicken_count: int = mushroom_chicken_stacks[slot_index]
		var herb_mushroom_chicken_count: int = herb_mushroom_chicken_stacks[slot_index]
		if wood_count > 0:
			_slot_icons[slot_index].texture = WOOD_ICON
			_slot_labels[slot_index].text = str(wood_count)
		elif fiber_count > 0:
			_slot_icons[slot_index].texture = FIBER_ICON
			_slot_labels[slot_index].text = str(fiber_count)
		elif raw_meat_count > 0:
			_slot_icons[slot_index].texture = RAW_MEAT_ICON
			_slot_labels[slot_index].text = str(raw_meat_count)
		elif cooked_meat_count > 0:
			_slot_icons[slot_index].texture = COOKED_MEAT_ICON
			_slot_labels[slot_index].text = str(cooked_meat_count)
		elif axe_count > 0:
			_slot_icons[slot_index].texture = AXE_ICON
			_slot_labels[slot_index].text = str(axe_count)
		elif pickaxe_count > 0:
			_slot_icons[slot_index].texture = PICKAXE_ICON
			_slot_labels[slot_index].text = str(pickaxe_count)
		elif campfire_count > 0:
			_slot_icons[slot_index].texture = CAMPFIRE_ICON
			_slot_labels[slot_index].text = str(campfire_count)
		elif stone_count > 0:
			_slot_icons[slot_index].texture = STONE_ICON
			_slot_labels[slot_index].text = str(stone_count)
		elif berry_count > 0:
			_slot_icons[slot_index].texture = BERRIES_ICON
			_slot_labels[slot_index].text = str(berry_count)
		elif mushroom_count > 0:
			_slot_icons[slot_index].texture = MUSHROOM_ICON
			_slot_labels[slot_index].text = str(mushroom_count)
		elif herb_count > 0:
			_slot_icons[slot_index].texture = HERB_ICON
			_slot_labels[slot_index].text = str(herb_count)
		elif beef_count > 0:
			_slot_icons[slot_index].texture = BEEF_ICON
			_slot_labels[slot_index].text = str(beef_count)
		elif hide_count > 0:
			_slot_icons[slot_index].texture = HIDE_ICON
			_slot_labels[slot_index].text = str(hide_count)
		elif bone_count > 0:
			_slot_icons[slot_index].texture = BONE_ICON
			_slot_labels[slot_index].text = str(bone_count)
		elif herb_beef_count > 0:
			_slot_icons[slot_index].texture = HERB_BEEF_ICON
			_slot_labels[slot_index].text = str(herb_beef_count)
		elif berry_beef_count > 0:
			_slot_icons[slot_index].texture = BERRY_BEEF_ICON
			_slot_labels[slot_index].text = str(berry_beef_count)
		elif mushroom_chicken_count > 0:
			_slot_icons[slot_index].texture = MUSHROOM_CHICKEN_ICON
			_slot_labels[slot_index].text = str(mushroom_chicken_count)
		elif herb_mushroom_chicken_count > 0:
			_slot_icons[slot_index].texture = HERB_MUSHROOM_CHICKEN_ICON
			_slot_labels[slot_index].text = str(herb_mushroom_chicken_count)
		else:
			_slot_icons[slot_index].texture = null
			_slot_labels[slot_index].text = ""
		var slot_style: StyleBoxFlat = _make_box_style(Color(0.17, 0.18, 0.21, 1.0), Color(0.34, 0.37, 0.42, 1.0))
		if (_equipped_axe and axe_count > 0) or (_equipped_pickaxe and pickaxe_count > 0) or (_equipped_campfire and campfire_count > 0):
			slot_style.bg_color = Color(0.23, 0.29, 0.22, 1.0)
			slot_style.border_color = Color(0.78, 0.91, 0.48, 1.0)
			slot_style.set_border_width_all(3)
		_slot_panels[slot_index].add_theme_stylebox_override("panel", slot_style)
	_refresh_equipped_display()


func _refresh_equipped_display() -> void:
	_equipped_icon.texture = AXE_ICON if _equipped_axe else PICKAXE_ICON if _equipped_pickaxe else CAMPFIRE_ICON if _equipped_campfire else null
	_equipped_label.text = "Woodcutter's Axe" if _equipped_axe else "Pickaxe" if _equipped_pickaxe else "Campfire" if _equipped_campfire else "Nothing equipped"
	_equipped_icon.visible = _equipped_axe or _equipped_pickaxe or _equipped_campfire


func _process(_delta: float) -> void:
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		set_open(not is_open())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and is_open():
		set_open(false)
		get_viewport().set_input_as_handled()