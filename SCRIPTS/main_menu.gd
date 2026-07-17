extends Control

"""
Controls the main menu buttons.
Handles starting the game, opening menus, and quitting the game.
"""

const GAME_SCENE_PATH = "res://SCENES/GAME/game_scene.tscn"
const LOAD_MENU_PATH = "res://SCENES/MENUS/load_menu.tscn"


func _ready():
	"""
	Runs when the main menu scene is loaded.
	Connects all button pressed signals to their functions.
	"""
	$VBoxContainer/NewGameButton.pressed.connect(onNewGamePressed)
	$VBoxContainer/ContinueButton.pressed.connect(onContinuePressed)
	$VBoxContainer/LoadButton.pressed.connect(onLoadPressed)
	$VBoxContainer/SettingsButton.pressed.connect(onSettingsPressed)
	$VBoxContainer/QuitButton.pressed.connect(onQuitPressed)
	# Each button within the box container when pressed will load it's relevant scene

func onNewGamePressed():
	"""
	Currently just loads the main testing scene.
	"""
	
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func onContinuePressed():
	"""
	Placeholder for continuing the latest save.
	Currently does nothing.
	"""
	pass


func onLoadPressed():
	"""
	Opens the load menu scene.
	"""
	get_tree().change_scene_to_file(LOAD_MENU_PATH)


func onSettingsPressed():
	"""
	Placeholder for opening settings.
	Currently does nothing. Woooo
	"""
	pass


func onQuitPressed():
	"""
	Quits the application.
	"""
	get_tree().quit()
