extends Node

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1
const ITEM_NAMES: Array[String] = ["Wood", "Fiber", "Raw Meat", "Cooked Meat", "Axe", "Pickaxe", "Campfire", "Stone"]
## Foraging items added after the first release. They are OPTIONAL: older saves
## omit them, so validation accepts a save that lacks them and treats the count
## as zero. New saves always include them.
const OPTIONAL_ITEM_NAMES: Array[String] = ["Wild Berries", "Wild Mushrooms", "Wild Herbs", "Beef", "Animal Hide", "Animal Bone", "Herb-Roasted Beef", "Berry-Glazed Beef", "Mushroom-Roasted Chicken", "Herb & Mushroom Chicken"]
const ALL_ITEM_NAMES: Array[String] = ["Wood", "Fiber", "Raw Meat", "Cooked Meat", "Axe", "Pickaxe", "Campfire", "Stone", "Wild Berries", "Wild Mushrooms", "Wild Herbs", "Beef", "Animal Hide", "Animal Bone", "Herb-Roasted Beef", "Berry-Glazed Beef", "Mushroom-Roasted Chicken", "Herb & Mushroom Chicken"]
## Resource pickup categories. "berry", "mushroom" and "herb" are the optional
## foraging categories; older saves simply do not list them.
const BASE_RESOURCE_CATEGORIES: Array[String] = ["wood", "fiber", "stone", "chicken"]
const OPTIONAL_RESOURCE_CATEGORIES: Array[String] = ["berry", "mushroom", "herb"]
const OPTIONAL_PERSISTENT_ACTOR_CATEGORIES: Array[String] = ["cow"]

var _status: String = ""
var _busy: bool = false
var _restoring: bool = false
var _initialized: bool = false
var _status_dialog: AcceptDialog

## True once the startup load-or-create step has finished. The tutorial waits
## for this so it can tell a brand-new game from a loaded save.
func is_initialized() -> bool:
	return _initialized

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize_save")

func _initialize_save() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	const FRESH_START_MARKER: String = "user://fresh_start_initialized.flag"
	if not FileAccess.file_exists(FRESH_START_MARKER):
		_start_fresh_save()
		var marker: FileAccess = FileAccess.open(FRESH_START_MARKER, FileAccess.WRITE)
		if marker != null:
			marker.store_string("initialized")
			marker.close()
	elif FileAccess.file_exists(SAVE_PATH):
		await load_game()
	else:
		_start_fresh_save()
	_initialized = true

func _start_fresh_save() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var data: Dictionary = _capture_state(scene)
	if data.is_empty() or not validate_save(data):
		_status = "Fresh save not created: initial game state could not be captured."
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_status = "Fresh save not created: save file cannot be opened."
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	_status = "Started a new save."

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Removes the save slot (save, backup, and temp files). Leaves the current
## in-memory game untouched; use start_new_game() to also reset the world.
func delete_save() -> bool:
	var removed: bool = false
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK:
				removed = true
	_status = "Save deleted." if removed else "No save to delete."
	return removed

