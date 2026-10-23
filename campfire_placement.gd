class_name CampfirePlacement
extends Node3D

const CAMPFIRE_MESH: Mesh = preload("res://PUSHILIN_campfire.obj")
const MAX_PLACE_DISTANCE: float = 18.0
const MAX_PLAYER_DISTANCE: float = 12.0
const MAX_GROUND_HEIGHT_DELTA: float = 1.5
const MIN_GROUND_NORMAL_Y: float = 0.72
const CAMPFIRE_GROUND_OFFSET: float = 0.512

var _player: PlayerController
var _inventory: InventoryUI
var _preview: MeshInstance3D
var _placed_material: StandardMaterial3D
var _preview_material: StandardMaterial3D
var _placement_valid: bool = false
var _placement_position: Vector3 = Vector3.ZERO
var _campfire_surface_material: Material
var _hint: Label


func setup(player: PlayerController, inventory: InventoryUI) -> void:
	_player = player
	_inventory = inventory
	_preview = MeshInstance3D.new()
	_preview.name = "CampfirePreview"
	_preview.mesh = CAMPFIRE_MESH
	_campfire_surface_material = CAMPFIRE_MESH.surface_get_material(0) if CAMPFIRE_MESH.get_surface_count() > 0 else null
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_material = StandardMaterial3D.new()
	_preview_material.albedo_color = Color(0.35, 1.0, 0.42, 0.58)
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _campfire_surface_material is BaseMaterial3D:
		var preview_surface: BaseMaterial3D = (_campfire_surface_material as BaseMaterial3D).duplicate() as BaseMaterial3D
		preview_surface.albedo_color = Color(0.35, 1.0, 0.42, 0.58)
		preview_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		preview_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview.material_override = preview_surface
	else:
		_preview.material_override = _preview_material
	add_child(_preview)
	_preview.visible = false
	_placed_material = _campfire_surface_material
	var hint_layer: CanvasLayer = CanvasLayer.new()
	hint_layer.name = "PlacementHintLayer"
	add_child(hint_layer)
	_hint = Label.new()
	_hint.name = "PlacementHint"
	_hint.text = "Move mouse to position  |  Left click: place  |  Right click: cancel"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -260.0
	_hint.offset_top = -72.0
	_hint.offset_right = 260.0
	_hint.offset_bottom = -34.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	_hint.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 1.0))
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_layer.add_child(_hint)
	set_process(true)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_inventory):
		return
	var can_place: bool = _inventory.is_campfire_equipped() and not _inventory.is_open()
	_preview.visible = can_place
	_hint.visible = can_place
	if can_place:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_inventory) and _inventory.is_campfire_equipped() and not _inventory.is_open():
		_update_preview()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_inventory) or not _inventory.is_campfire_equipped() or _inventory.is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_inventory.cancel_campfire_equipped()
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _placement_valid:
				_place_campfire()
			get_viewport().set_input_as_handled()


func _update_preview() -> void:
	var camera: Camera3D = _player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_position)
	var direction: Vector3 = camera.project_ray_normal(mouse_position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * MAX_PLACE_DISTANCE)
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_placement_valid = false
	_set_preview_color(Color(1.0, 0.3, 0.25, 0.58))
	if hit.is_empty():
		return
	var surface_normal: Vector3 = hit["normal"] as Vector3
	var hit_position: Vector3 = hit["position"] as Vector3
	var horizontal_distance: float = Vector2(hit_position.x - _player.global_position.x, hit_position.z - _player.global_position.z).length()
	if surface_normal.dot(Vector3.UP) < MIN_GROUND_NORMAL_Y or horizontal_distance > MAX_PLAYER_DISTANCE or absf(hit_position.y - _player.global_position.y) > MAX_GROUND_HEIGHT_DELTA:
		return
	_placement_position = hit_position + Vector3.UP * CAMPFIRE_GROUND_OFFSET
	_placement_valid = true
	_preview.global_position = _placement_position
	_set_preview_color(Color(0.35, 1.0, 0.42, 0.58))


func _set_preview_color(color: Color) -> void:
	_preview_material.albedo_color = color
	if _preview.material_override is BaseMaterial3D:
		(_preview.material_override as BaseMaterial3D).albedo_color = color


func _place_campfire() -> void:
	var campfire: PlacedCampfire = PlacedCampfire.new()
	campfire.name = "PlacedCampfire"
	campfire.mesh = CAMPFIRE_MESH
	campfire.material_override = _placed_material
	campfire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	get_tree().current_scene.add_child(campfire)
	campfire.global_position = _placement_position
	_inventory.consume_equipped_campfire()
