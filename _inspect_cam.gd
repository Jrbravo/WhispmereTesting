extends Camera3D

func _ready() -> void:
	var t: Node3D = get_parent().get_node_or_null("Target")
	var point: Vector3 = t.global_position if t != null else Vector3(0, 3, 0)
	look_at(point, Vector3.UP)