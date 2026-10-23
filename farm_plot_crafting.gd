class_name FarmPlotCrafting
extends Node

const PLOT_COST: Dictionary = {"Fiber": 1, "Wood": 1}

var _inventory: InventoryUI
var _placement: FarmPlotPlacement


func setup(inventory: InventoryUI, placement: FarmPlotPlacement) -> void:
	_inventory = inventory
	_placement = placement


func can_craft() -> bool:
	return is_instance_valid(_inventory) and _inventory.can_consume_items(PLOT_COST)


func craft() -> bool:
	if not can_craft() or not is_instance_valid(_placement):
		return false
	_placement.begin_placement()
	return true
