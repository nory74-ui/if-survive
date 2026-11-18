extends Node
## マルチタイトル共通カタログ・シナリオ・アセット解決マネージャ（Autoload: GameManager）

const CATALOG_PATH := "res://episodes/catalog.json"

var catalog_data: Dictionary = {}
var current_episode: Dictionary = {}
var current_episode_id: String = ""
var current_scenario: Dictionary = {}


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	var parsed: Variant = _read_json_file(CATALOG_PATH)
	if parsed is Dictionary:
		catalog_data = parsed as Dictionary
	else:
		push_error("episodes/catalog.json の読み込みに失敗しました: " + CATALOG_PATH)


func get_episodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eps: Variant = catalog_data.get("episodes", [])
	if eps is Array:
		for item in eps:
			if item is Dictionary:
				out.append(item as Dictionary)
	return out


func get_episode_info(episode_id: String) -> Dictionary:
	for ep in get_episodes():
		if str(ep.get("id", "")) == episode_id:
			return ep
	return {}


func load_episode(episode_info: Dictionary) -> bool:
	var dir_path := str(episode_info.get("dir", ""))
	if dir_path.is_empty():
		return false
	var scenario_path := dir_path.path_join("scenario.json")
	var parsed: Variant = _read_json_file(scenario_path)
	if parsed is Dictionary and (parsed as Dictionary).has("scenes"):
		current_episode = episode_info.duplicate(true)
		current_episode_id = str(episode_info.get("id", ""))
		current_scenario = parsed as Dictionary
		return true
	push_warning("シナリオが見つからないか形式不正です: " + scenario_path)
	return false


func resolve_asset_path(raw_path: String, episode_dir: String = "") -> String:
	if raw_path.is_empty():
		return ""
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return raw_path
	var base_dir := episode_dir if not episode_dir.is_empty() else str(current_episode.get("dir", ""))
	if base_dir.is_empty():
		return "res://" + raw_path
	if raw_path.begins_with("assets/"):
		return base_dir.path_join(raw_path)
	return base_dir.path_join("assets").path_join(raw_path)


func resolve_audio_dir(subdir: String, episode_dir: String = "") -> String:
	var base_dir := episode_dir if not episode_dir.is_empty() else str(current_episode.get("dir", ""))
	if base_dir.is_empty():
		return "res://assets/%s/" % subdir
	return "%s/assets/%s/" % [base_dir, subdir]


func load_texture_safe(full_path: String) -> Texture2D:
	if full_path.is_empty():
		return null
	if ResourceLoader.exists(full_path):
		var res := ResourceLoader.load(full_path)
		if res is Texture2D:
			return res as Texture2D
	if FileAccess.file_exists(full_path):
		var abs_path := ProjectSettings.globalize_path(full_path)
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON解析エラー (%s 行 %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
