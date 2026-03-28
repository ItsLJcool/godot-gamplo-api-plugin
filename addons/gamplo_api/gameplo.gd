extends Node

signal on_login
signal on_gameplo_ready

signal on_achivement_unlock(item:GameploAchievement)

class GameploAchievement:
	var id:int = -1
	var key:String = ""
	
	var title:String = "Default Title"
	var desc:String = "This is a Default description to an invalid Achivement!"
	
	var icon_url:String = ""
	
	var points:int = 0
	
	var is_hidden:bool = false
	var unlocked:bool = false
	
	var unlocked_at:Variant = null
	## Returns the time as in milliseconds from the unlock time ISO 8601 format
	func get_unlock_time() -> int:
		if unlocked_at == null: return 0
		return Time.get_unix_time_from_datetime_string(unlocked_at)
	
	func _init(id:int, key:String, title:String, desc:String, icon:String):
		self.id = id
		self.key = key
		self.title = title
		self.desc = desc
		self.icon = icon

var game_achievements:Array[GameploAchievement]

var _login_http := HTTPRequest.new()
var _achievement_http := HTTPRequest.new()

const ACHIEVEMNT_URL := "https://gamplo.com/api/sdk/achievements"
const GAMEPLO_AUTH_URL := "https://gamplo.com/api/sdk/auth"
const GAMEPLO_API_BASE := "https://gamplo.com/api"

var is_offline:bool = true

var session_id:String = ""

var username:String = "guest"
var display_name:String = "Guest"
var player_id:String = ""
var icon_url:String = ""

var _pushed_token_warnings:bool = false

func get_token() -> String:
		if not OS.has_feature("web"):
			if not _pushed_token_warnings:
				_pushed_token_warnings = true
				push_warning("User is not on a Web browser, returning into offline mode")
			is_offline = true
			return ""
		
		# This gets the token if the user is playing on gamplo and has the token in cookies
		# thank you AwsmeAnthony for providing this from their Gameplo API implementation
		var token:Variant = JavaScriptBridge.eval( "new URLSearchParams(window.location.search).get('gamplo_token')" )
		
		if token == null:
			if not _pushed_token_warnings: 
				_pushed_token_warnings = true
				push_warning("Failed to get gamplo token, assuming user is offline")
			is_offline = true
			return ""
		
		is_offline = false
		return str(token)

func _on_login_request(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray):
	if response_code != 200:
		push_error("Gamplo request failed: %s" % response_code)
		return
		
	var parsed:Dictionary = JSON.parse_string(body.get_string_from_utf8())
	
	if parsed == null:
		push_warning("Login Request has no valid body or Invalid JSON Response")
		return
	
	session_id = parsed.get("sessionId", "")
	if parsed.has("player"):
		var player := parsed.get("player")
		username = player.get("username", "guest")
		display_name = player.get("displayName", "Guest")
		player_id = player.get("id", "")
		icon_url = player.get("image", "")
	
	print("parsed: ", parsed)
	print("Successfully Authed %s!\nSession ID: %s" % [display_name, session_id])
	on_login.emit()

func _on_achivements_request(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray):
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	
	if response_code != 200:
		push_error("HTTP %s: %s" % [response_code, text])
		return
		
	if parsed == null:
		push_warning("Invalid JSON Response")
		return
	
	if parsed.has("achievement"):
		var parsed_data = parsed.get("achievement")
		if not parsed_data.get("alreadyUnlocked", false):
			var filtered := game_achievements.filter(func(data): return data.key == parsed_data.get("key", "") )
			if not filtered.is_empty():
				var achievement:GameploAchievement = filtered.pop_back()
				achievement.unlocked = true
				achievement.unlocked_at = Time.get_datetime_string_from_system()
				on_achivement_unlock.emit(achievement)
	
	if parsed.has("achievements"):
		game_achievements = []
		for data in parsed.get("achievements"):
			print("data: ", data)
			var achievement:GameploAchievement = GameploAchievement.new(
				data.get("id", -1), data.get("key"), data.get("title"), data.get("description"), data.get("icon")
			)
			achievement.points = data.get("points", 0)
			achievement.is_hidden = data.get("hidden", false)
			achievement.unlocked = data.get("unlocked", false)
			achievement.unlocked_at = data.get("unlockedAt", null)
			game_achievements.push_back(achievement)
	
	on_gameplo_ready.emit()

func _init():
	_login_http.request_completed.connect(_on_login_request)
	add_child(_login_http)
	
	_achievement_http.request_completed.connect(_on_achivements_request)
	add_child(_achievement_http)
	

func _ready():
	if not OS.has_feature("web"):
		on_gameplo_ready.emit()
		return
	# Initalize all the dev or token shit
	get_token()
	
	_auth_gameplo()
	on_login.connect(_cache_achivements)

func _auth_gameplo():
	if is_offline:
		print("Is offline, skipping authing")
		return
	
	_login_http.request(
		GAMEPLO_AUTH_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({"token": get_token()})
	)

func _cache_achivements():
	if is_offline: return
	
	var err = _achievement_http.request(
		ACHIEVEMNT_URL,
		["x-sdk-session: %s" % session_id],
		HTTPClient.METHOD_GET
	)
	
	if err != OK: push_error("Could not request achievements: %s" % err)

func unlock_achivement(key:String) -> bool:
	var err = _achievement_http.request(
		ACHIEVEMNT_URL + "/unlock",
		[ "Content-Type: application/json", "x-sdk-session: %s" % session_id ],
		HTTPClient.METHOD_POST,
		JSON.stringify({"key": key})
	)

	return err == OK
