extends Node

## Central interaction arbiter.
##
## Many world objects react to the "pickup" action (gather wood/stone/fiber,
## pick up a chicken, chop a tree, mine a deposit, open the chest, talk to an
## NPC, use a campfire). Previously each of them showed its own prompt and acted
## independently, so standing between two things showed overlapping prompts and
## one press collected both.
##
## Every interactable joins the "interactable" group and exposes:
##   interaction_point() -> Vector3   world position of the thing you'd interact with
##   interaction_radius() -> float    how close the player must be
##   is_interaction_actionable() -> bool  whether pressing E would do something now
##   is_interaction_available() -> bool   (optional) false hides it entirely
##
## Each frame this picks the single best candidate: the nearest one roughly in
## front of the player's view, preferring actionable ones over informational
## ones. Interactables then only show their prompt / accept E when
## InteractionArbiter.is_selected(self) is true.

const FORWARD_MIN_DOT: float = 0.25

var _selected: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_selected = _choose()


func get_selected() -> Node:
	return _selected


func is_selected(node: Node) -> bool:
	return _selected != null and _selected == node


func _choose() -> Node:
	if SaveManager.is_restoring() or _blocking_ui_open():
		return null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var player: Node3D = scene.get_node_or_null("Player") as Node3D
	if player == null:
		return null
	var forward: Vector3 = _forward(player)
	var best: Node = null
	var best_priority: int = 2
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node) or not node.has_method("interaction_point"):
			continue
		if node.has_method("is_interaction_available") and not bool(node.call("is_interaction_available")):
			continue
		var point: Vector3 = node.call("interaction_point") as Vector3
		var to: Vector3 = point - player.global_position
		var flat: Vector3 = Vector3(to.x, 0.0, to.z)
		var distance: float = flat.length()
		var radius: float = float(node.call("interaction_radius"))
		if distance > radius:
			continue
		var direction: Vector3 = flat / distance if distance > 0.001 else forward
		if forward.dot(direction) < FORWARD_MIN_DOT:
			continue
		var priority: int = 0 if (node.has_method("is_interaction_actionable") and bool(node.call("is_interaction_actionable"))) else 1
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			best_priority = priority
			best_distance = distance
			best = node
	return best


func _forward(player: Node3D) -> Vector3:
	var pivot: Node3D = player.get_node_or_null("CameraPivot") as Node3D
	if pivot != null:
		var direction: Vector3 = -pivot.global_transform.basis.z
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	return Vector3(0.0, 0.0, -1.0)


func _blocking_ui_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		if node is Control and (node as Control).is_visible_in_tree():
			return true
	return false