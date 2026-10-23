class_name TutorialUI
extends CanvasLayer

## Small, text-only introductory sequence for the Wispmere prototype.
##
## It never manipulates gameplay: it only reads existing state (inventory totals,
## placed campfires, campfire cooking, NPC dialogue) and reacts. Stages:
##   WELCOME -> GATHER -> CRAFT -> COOK -> MEET -> DONE
##
## Progress is persisted through the existing SaveManager (see get_save_state /
## set_save_state). The player keeps full control the whole time.

enum Stage { WELCOME, GATHER, CRAFT, COOK, MEET, DONE }

const BANNER_FONT: int = 64
const STAGE_FONT: int = 30
const FINAL_FONT: int = 40

var _stage: int = Stage.WELCOME
var _completed: bool = false
var _started: bool = false
var _intro_active: bool = false
var _seq: int = 0
var _active_tween: Tween

var _gather: Dictionary = {"wood": false, "stone": false, "meat": false}
var _craft: Dictionary = {"axe": false, "pickaxe": false, "campfire": false}
var _cooked: bool = false

var _banner_root: Control
var _banner: Label
var _hud_panel: PanelContainer
var _hud_label: Label


func _ready() -> void:
	layer = 3
	add_to_group("tutorial_ui")
	_build_banner()
	_build_hud()
	_activate.call_deferred()


func _build_banner() -> void:
	_banner_root = Control.new()
	_banner_root.name = "BannerRoot"
	_banner_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_root.visible = false
	add_child(_banner_root)
	var center: CenterContainer = CenterContainer.new()
	center.name = "BannerCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_root.add_child(center)
	_banner = Label.new()
	_banner.name = "BannerText"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(720.0, 0.0)
	_banner.add_theme_font_size_override("font_size", BANNER_FONT)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8, 1.0))
	_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_banner.add_theme_constant_override("shadow_offset_x", 3)
	_banner.add_theme_constant_override("shadow_offset_y", 4)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_banner)