## Wipes the save slot and reloads the scene into a pristine state, then writes
## a fresh save. The tutorial restarts because its persisted stage resets to 0.
func start_new_game() -> void:
	if _busy or _restoring:
		return
	delete_save()
	get_tree().change_scene_to_file("res://Main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	save_game()
	_status = "New game started."

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("save_game"):
		var save_succeeded: bool = save_game()
		show_status(save_succeeded)
	if Input.is_action_just_pressed("load_game"):
		var load_succeeded: bool = await load_game()
		show_status(load_succeeded)
	if Input.is_action_just_pressed("ui_accept") and is_instance_valid(_status_dialog):
		_on_status_dialog_closed()

func show_status(success: bool) -> void:
	if is_instance_valid(_status_dialog):
		_status_dialog.dialog_text = _status if _status != "" else ("Game saved." if success else "Save/load failed.")
		_status_dialog.popup_centered()
		return
	_status_dialog = AcceptDialog.new()
	_status_dialog.title = "Save / Load"
	_status_dialog.dialog_text = _status if _status != "" else ("Game saved." if success else "Save/load failed.")
	get_tree().root.add_child(_status_dialog)
	_status_dialog.confirmed.connect(_on_status_dialog_closed)
	_status_dialog.canceled.connect(_on_status_dialog_closed)
	_status_dialog.popup_centered()

func _on_status_dialog_closed() -> void:
	if is_instance_valid(_status_dialog):
		_status_dialog.queue_free()
	_status_dialog = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func get_relationship_state() -> Dictionary:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error == OK and parser.data is Dictionary and validate_save(parser.data as Dictionary):
		return (parser.data as Dictionary)["relationships"]
	return {}

func is_restoring() -> bool:
	return _restoring

func get_status() -> String:
	return _status

func save_game() -> bool:
	if _busy or _restoring:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null:
		_status = "Save failed: no active scene."
		return false
	var data: Dictionary = _capture_state(scene)
	if data.is_empty() or not validate_save(data):
		var reason: String = "capture was incomplete" if data.is_empty() else _validation_failure(data)
		_status = "Save failed: %s." % reason
		return false
	var temp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_status = "Save failed: cannot open save file (%s)." % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var file_error: Error = file.get_error()
	file.close()
	if file_error != OK:
		_status = "Save failed while writing (%s)." % error_string(file_error)
		return false
	if FileAccess.file_exists(SAVE_PATH):
		var backup_path: String = SAVE_PATH + ".bak"
		if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
		var backup_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(backup_path))
		if backup_error != OK:
			_status = "Save failed preserving previous save (%s)." % error_string(backup_error)
			return false
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(SAVE_PATH))
	if rename_error != OK:
		var backup: String = SAVE_PATH + ".bak"
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(SAVE_PATH))
		_status = "Save failed replacing the previous save (%s)." % error_string(rename_error)
		return false
	var old_backup: String = SAVE_PATH + ".bak"
	if FileAccess.file_exists(old_backup): DirAccess.remove_absolute(ProjectSettings.globalize_path(old_backup))
	_status = "Game saved."
	return true

func load_game() -> bool:
	if _busy:
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		_status = "No save file found."
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_status = "Load failed: save file cannot be opened."
		return false
	var parser: JSON = JSON.new()
	var raw_text: String = file.get_as_text()
	var parse_error: Error = parser.parse(raw_text)
	file.close()
	if parse_error != OK:
		_status = "Load rejected: invalid JSON at line %d; current game was not changed." % parser.get_error_line()
		return false
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not validate_save(parsed as Dictionary):
		_status = "Load rejected: save is damaged, incomplete, unsupported, or invalid; current game was not changed. (%s)" % _validation_failure(parsed as Dictionary)
		return false
	var scene: Node = get_tree().current_scene
	if scene == null:
		_status = "Load failed: no active scene."
		return false
	if not _preflight_restore(scene, parsed as Dictionary):
		_status = _preflight_failure(scene, parsed as Dictionary)
		return false
	_busy = true
	_restoring = true
	_ensure_dialogue(scene, false)
	_ensure_dialogue(scene, true)
	await _apply_state(scene, parsed as Dictionary)
	_restoring = false
	_busy = false
	_status = "Game loaded."
	return true

func _preflight_failure(scene: Node, data: Dictionary) -> String:
	var world: Dictionary = data["world"]
	var resource_data: Dictionary = world["resources"]
	for category: String in BASE_RESOURCE_CATEGORIES + OPTIONAL_RESOURCE_CATEGORIES:
		if not resource_data.has(category):
			continue
		for absolute_path: String in resource_data[category]:
			var relative_path: String = absolute_path.trim_prefix("/root/" + String(scene.name) + "/")
			if scene.get_node_or_null(NodePath(relative_path)) == null:
				return "Load rejected: missing %s resource node %s." % [category, relative_path]
	for identifier: String in world["harvested_trees"]:
		if scene.get_node_or_null(NodePath("Nature/" + identifier)) == null:
			return "Load rejected: missing tree identifier %s." % identifier
	for identifier: String in world["harvested_stones"]:
		var separator: int = identifier.rfind("/")
		var host_path: String = identifier.substr(0, separator).trim_prefix("/root/" + String(scene.name) + "/")
		var rock_name: String = identifier.substr(separator + 1)
		var host: StoneVein = scene.get_node_or_null(NodePath(host_path)) as StoneVein
		if host == null or host.get_node_or_null(rock_name) == null:
			return "Load rejected: missing rock node %s/%s." % [host_path, rock_name]
	var actor_states: Dictionary = world.get("persistent_actors", {})
	for actor_path_value: Variant in actor_states.keys():
		var actor_path: String = String(actor_path_value)
		if scene.get_node_or_null(NodePath(actor_path)) == null:
			return "Load rejected: missing persistent actor %s." % actor_path
	return "Load rejected: unknown world node mismatch."

