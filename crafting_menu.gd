class_name CraftingMenu
extends CanvasLayer

@export var toggle_action: StringName = &"crafting"

@onready var root: CenterContainer = $Root
@onready var axe_slot: Panel = $Root/Window/Content/Grid/Slot1
@onready var pickaxe_slot: Panel = $Root/Window/Content/Grid/Slot2
@onready var pickaxe_icon: TextureRect = $Root/Window/Content/Grid/Slot2/PickaxeIcon
@onready var campfire_slot: Panel = $Root/Window/Content/Grid/Slot3
@onready var campfire_icon: TextureRect = $Root/Window/Content/Grid/Slot3/CampfireIcon
@onready var tent_slot: Panel = $Root/Window/Content/Grid/Slot4
@onready var crafting_grid: GridContainer = $Root/Window/Content/Grid

var _inventory: InventoryUI
var _tooltip: PanelContainer
var _tooltip_label: Label
var _axe_hovered: bool = false
var _pickaxe_hovered: bool = false
var _campfire_hovered: bool = false
var _tent_hovered: bool = false
var _farm_plot_slot: Panel
var _farm_plot_hovered: bool = false


func _ready() -> void:
	root.add_to_group("blocking_ui")
	root.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inventory = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
	_create_axe_tooltip()
	axe_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	axe_slot.mouse_entered.connect(_on_axe_mouse_entered)
	axe_slot.mouse_exited.connect(_on_axe_mouse_exited)
	axe_slot.gui_input.connect(_on_axe_gui_input)
	pickaxe_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	pickaxe_slot.mouse_entered.connect(_on_pickaxe_mouse_entered)
	pickaxe_slot.mouse_exited.connect(_on_pickaxe_mouse_exited)
	pickaxe_slot.gui_input.connect(_on_pickaxe_gui_input)
	pickaxe_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campfire_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	campfire_slot.mouse_entered.connect(_on_campfire_mouse_entered)
	campfire_slot.mouse_exited.connect(_on_campfire_mouse_exited)
	campfire_slot.gui_input.connect(_on_campfire_gui_input)
	campfire_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tent_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_farm_plot_slot = _make_farm_plot_slot()
	crafting_grid.add_child(_farm_plot_slot)
	_farm_plot_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_farm_plot_slot.mouse_entered.connect(_on_farm_plot_mouse_entered)
	_farm_plot_slot.mouse_exited.connect(_on_farm_plot_mouse_exited)
	_farm_plot_slot.gui_input.connect(_on_farm_plot_gui_input)


func is_open() -> bool:
	return root != null and root.visible


func set_open(open: bool) -> void:
	if root == null:
		return
	if open:
		var placement: FarmPlotPlacement = get_tree().current_scene.get_node_or_null("InventoryUI/FarmPlotPlacement") as FarmPlotPlacement
		if is_instance_valid(placement):
			placement.cancel_placement()
	root.visible = open
	if open:
		var inventory: InventoryUI = get_tree().current_scene.get_node_or_null("InventoryUI") as InventoryUI
		if is_instance_valid(inventory):
			inventory.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _make_farm_plot_slot() -> Panel:
	var slot: Panel = Panel.new()
	slot.name = "FarmPlotSlot"
	slot.custom_minimum_size = Vector2(72.0, 72.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.18, 0.21, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.34, 0.37, 0.42, 1.0)
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)
	var icon: TextureRect = TextureRect.new()
	icon.name = "MudIcon"
	icon.texture = load("res://assets/generated/farm_plot_icon.png") as Texture2D if ResourceLoader.exists("res://assets/generated/farm_plot_icon.png") else null
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 4.0
	icon.offset_right = -8.0
	icon.offset_bottom = -20.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var label: Label = Label.new()
	label.name = "FarmPlotName"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 2.0
	label.offset_top = 48.0
	label.offset_right = -2.0
	label.offset_bottom = -2.0
	label.text = "Farm Plot"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	return slot


func _on_farm_plot_mouse_entered() -> void:
	_farm_plot_hovered = true
	_refresh_tooltip()
	_tooltip.visible = true


func _on_farm_plot_mouse_exited() -> void:
	_farm_plot_hovered = false
	_tooltip.visible = false


