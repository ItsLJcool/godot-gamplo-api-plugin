extends Node2D

@onready var debug_text:RichTextLabel = $Control/RichTextLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_debug_text()
	Gameplo.on_gameplo_ready.connect(update_debug_text)
	Gameplo.on_achivement_unlock.connect(update_debug_text)
	await get_tree().create_timer(5).timeout
	for data in Gameplo.game_achievements:
		Gameplo.unlock_achivement(data.key)

func update_debug_text():
	debug_text.text = "Is Offline: %s
Username: %s
Display Name: %s
Player ID: %s
Session ID: %s

Achivements:" % [
		Gameplo.is_offline, Gameplo.username, Gameplo.display_name, Gameplo.player_id, Gameplo.session_id
	]
	
	for data:Gameplo.GameploAchievement in Gameplo.game_achievements:
		debug_text.text += "
\nID: %s
Key: %s
Title: %s
Description: %s
Points: %s
Hidden: %s
Unlocked: %s" % [
			data.id, data.key, data.title, data.desc, data.points, data.is_hidden, data.unlocked
		]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