func _preflight_restore(scene: Node, data: Dictionary) -> bool:
	var world: Dictionary = data["world"]
	var resource_data: Dictionary = world["resources"]
	for category: String in BASE_RESOURCE_CATEGORIES + OPTIONAL_RESOURCE_CATEGORIES:
		if not resource_data.has(category):
			continue
		for absolute_path: String in resource_data[category]:
			var relative_path: String = absolute_path.trim_prefix("/root/" + String(scene.name) + "/")
			if scene.get_node_or_null(NodePath(relative_path)) == null:
				return false
	for plot_data: Dictionary in world.get("farm_plots", []):
		if not _valid_farm_plots([plot_data]):
			return false
	for identifier: String in world["harvested_trees"]:
		var tree: Node = scene.get_node_or_null(NodePath("Nature/" + identifier))
		if tree == null:
			return false
	for identifier: String in world["harvested_stones"]:
		var separator: int = identifier.rfind("/")
		if separator <= 0 or not identifier.begins_with("/root/" + String(scene.name) + "/"):
			return false
		var host_path: String = identifier.substr(0, separator).trim_prefix("/root/" + String(scene.name) + "/")
		var rock_name: String = identifier.substr(separator + 1)
		var host: StoneVein = scene.get_node_or_null(NodePath(host_path)) as StoneVein
		if host == null or host.get_node_or_null(rock_name) == null:
			return false
	var actor_states: Dictionary = world.get("persistent_actors", {})
	for actor_path_value: Variant in actor_states.keys():
		var actor_path: String = String(actor_path_value)
		if actor_path.is_empty() or actor_path.contains("..") or actor_path.begins_with("/"):
			return false
		var actor: Node = scene.get_node_or_null(NodePath(actor_path))
		if actor == null or not actor.is_in_group("persistent_cows"):
			return false
		var state_value: Variant = actor_states[actor_path_value]
		if not state_value is Dictionary or not (state_value as Dictionary).get("harvested") is bool:
			return false
		if not String(actor_path_value).begins_with("Props/"):
			return false
	return true

func _capture_harvested_stone_ids() -> Array[String]:
	var ids: Array[String] = []
	for host_node: Node in get_tree().get_nodes_in_group("stone_deposits"):
		var host: StoneVein = host_node as StoneVein
		if is_instance_valid(host):
			for identifier: String in host.get_harvested_ids():
				ids.append("/root/" + String(get_tree().current_scene.name) + "/" + String(get_tree().current_scene.get_path_to(host)) + "/" + identifier)
	return ids

func _find_relationship_dialogue(is_stoney: bool) -> NPCDialogue:
	return _find_dialogue_by_name("NPCDialogue_Stoney" if is_stoney else "NPCDialogue")

func _ensure_dialogue(scene: Node, is_stoney: bool) -> NPCDialogue:
	var dialogue_name: String = "NPCDialogue_Stoney" if is_stoney else "NPCDialogue"
	var dialogue: NPCDialogue = scene.get_node_or_null(dialogue_name) as NPCDialogue
	if not is_instance_valid(dialogue):
		for candidate: Node in get_tree().get_nodes_in_group("npc_dialogue"):
			var possible: NPCDialogue = candidate as NPCDialogue
			if is_instance_valid(possible) and possible.is_configured_for_stoney() == is_stoney and scene.is_ancestor_of(possible):
				dialogue = possible
				break
	if not is_instance_valid(dialogue):
		dialogue = NPCDialogue.new()
		dialogue.name = dialogue_name
		dialogue.configure_for_stoney(is_stoney)
		scene.add_child(dialogue)
	else:
		dialogue.name = dialogue_name
		if not dialogue.has_completed_friendship() and not dialogue.has_pending_thank_you():
			dialogue.configure_for_stoney(is_stoney)
	return dialogue

func _find_dialogue_by_name(dialogue_name: String) -> NPCDialogue:
	for candidate: Node in get_tree().get_nodes_in_group("npc_dialogue"):
		if String(candidate.name) == dialogue_name:
			return candidate as NPCDialogue
	return null

func _find_dialogue() -> NPCDialogue:
	for candidate: Node in get_tree().get_nodes_in_group("npc_dialogue"):
		if is_instance_valid(candidate):
			return candidate as NPCDialogue
	return null

