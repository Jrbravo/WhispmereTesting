extends Node3D

## Places a RoadIsland 09 prefab over each existing TownSquare*Path mesh.
## The source path mesh and transform are never modified.
const ROAD_ISLAND_09: PackedScene = preload("res://Prefabs/Environment/RoadIsland/EA03_Environment_RoadIsland_09_PRE.prefab.scn")
const PATH_MESH_SIZE: Vector3 = Vector3(4.0, 0.08, 40.0)
const ROAD_MESH_LENGTH: float = 18.74039
const ROAD_MESH_WIDTH: float = 3.947326
const SURFACE_LIFT: float = 0.035
const ROAD_MESH_CENTER_X: float = 0.27202
const ROAD_MESH_CENTER_Y: float = 0.277394
const ROAD_MESH_CENTER_Z: float = 0.450584

func _ready() -> void:
	call_deferred("_create_overlays")

func _create_overlays() -> void:
	var dressing: Node = get_parent()
	if dressing == null:
		return
	for child: Node in dressing.get_children():
		if not child is MeshInstance3D or not String(child.name).begins_with("TownSquare") or not String(child.name).contains("Path"):
			continue
		var source_path: MeshInstance3D = child as MeshInstance3D
		var road: Node3D = ROAD_ISLAND_09.instantiate() as Node3D
		if road == null:
			continue
		road.name = "Overlay_" + String(source_path.name)
		dressing.add_child(road)
		road.global_transform = _overlay_transform(source_path)

func _overlay_transform(source_path: MeshInstance3D) -> Transform3D:
	var source: Transform3D = source_path.global_transform
	var length_direction: Vector3 = (source.basis * Vector3.FORWARD).normalized()
	var width_direction: Vector3 = length_direction.cross(Vector3.UP).normalized()
	if width_direction.length_squared() < 0.5:
		width_direction = Vector3.RIGHT
	var vertical_direction: Vector3 = Vector3.UP
	var length_scale: float = PATH_MESH_SIZE.z / ROAD_MESH_LENGTH
	var width_scale: float = PATH_MESH_SIZE.x / ROAD_MESH_WIDTH
	var overlay_basis: Basis = Basis(
		length_direction * length_scale,
		vertical_direction,
		width_direction * width_scale
	)
	var source_surface_y: float = source.origin.y + PATH_MESH_SIZE.y * 0.5 + SURFACE_LIFT
	var surface_center_offset: Vector3 = overlay_basis * Vector3(ROAD_MESH_CENTER_X, ROAD_MESH_CENTER_Y, ROAD_MESH_CENTER_Z)
	var overlay_origin: Vector3 = Vector3(source.origin.x, source_surface_y, source.origin.z) - surface_center_offset
	return Transform3D(overlay_basis, overlay_origin)
