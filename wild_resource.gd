class_name WildResource
extends Node3D

## Generic gatherable for the collectible-only foraging resources
## (wild berries, mushrooms, herbs). It mirrors the existing FiberBush pickup
## conventions: join the "interactable" group plus a per-category pickup group,
## show one prompt when the player is near and facing it, gather with E, and
## remove the node. Collected amounts go to the shared InventoryUI.
##
## These resources are collectibles only: they have no crafting, cooking,
## status or relationship effects yet.

@export var category: String = "berry"          ## berry | mushroom | herb
@export var item_name: String = "Wild Berries"  ## Inventory item awarded
@export var amount: int = 1
@export var interaction_distance: float = 4.5
@export var prompt_text: String = "Wild Berries"
@export var prompt_color: Color = Color(0.94, 0.45, 0.5, 1.0)

@onready var prompt_label: Label = $PromptLayer/PromptLabel

var _player: Node3D
var _inventory: InventoryUI


func _enter_tree() -> void:
	add_to_group("interactable")
	add_to_group(pickup_group())


## The group SaveManager uses to persist gathered/remaining nodes for this type.
func pickup_group() -> String:
	return category + "_pickups"


func _ready() -> void:
	prompt_label.visible = false
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	prompt_label.offset_top = 26.0
	prompt_label.offset_bottom = 76.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.add_theme_color_override("font_color", prompt_color)
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 1.0))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player") as Node3D
		_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI


func _process(_delta: float) -> void:
	if SaveManager.is_restoring():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			_player = current_scene.get_node_or_null("Player") as Node3D
			_inventory = current_scene.get_node_or_null("InventoryUI") as InventoryUI
	if not is_instance_valid(_player):
		prompt_label.visible = false
		return
	var player_ground_position: Vector3 = Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var in_range: bool = global_position.distance_to(player_ground_position) <= interaction_distance and InteractionArbiter.is_selected(self)
	prompt_label.visible = in_range
	if not in_range:
		return
	prompt_label.text = "%s (+%d)\nPress E to gather" % [prompt_text, amount]
	if Input.is_action_just_pressed("pickup") and is_instance_valid(_inventory) and not _inventory.is_open():
		if _grant(_inventory, amount) == amount:
			queue_free()


func _grant(inventory: InventoryUI, count: int) -> int:
	match category:
		"berry": return inventory.add_berry(count)
		"mushroom": return inventory.add_mushroom(count)
		"herb": return inventory.add_herb(count)
	return 0


## Used by the Chef NPC: removes this gatherable from the world and returns the
## items it yields, keyed by inventory item name. The node is freed, so the
## passing save records it as already gathered, exactly like player gathering.
func collect_for_npc() -> Dictionary:
	var reward: Dictionary = {item_name: amount}
	queue_free()
	return reward


func interaction_point() -> Vector3:
	return global_position


func interaction_radius() -> float:
	return interaction_distance


func is_interaction_actionable() -> bool:
	return true


func is_interaction_available() -> bool:
	return is_instance_valid(_inventory)