func _capture_state(scene: Node) -> Dictionary:
	var woodsman_dialogue: NPCDialogue = _ensure_dialogue(scene, false)
	var stoney_dialogue: NPCDialogue = _ensure_dialogue(scene, true)
	if woodsman_dialogue == null or stoney_dialogue == null:
		return {}
	var player: PlayerController = scene.get_node_or_null("Player") as PlayerController
	var inventory: InventoryUI = scene.get_node_or_null("InventoryUI") as InventoryUI
	var chef: ChefNPC = scene.get_node_or_null("Props/Chef") as ChefNPC
	var woodsman_npc: IdleNPC = scene.get_node_or_null("Props/NPC") as IdleNPC
	var stoney_npc: IdleNPC = scene.get_node_or_null("Props/StoneMinerNPC") as IdleNPC
	if player == null or inventory == null or woodsman_dialogue == null or stoney_dialogue == null or chef == null or woodsman_npc == null or stoney_npc == null:
		return {}
	var woodsman_state: Dictionary = woodsman_dialogue.get_own_save_state()
	var stoney_state: Dictionary = stoney_dialogue.get_own_save_state()
	var stacks: Dictionary = {}
	for item: String in ALL_ITEM_NAMES:
		var values: Array[int] = []
		for slot: int in range(InventoryUI.SLOT_COUNT):
			values.append(inventory.get_slot_item_count(slot, item))
		stacks[item] = values
	var resources: Dictionary = {}
	for category: String in BASE_RESOURCE_CATEGORIES + OPTIONAL_RESOURCE_CATEGORIES:
		var ids: Array[String] = []
		for node: Node in get_tree().get_nodes_in_group(_group_for(category)):
			if is_instance_valid(node) and scene.is_ancestor_of(node):
				ids.append("/root/" + String(scene.name) + "/" + String(scene.get_path_to(node)))
		resources[category] = ids
	var persistent_actors: Dictionary = {}
	for actor_node: Node in get_tree().get_nodes_in_group("persistent_cows"):
		if is_instance_valid(actor_node) and scene.is_ancestor_of(actor_node) and actor_node.has_method("is_harvested"):
			persistent_actors[String(scene.get_path_to(actor_node))] = {"harvested": bool(actor_node.call("is_harvested"))}
	var tree_host: TreeResource = scene.get_node_or_null("Nature") as TreeResource
	var harvested_trees: Array[String] = tree_host.get_harvested_ids() if is_instance_valid(tree_host) else []
	var harvested_stones: Array[String] = _capture_harvested_stone_ids()
	var chest: ChestInventoryMenu = get_tree().get_first_node_in_group("chest_storage") as ChestInventoryMenu
	if not is_instance_valid(chest):
		chest = ChestInventoryMenu.get_or_create(scene)
	var fires: Array[Dictionary] = []
	var farm_plots: Array[Dictionary] = []
	for plot_node: Node in get_tree().get_nodes_in_group("farm_plots"):
		var plot: FarmPlot = plot_node as FarmPlot
		if is_instance_valid(plot) and scene.is_ancestor_of(plot):
			farm_plots.append(plot.get_save_state())
	for fire_node: Node in get_tree().get_nodes_in_group("placed_campfires"):
		var fire: PlacedCampfire = fire_node as PlacedCampfire
		if is_instance_valid(fire):
			fires.append({"position": _vector_to_array(fire.global_position), "state": fire.get_save_state()})
	for menu_node: Node in get_tree().get_nodes_in_group("campfire_menu"):
		if not is_instance_valid(menu_node):
			continue
		var menu: CampfireMenu = menu_node as CampfireMenu
		var has_owner: bool = false
		for fire_node: Node in get_tree().get_nodes_in_group("placed_campfires"):
			if is_instance_valid(fire_node) and fire_node.get_node_or_null("CampfireMenu") == menu:
				has_owner = true
				break
		if not has_owner and (menu.get_save_state()["raw"] > 0 or menu.get_save_state()["cooked"] > 0):
			fires.append({"position": _vector_to_array(menu.get_campfire_position()), "state": menu.get_save_state()})
	var tutorial_node: Node = scene.get_node_or_null("TutorialUI")
	var tutorial_state: Dictionary = {}
	if tutorial_node != null and tutorial_node.has_method("get_save_state"):
		tutorial_state = tutorial_node.call("get_save_state") as Dictionary
	var result: Dictionary = {
		"version": SAVE_VERSION,
		"player": {"position": _vector_to_array(player.global_position)},
		"inventory": {"stacks": stacks, "axe": inventory.is_axe_equipped(), "pickaxe": inventory.is_pickaxe_equipped(), "campfire": inventory.is_campfire_equipped()},
		"relationships": {"woodsman_thanked": woodsman_state["thanked"], "woodsman_friend": woodsman_state["friend"], "woodsman_working": woodsman_npc.is_working(), "stoney_thanked": stoney_state["thanked"], "stoney_friend": stoney_state["friend"], "stoney_working": stoney_npc.is_working(), "chef_thanked": chef.get_save_state()["thanked"], "chef_friend": chef.get_save_state()["friend"]},
		"chef": {"position": _vector_to_array(chef.global_position)},
		"world": {"resources": resources, "harvested_trees": harvested_trees, "harvested_stones": harvested_stones, "chest": chest.get_save_state() if is_instance_valid(chest) else _empty_chest(), "campfires": fires, "farm_plots": farm_plots, "persistent_actors": persistent_actors}
	}
	if not tutorial_state.is_empty():
		result["tutorial"] = tutorial_state
	return result