func _build_hud() -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "ObjectivePanel"
	_hud_panel.anchor_left = 1.0
	_hud_panel.anchor_right = 1.0
	_hud_panel.anchor_top = 0.0
	_hud_panel.anchor_bottom = 0.0
	_hud_panel.offset_left = -300.0
	_hud_panel.offset_top = 18.0
	_hud_panel.offset_right = -18.0
	_hud_panel.offset_bottom = 150.0
	_hud_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.85)
	style.border_color = Color(0.62, 0.48, 0.31, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_hud_panel.add_theme_stylebox_override("panel", style)
	_hud_panel.visible = false
	add_child(_hud_panel)
	_hud_label = Label.new()
	_hud_label.name = "ObjectiveText"
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud_label.add_theme_font_size_override("font_size", 17)
	_hud_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_panel.add_child(_hud_label)


# --- Lifecycle -------------------------------------------------------------

func _activate() -> void:
	await _wait_for_save_manager()
	if _completed or _stage >= Stage.DONE:
		_completed = true
		_hide_all()
		return
	_started = true
	if _stage <= Stage.WELCOME:
		_stage = Stage.WELCOME
		_hide_hud()
		_banner.add_theme_font_size_override("font_size", BANNER_FONT)
		_banner.text = "Welcome to Wispmere"
		await _show_banner_sequence(0.7, 1.7)
		if _completed:
			return
		_enter_stage(Stage.GATHER)
	else:
		_show_hud(_stage)


func _wait_for_save_manager() -> void:
	var guard: int = 0
	while guard < 900 and not SaveManager.is_initialized():
		guard += 1
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if not _started or _completed or _intro_active:
		return
	match _stage:
		Stage.GATHER: _update_gather()
		Stage.CRAFT: _update_craft()
		Stage.COOK: _update_cook()
		Stage.MEET: _update_meet()


# --- Stage transitions -----------------------------------------------------

func _enter_stage(next: int) -> void:
	if _completed:
		return
	_stage = next
	_intro_active = true
	_hide_hud()
	_banner.add_theme_font_size_override("font_size", STAGE_FONT)
	_banner.text = _intro_text(next)
	await _show_banner_sequence(0.5, 2.0)
	_intro_active = false
	if _completed:
		return
	_show_hud(_stage)


func _finish() -> void:
	if _completed:
		return
	_completed = true
	_intro_active = true
	_hide_hud()
	_banner.add_theme_font_size_override("font_size", FINAL_FONT)
	_banner.text = "Every friendship starts somewhere.\nWispmere is yours to rebuild."
	await _show_banner_sequence(0.7, 2.6)
	_intro_active = false
	_hide_all()


func _show_banner_sequence(fade: float, hold: float) -> void:
	var my: int = _seq
	_banner_root.visible = true
	_banner_root.modulate.a = 0.0
	var tween: Tween = create_tween()
	_active_tween = tween
	tween.tween_property(_banner_root, "modulate:a", 1.0, fade)
	tween.tween_interval(hold)
	tween.tween_property(_banner_root, "modulate:a", 0.0, fade)
	await tween.finished
	if my != _seq:
		return
	if is_instance_valid(_banner_root):
		_banner_root.visible = false


func _cancel_sequence() -> void:
	_seq += 1
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


# --- Objective checks (read existing gameplay state) -----------------------

func _update_gather() -> void:
	var inv: InventoryUI = _inventory()
	if inv == null:
		return
	var changed: bool = false
	if not _gather["wood"] and _total(inv, "Wood") > 0:
		_gather["wood"] = true
		changed = true
	if not _gather["stone"] and _total(inv, "Stone") > 0:
		_gather["stone"] = true
		changed = true
	if not _gather["meat"] and _total(inv, "Raw Meat") > 0:
		_gather["meat"] = true
		changed = true
	if changed:
		_refresh_hud()
	if _gather["wood"] and _gather["stone"] and _gather["meat"]:
		_enter_stage(Stage.CRAFT)


func _update_craft() -> void:
	var inv: InventoryUI = _inventory()
	if inv == null:
		return
	var changed: bool = false
	if not _craft["axe"] and _total(inv, "Axe") > 0:
		_craft["axe"] = true
		changed = true
	if not _craft["pickaxe"] and _total(inv, "Pickaxe") > 0:
		_craft["pickaxe"] = true
		changed = true
	if not _craft["campfire"] and (_total(inv, "Campfire") > 0 or _has_placed_campfire()):
		_craft["campfire"] = true
		changed = true
	if changed:
		_refresh_hud()
	if _craft["axe"] and _craft["pickaxe"] and _craft["campfire"]:
		_enter_stage(Stage.COOK)


func _update_cook() -> void:
	if not _cooked:
		if _has_placed_campfire() and (_total(_inventory(), "Cooked Meat") > 0 or _any_campfire_cooked()):
			_cooked = true
			_refresh_hud()
	if _cooked:
		_enter_stage(Stage.MEET)


func _update_meet() -> void:
	for node: Node in get_tree().get_nodes_in_group("npc_dialogue"):
		var dialogue: NPCDialogue = node as NPCDialogue
		if is_instance_valid(dialogue) and dialogue.is_open():
			_finish()
			return


# --- Helpers ---------------------------------------------------------------

func _inventory() -> InventoryUI:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("InventoryUI") as InventoryUI


func _total(inv: InventoryUI, item: String) -> int:
	if inv == null:
		return 0
	var sum: int = 0
	for slot: int in range(InventoryUI.SLOT_COUNT):
		sum += inv.get_slot_item_count(slot, item)
	return sum


func _has_placed_campfire() -> bool:
	return not get_tree().get_nodes_in_group("placed_campfires").is_empty()


func _any_campfire_cooked() -> bool:
	for node: Node in get_tree().get_nodes_in_group("placed_campfires"):
		var fire: PlacedCampfire = node as PlacedCampfire
		if is_instance_valid(fire):
			if int(fire.get_save_state().get("cooked", 0)) > 0:
				return true
	return false


func _mark(done: bool) -> String:
	return "[x]" if done else "[ ]"


func _hud_text(stage: int) -> String:
	match stage:
		Stage.GATHER:
			return "Gather Supplies\n%s Wood\n%s Stone\n%s Raw Chicken" % [_mark(_gather["wood"]), _mark(_gather["stone"]), _mark(_gather["meat"])]
		Stage.CRAFT:
			return "Craft Your Tools\n%s Axe\n%s Pickaxe\n%s Campfire" % [_mark(_craft["axe"]), _mark(_craft["pickaxe"]), _mark(_craft["campfire"])]
		Stage.COOK:
			return "Cook Your First Meal\n%s Campfire placed\n%s Cooked chicken" % [_mark(_has_placed_campfire()), _mark(_cooked)]
		Stage.MEET:
			return "Meet Your Neighbors\n%s Talk to a local" % _mark(false)
	return ""


func _intro_text(stage: int) -> String:
	match stage:
		Stage.GATHER:
			return "Every new beginning starts with the basics.\nGather some wood, stone, and raw chicken meat."
		Stage.CRAFT:
			return "Resources are only the beginning.\nLet's put them to use."
		Stage.COOK:
			return "Raw food won't do you much good.\nBuild a campfire and cook some chicken."
		Stage.MEET:
			return "You're not the only one trying to make a life here.\nGo meet the locals - approach them and press E."
	return ""


func _refresh_hud() -> void:
	if _hud_panel.visible:
		_hud_label.text = _hud_text(_stage)


func _show_hud(stage: int) -> void:
	_hud_label.text = _hud_text(stage)
	_hud_panel.visible = true


func _hide_hud() -> void:
	_hud_panel.visible = false


func _hide_all() -> void:
	_hide_hud()
	if is_instance_valid(_banner_root):
		_banner_root.visible = false


# --- Persistence -----------------------------------------------------------

func get_save_state() -> Dictionary:
	return {
		"stage": _stage,
		"completed": _completed,
		"gather_wood": _gather["wood"],
		"gather_stone": _gather["stone"],
		"gather_meat": _gather["meat"],
		"craft_axe": _craft["axe"],
		"craft_pickaxe": _craft["pickaxe"],
		"craft_campfire": _craft["campfire"],
		"cooked": _cooked,
	}


func set_save_state(state: Dictionary) -> void:
	_completed = bool(state.get("completed", false))
	_stage = int(state.get("stage", Stage.WELCOME))
	_gather["wood"] = bool(state.get("gather_wood", false))
	_gather["stone"] = bool(state.get("gather_stone", false))
	_gather["meat"] = bool(state.get("gather_meat", false))
	_craft["axe"] = bool(state.get("craft_axe", false))
	_craft["pickaxe"] = bool(state.get("craft_pickaxe", false))
	_craft["campfire"] = bool(state.get("craft_campfire", false))
	_cooked = bool(state.get("cooked", false))
	if _completed or _stage >= Stage.DONE:
		_completed = true
		_stage = Stage.DONE
	if not _started:
		return
	_cancel_sequence()
	_intro_active = false
	_hide_all()
	if _completed:
		return
	if _stage <= Stage.WELCOME:
		_activate()
	else:
		_show_hud(_stage)


func is_completed() -> bool:
	return _completed