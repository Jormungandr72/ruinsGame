extends Control

"""
Controls the load menu.
Shows placeholder save slots and allows returning to the main menu.
"""

const MAIN_MENU_PATH = "res://scenes/menus/main_menu.tscn"


func _ready():
	"""
	Runs when the load menu scene is loaded.
	Connects save slot and back button signals.
	"""
	$VBoxContainer/SaveSlotOneButton.pressed.connect(onSaveSlotOnePressed)
	$VBoxContainer/SaveSlotTwoButton.pressed.connect(onSaveSlotTwoPressed)
	$VBoxContainer/SaveSlotThreeButton.pressed.connect(onSaveSlotThreePressed)
	$VBoxContainer/BackButton.pressed.connect(onBackPressed)


func onSaveSlotOnePressed():
	"""
	Placeholder for loading save slot one.
	Currently does nothing.
	"""
	pass


func onSaveSlotTwoPressed():
	"""
	Placeholder for loading save slot two.
	Currently does nothing.
	"""
	pass


func onSaveSlotThreePressed():
	"""
	Placeholder for loading save slot three.
	Currently does nothing.
	"""
	pass


func onBackPressed():
	"""
	Returns the player to the main menu.
	"""
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
