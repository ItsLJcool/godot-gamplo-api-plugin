@tool
extends EditorPlugin

const gameplo_autoload_path:String = "res://addons/gamplo_api/gameplo.gd"
const gameplo_autoload_name:StringName = &"Gameplo"

func _enable_plugin() -> void:
	add_autoload_singleton(gameplo_autoload_name, gameplo_autoload_path)
	

func _disable_plugin() -> void:
	remove_autoload_singleton(gameplo_autoload_name)


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