func _on_farm_plot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_inventory) and _inventory.craft_farm_plot():
			set_open(false)
		get_viewport().set_input_as_handled()


func _create_axe_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "AxeCostTooltip"
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 10
	_tooltip.custom_minimum_size = Vector2(190.0, 110.0)
	_tooltip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_tooltip)
	_tooltip_label = Label.new()
	_tooltip_label.name = "CostDetails"
	_tooltip_label.add_theme_font_size_override("font_size", 15)
	_tooltip_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.add_child(_tooltip_label)


func _on_campfire_mouse_entered() -> void:
	_campfire_hovered = true
	_refresh_tooltip()
	_tooltip.visible = true


func _on_campfire_mouse_exited() -> void:
	_campfire_hovered = false
	_tooltip.visible = false


func _on_campfire_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_inventory) and _inventory.craft_campfire():
			_refresh_tooltip()
		get_viewport().set_input_as_handled()


func _on_pickaxe_mouse_entered() -> void:
	_pickaxe_hovered = true
	_refresh_tooltip()
	_tooltip.visible = true


func _on_pickaxe_mouse_exited() -> void:
	_pickaxe_hovered = false
	_tooltip.visible = false


func _on_pickaxe_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_inventory) and _inventory.craft_pickaxe():
			_refresh_tooltip()
		get_viewport().set_input_as_handled()


func _on_axe_mouse_entered() -> void:
	_axe_hovered = true
	_refresh_tooltip()
	_tooltip.visible = true


func _on_axe_mouse_exited() -> void:
	_axe_hovered = false
	_tooltip.visible = false


func _on_axe_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_inventory) and _inventory.craft_axe():
			_refresh_tooltip()
		get_viewport().set_input_as_handled()


func _refresh_tooltip() -> void:
	if not is_instance_valid(_inventory):
		return
	var wood_count: int = _inventory.get_total_wood()
	var fiber_count: int = _inventory.get_total_fiber()
	var stone_count: int = _inventory.get_total_stone()
	if _farm_plot_hovered:
		_tooltip_label.text = "Farm Plot cost\nWood: %d / 1\nFiber: %d / 1\nClick to place" % [wood_count, fiber_count]
	elif _campfire_hovered:
		_tooltip_label.text = "Campfire cost\nWood: %d / 1\nFiber: %d / 1\nStone: %d / 1\nClick to craft" % [wood_count, fiber_count, stone_count]
	elif _tent_hovered:
		_tooltip_label.text = "Tent\nNot craftable yet"
	elif _pickaxe_hovered:
		_tooltip_label.text = "Pickaxe cost\nWood: %d / 1\nStone: %d / 1\nClick to craft" % [wood_count, stone_count]
	else:
		_tooltip_label.text = "Axe cost\nWood: %d / 1\nFiber: %d / 1\nClick to craft" % [wood_count, fiber_count]


func _process(_delta: float) -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	_axe_hovered = is_open() and axe_slot.get_global_rect().has_point(mouse_position)
	_pickaxe_hovered = is_open() and pickaxe_slot.get_global_rect().has_point(mouse_position)
	_campfire_hovered = is_open() and campfire_slot.get_global_rect().has_point(mouse_position)
	_tent_hovered = is_open() and tent_slot.get_global_rect().has_point(mouse_position)
	_farm_plot_hovered = is_open() and is_instance_valid(_farm_plot_slot) and _farm_plot_slot.get_global_rect().has_point(mouse_position)
	if (_axe_hovered or _pickaxe_hovered or _campfire_hovered or _tent_hovered or _farm_plot_hovered) and is_instance_valid(_inventory):
		_refresh_tooltip()
		var active_slot: Panel = _farm_plot_slot if _farm_plot_hovered else campfire_slot if _campfire_hovered else tent_slot if _tent_hovered else pickaxe_slot if _pickaxe_hovered else axe_slot
		_tooltip.position = active_slot.get_global_rect().position - Vector2(202.0, 0.0)
		_tooltip.visible = true
	else:
		_tooltip.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		set_open(not is_open())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and is_open():
		set_open(false)
		get_viewport().set_input_as_handled()
		return
