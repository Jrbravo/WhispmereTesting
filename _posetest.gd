extends Node3D

var sk: Skeleton3D
var b: int
var n: int = 0
var D: Basis


var b2: int
var b3: int
var d2: Basis
var d3: Basis


func _ready() -> void:
	var k: Node = load("res://knight.glb").instantiate()
	add_child(k)
	sk = _find_sk(k)

	# method 1: pose = GR^-1 * D
	b = sk.find_bone("DEF-upper_arm.L")
	var gr1: Basis = sk.get_bone_global_rest(b).basis
	D = Basis(Vector3.UP, deg_to_rad(45)) * gr1
	sk.set_bone_pose_rotation(b, Quaternion(gr1.inverse() * D))

	# method 2: pose = D * GR^-1
	b2 = sk.find_bone("DEF-upper_arm.R")
	var gr2: Basis = sk.get_bone_global_rest(b2).basis
	d2 = Basis(Vector3.UP, deg_to_rad(45)) * gr2
	sk.set_bone_pose_rotation(b2, Quaternion(d2 * gr2.inverse()))

	# method 3: global pose override
	b3 = sk.find_bone("DEF-shin.L")
	var gr3: Basis = sk.get_bone_global_rest(b3).basis
	d3 = Basis(Vector3.UP, deg_to_rad(45)) * gr3
	sk.set_bone_global_pose_override(b3, Transform3D(d3, sk.get_bone_global_rest(b3).origin), 1.0, true)

	print("m1 D.y=", D.y)
	print("m2 D.y=", d2.y)
	print("m3 D.y=", d3.y)


func _process(_delta: float) -> void:
	if n >= 2 and n < 4:
		print("m1 pose-> global.y=", sk.get_bone_global_pose(b).basis.y, " match=", sk.get_bone_global_pose(b).basis.y.is_equal_approx(D.y))
		print("m2 pose-> global.y=", sk.get_bone_global_pose(b2).basis.y, " match=", sk.get_bone_global_pose(b2).basis.y.is_equal_approx(d2.y))
		print("m3 override-> global.y=", sk.get_bone_global_pose(b3).basis.y, " match=", sk.get_bone_global_pose(b3).basis.y.is_equal_approx(d3.y))
	n += 1


func _find_sk(n2: Node) -> Skeleton3D:
	if n2 is Skeleton3D:
		return n2
	for c in n2.get_children():
		var r: Skeleton3D = _find_sk(c)
		if r != null:
			return r
	return null