func _validation_failure(data: Dictionary) -> String:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return "save version invalid"
	var inventory: Dictionary = data.get("inventory", {})
	var stacks: Dictionary = inventory.get("stacks", {})
	for item: String in ITEM_NAMES:
		var item_error: String = _validate_stack(stacks, item)
		if not item_error.is_empty():
			return item_error
	for item: String in OPTIONAL_ITEM_NAMES:
		if not stacks.has(item):
			continue
		var optional_error: String = _validate_stack(stacks, item)
		if not optional_error.is_empty():
			return optional_error
	var world: Dictionary = data.get("world", {})
	var resources: Dictionary = world.get("resources", {})
	for category: String in BASE_RESOURCE_CATEGORIES:
		var entries: Array = resources.get(category, [])
		for value: Variant in entries:
			if not value is String or not _valid_path(value):
				return "resource identifier invalid: %s" % String(value)
	for category: String in OPTIONAL_RESOURCE_CATEGORIES:
		if not resources.has(category):
			continue
		var optional_entries: Array = resources.get(category, [])
		for value: Variant in optional_entries:
			if not value is String or not _valid_path(value):
				return "resource identifier invalid: %s" % String(value)
	if not _valid_chest(world.get("chest")):
		return "chest state invalid"
	return "one or more required fields or values are invalid"


func _validate_stack(stacks: Dictionary, item: String) -> String:
	if not stacks.has(item):
		return "missing inventory stack %s" % item
	if not stacks[item] is Array or stacks[item].size() != InventoryUI.SLOT_COUNT:
		return "wrong inventory slot count for %s" % item
	for value: Variant in stacks[item]:
		if (not value is int and not value is float) or not is_equal_approx(float(value), roundf(float(value))) or int(value) < 0 or int(value) > 99:
			return "invalid stack count for %s: %s (%s)" % [item, str(value), type_string(typeof(value))]
	return ""

func validate_save(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return false
	if not data.get("player") is Dictionary or not data.get("inventory") is Dictionary or not data.get("relationships") is Dictionary or not data.get("world") is Dictionary:
		return false
	var player: Dictionary = data["player"]
	if not _valid_vector(player.get("position")):
		return false
	var saved_chef: Variant = data.get("chef")
	if saved_chef is Dictionary and not _valid_vector((saved_chef as Dictionary).get("position")):
		return false
	var inventory: Dictionary = data["inventory"]
	if not inventory.get("stacks") is Dictionary:
		return false
	var stacks: Dictionary = inventory["stacks"]
	for item: String in ITEM_NAMES:
		if not stacks.has(item) or not stacks[item] is Array or stacks[item].size() != InventoryUI.SLOT_COUNT:
			return false
		for count: Variant in stacks[item]:
			if (not count is int and not count is float) or not is_equal_approx(float(count), roundf(float(count))) or int(count) < 0 or int(count) > 99:
				return false
	for item: String in OPTIONAL_ITEM_NAMES:
		if not stacks.has(item):
			continue
		if not stacks[item] is Array or stacks[item].size() != InventoryUI.SLOT_COUNT:
			return false
		for count: Variant in stacks[item]:
			if (not count is int and not count is float) or not is_equal_approx(float(count), roundf(float(count))) or int(count) < 0 or int(count) > 99:
				return false
	for flag: String in ["axe", "pickaxe", "campfire"]:
		if not inventory.get(flag) is bool:
			return false
	var relationships: Dictionary = data["relationships"]
	for key: String in ["woodsman_thanked", "woodsman_friend", "stoney_thanked", "stoney_friend", "chef_thanked", "chef_friend"]:
		if not relationships.get(key) is bool:
			return false
	for key: String in ["woodsman_working", "stoney_working"]:
		if relationships.has(key) and not relationships[key] is bool:
			return false
	if data.has("tutorial"):
		var tutorial: Variant = data["tutorial"]
		if not tutorial is Dictionary:
			return false
		var tutorial_dict: Dictionary = tutorial
		var stage_value: Variant = tutorial_dict.get("stage", 0)
		if (not stage_value is int and not stage_value is float) or int(stage_value) < 0 or int(stage_value) > 5:
			return false
		for flag: String in ["completed", "gather_wood", "gather_stone", "gather_meat", "craft_axe", "craft_pickaxe", "craft_campfire", "cooked"]:
			if tutorial_dict.has(flag) and not tutorial_dict[flag] is bool:
				return false
	var world: Dictionary = data["world"]
	if not world.get("resources") is Dictionary or not _valid_chest(world.get("chest")) or not world.get("campfires") is Array or not world.get("harvested_trees") is Array or not world.get("harvested_stones") is Array:
		return false
	if world.has("farm_plots") and not _valid_farm_plots(world["farm_plots"]):
		return false
	var resources: Dictionary = world["resources"]
	for category: String in BASE_RESOURCE_CATEGORIES:
		if not resources.get(category) is Array:
			return false
		for path: Variant in resources[category]:
			if not path is String or not _valid_path(path):
				return false
	for category: String in OPTIONAL_RESOURCE_CATEGORIES:
		if not resources.has(category):
			continue
		if not resources.get(category) is Array:
			return false
		for path: Variant in resources[category]:
			if not path is String or not _valid_path(path):
				return false
	var persistent_actors_value: Variant = world.get("persistent_actors", {})
	if not persistent_actors_value is Dictionary:
		return false
	var persistent_actors: Dictionary = persistent_actors_value
	for actor_path_value: Variant in persistent_actors.keys():
		if not actor_path_value is String or String(actor_path_value).is_empty() or String(actor_path_value).contains("..") or String(actor_path_value).begins_with("/"):
			return false
		var actor_state_value: Variant = persistent_actors[actor_path_value]
		if not actor_state_value is Dictionary or not (actor_state_value as Dictionary).get("harvested") is bool:
			return false
		if not String(actor_path_value).begins_with("Props/"):
			return false
	for path: Variant in world["harvested_trees"]:
		if not path is String or path.is_empty() or path.contains("..") or path.begins_with("/"):
			return false
	for path: Variant in world["harvested_stones"]:
		if not path is String or not _valid_path(path):
			return false
	for fire: Variant in world["campfires"]:
		if not fire is Dictionary or not _valid_vector(fire.get("position")) or not fire.get("state") is Dictionary:
			return false
		var state: Dictionary = fire["state"]
		if (not state.get("raw") is int and not state.get("raw") is float) or not is_equal_approx(float(state["raw"]), roundf(float(state["raw"]))) or int(state["raw"]) < 0 or int(state["raw"]) > 99:
			return false
		if (not state.get("cooked") is int and not state.get("cooked") is float) or not is_equal_approx(float(state["cooked"]), roundf(float(state["cooked"]))) or int(state["cooked"]) < 0 or int(state["cooked"]) > 99:
			return false
		if not state.get("remaining") is float and not state.get("remaining") is int:
			return false
		if float(state["remaining"]) < 0.0 or float(state["remaining"]) > 15.0:
			return false
		# Recipe cooking fields are optional so saves written before recipes existed
		# still validate.
		if state.has("recipe") and not _valid_recipe_state(state):
			return false
	return true

func _valid_farm_plots(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is Dictionary:
			return false
		var plot: Dictionary = entry as Dictionary
		if not _valid_vector(plot.get("position")):
			return false
		var stage: Variant = plot.get("stage")
		if not stage is String or not [FarmPlot.STAGE_EMPTY, FarmPlot.STAGE_WATERING, FarmPlot.STAGE_GROWING, FarmPlot.STAGE_READY].has(String(stage)):
			return false
		var remaining: Variant = plot.get("remaining")
		if (not remaining is int and not remaining is float) or float(remaining) < 0.0 or float(remaining) > FarmPlot.GROWTH_SECONDS:
			return false
		if String(stage) == FarmPlot.STAGE_WATERING and float(remaining) > FarmPlot.WATERING_SECONDS:
			return false
	return true


func _valid_recipe_state(state: Dictionary) -> bool:
	var recipe: Variant = state.get("recipe", "")
	if not recipe is String or String(recipe).length() > 64:
		return false
	if state.has("recipe_remaining"):
		var remaining: Variant = state["recipe_remaining"]
		if (not remaining is int and not remaining is float) or float(remaining) < 0.0 or float(remaining) > CampfireMenu.RECIPE_COOK_TIME_SECONDS:
			return false
	# "ready" holds finished dishes and "stock" holds ingredients the Chef left;
	# both are item-name -> count maps.
	for key: String in ["ready", "stock"]:
		if state.has(key) and not _valid_item_counts(state[key]):
			return false
	return true

func _valid_item_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for item_value: Variant in (value as Dictionary).keys():
		var item_name: String = String(item_value)
		var count: Variant = (value as Dictionary)[item_value]
		if not ALL_ITEM_NAMES.has(item_name):
			return false
		if (not count is int and not count is float) or not is_equal_approx(float(count), roundf(float(count))) or int(count) < 0 or int(count) > 99:
			return false
	return true

func _valid_chest(value: Variant) -> bool:
	if not value is Array or value.size() != ChestInventoryMenu.SLOT_COUNT:
		return false
	for slot: Variant in value:
		if not slot is Dictionary or not slot.get("item") is String:
			return false
		var raw_count: Variant = slot.get("count")
		if (not raw_count is int and not raw_count is float) or not is_equal_approx(float(raw_count), roundf(float(raw_count))):
			return false
		var item: String = slot["item"]
		var count: int = int(slot["count"])
		if count < 0 or count > 99 or (item.is_empty() != (count == 0)) or (not item.is_empty() and not ALL_ITEM_NAMES.has(item)):
			return false
	return true

func _valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if not component is float and not component is int:
			return false
	return true

func _valid_path(value: String) -> bool:
	return value.begins_with("/root/") and not value.contains("..")

func _apply_state(scene: Node, data: Dictionary) -> void:
	_ensure_dialogue(scene, false)
	_ensure_dialogue(scene, true)
	await get_tree().process_frame
	var world: Dictionary = data["world"]
	var resources: Dictionary = world["resources"]
	for category: String in BASE_RESOURCE_CATEGORIES + OPTIONAL_RESOURCE_CATEGORIES:
		if not resources.has(category):
			continue
		var keep: Array[String] = []
		for path: String in resources[category]:
			var existing: Node = get_tree().root.get_node_or_null(NodePath(path.trim_prefix("/root/")))
			if existing == null:
				continue
			keep.append(path)
		for node: Node in get_tree().get_nodes_in_group(_group_for(category)):
			if is_instance_valid(node) and scene.is_ancestor_of(node) and not keep.has("/root/" + String(scene.name) + "/" + String(scene.get_path_to(node))):
				node.remove_from_group(_group_for(category))
				node.queue_free()
	var tree_host: TreeResource = scene.get_node_or_null("Nature") as TreeResource
	if is_instance_valid(tree_host):
		tree_host.restore_harvested_ids(world["harvested_trees"])
	else:
		for host_node: Node in get_tree().get_nodes_in_group("tree_resources"):
			var alternate_tree_host: TreeResource = host_node as TreeResource
			if is_instance_valid(alternate_tree_host) and scene.is_ancestor_of(alternate_tree_host):
				alternate_tree_host.restore_harvested_ids(world["harvested_trees"])
				break
	for identifier: String in world["harvested_stones"]:
		var separator: int = identifier.rfind("/")
		var host_path: String = identifier.substr(0, separator)
		var rock_name: String = identifier.substr(separator + 1)
		var host: StoneVein = scene.get_node_or_null(NodePath(host_path.trim_prefix("/root/" + String(scene.name) + "/"))) as StoneVein
		if is_instance_valid(host):
			host.restore_harvested_ids([rock_name])
	var saved_actors: Dictionary = world.get("persistent_actors", {})
	for actor_node: Node in get_tree().get_nodes_in_group("persistent_cows"):
		if is_instance_valid(actor_node) and scene.is_ancestor_of(actor_node):
			actor_node.call("set_harvested", false)
	for actor_path_value: Variant in saved_actors.keys():
		var actor: Node = scene.get_node_or_null(NodePath(String(actor_path_value)))
		if is_instance_valid(actor) and actor.has_method("set_harvested"):
			var actor_state: Dictionary = saved_actors[actor_path_value]
			actor.call("set_harvested", bool(actor_state.get("harvested", false)))
	var restored_player: PlayerController = scene.get_node("Player") as PlayerController
	restored_player.end_farm_watering()
	for plot_node: Node in get_tree().get_nodes_in_group("farm_plots"):
		if is_instance_valid(plot_node) and scene.is_ancestor_of(plot_node):
			plot_node.queue_free()
	for plot_data: Dictionary in world.get("farm_plots", []):
		var plot: FarmPlot = FarmPlot.new()
		plot.name = "FarmPlot"
		var plot_position: Array = plot_data.get("position", [0.0, 0.0, 0.0])
		plot._saved_world_position = Vector3(float(plot_position[0]), float(plot_position[1]), float(plot_position[2]))
		scene.add_child(plot)
		plot.set_save_state.call_deferred(plot_data)
	var chest: ChestInventoryMenu = ChestInventoryMenu.get_or_create(scene)
	if not chest.is_node_ready(): await chest.ready
	chest.set_save_state(world["chest"])
	for fire_node: Node in get_tree().get_nodes_in_group("placed_campfires"):
		if is_instance_valid(fire_node): fire_node.queue_free()
	for menu_node: Node in get_tree().get_nodes_in_group("campfire_menu"):
		if is_instance_valid(menu_node): menu_node.queue_free()
	for fire_data: Dictionary in world["campfires"]:
		var fire: PlacedCampfire = PlacedCampfire.new()
		fire.name = "PlacedCampfire"
		fire.mesh = load("res://PUSHILIN_campfire.obj") as Mesh
		scene.add_child(fire)
		fire.global_position = _array_to_vector(fire_data["position"])
		fire.set_save_state.call_deferred(fire_data["state"])
	var inventory_data: Dictionary = data["inventory"]
	var inventory: InventoryUI = scene.get_node("InventoryUI") as InventoryUI
	inventory.set_save_state(inventory_data)
	var player: PlayerController = scene.get_node("Player") as PlayerController
	player.global_position = _array_to_vector(data["player"]["position"])
	player.velocity = Vector3.ZERO
	var chef: ChefNPC = scene.get_node("Props/Chef") as ChefNPC
	if data.get("chef") is Dictionary:
		chef.global_position = _array_to_vector(data["chef"]["position"])
	chef.velocity = Vector3.ZERO
	var woodsman_dialogue: NPCDialogue = _ensure_dialogue(scene, false)
	var stoney_dialogue: NPCDialogue = _ensure_dialogue(scene, true)
	woodsman_dialogue.configure_for_stoney(false)
	woodsman_dialogue.set_save_state(data["relationships"])
	stoney_dialogue.configure_for_stoney(true)
	stoney_dialogue.set_save_state(data["relationships"])
	_remove_duplicate_dialogues(scene, woodsman_dialogue, stoney_dialogue)
	chef.set_save_state(data["relationships"])
	var relationships: Dictionary = data["relationships"]
	var woodsman_npc: IdleNPC = scene.get_node_or_null("Props/NPC") as IdleNPC
	var stoney_npc: IdleNPC = scene.get_node_or_null("Props/StoneMinerNPC") as IdleNPC
	if is_instance_valid(woodsman_npc):
		woodsman_npc.set_job_state(bool(relationships.get("woodsman_working", false)))
	if is_instance_valid(stoney_npc):
		stoney_npc.set_job_state(bool(relationships.get("stoney_working", false)))
	var tutorial_node: Node = scene.get_node_or_null("TutorialUI")
	if tutorial_node != null and tutorial_node.has_method("set_save_state"):
		if data.has("tutorial"):
			tutorial_node.call("set_save_state", data["tutorial"])
		else:
			# A save made before the tutorial existed must not replay the intro.
			tutorial_node.call("set_save_state", {"stage": 5, "completed": true})

func _remove_duplicate_dialogues(scene: Node, woodsman: NPCDialogue, stoney: NPCDialogue) -> void:
	for candidate: Node in get_tree().get_nodes_in_group("npc_dialogue"):
		if not is_instance_valid(candidate) or not scene.is_ancestor_of(candidate):
			continue
		if candidate != woodsman and candidate != stoney:
			candidate.queue_free()

func _group_for(category: String) -> String:
	match category:
		"wood": return "wood_pickups"
		"fiber": return "fiber_pickups"
		"stone": return "stone_pickups"
		"chicken": return "chickens"
		"berry": return "berry_pickups"
		"mushroom": return "mushroom_pickups"
		"herb": return "herb_pickups"
	return ""

func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _array_to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _empty_chest() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(ChestInventoryMenu.SLOT_COUNT): result.append({"item": "", "count": 0})
	return result
