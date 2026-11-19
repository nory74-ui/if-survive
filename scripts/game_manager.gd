extends Node
## マルチタイトル共通カタログ・シナリオ・アセット解決・フラグ・終幕管理マネージャ（Autoload: GameManager）

const CATALOG_PATH := "res://episodes/catalog.json"
const SAVE_PATH := "user://if_survive_save.json"

var catalog_data: Dictionary = {}
var current_episode: Dictionary = {}
var current_episode_id: String = ""
var current_scenario: Dictionary = {}
var unlocked_endings: Dictionary = {}
var session_flags: Dictionary = {} # 1周プレイ中の伏線フラグ管理


func _ready() -> void:
	load_catalog()
	load_save_data()


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
	reset_flags()
	var scenario_path := dir_path.path_join("scenario.json")
	var parsed: Variant = _read_json_file(scenario_path)
	if parsed is Dictionary and (parsed as Dictionary).has("scenes"):
		current_episode = episode_info.duplicate(true)
		current_episode_id = str(episode_info.get("id", ""))
		current_scenario = parsed as Dictionary
		return true
	push_warning("シナリオが見つからないか形式不正です: " + scenario_path)
	return false


# --- 伏線フラグ管理 ---

func reset_flags() -> void:
	session_flags.clear()


func set_flag(flag_name: String, value: bool = true) -> void:
	if not flag_name.is_empty():
		session_flags[flag_name] = value


func has_flag(flag_name: String) -> bool:
	return bool(session_flags.get(flag_name, false))


func has_all_flags(flag_list: Array) -> bool:
	for f in flag_list:
		if not has_flag(str(f)):
			return false
	return true


func export_flags() -> Dictionary:
	return session_flags.duplicate(true)


func import_flags(flags_dict: Variant) -> void:
	session_flags.clear()
	if flags_dict is Dictionary:
		for k in (flags_dict as Dictionary).keys():
			var key_str := str(k)
			if not key_str.is_empty():
				session_flags[key_str] = bool((flags_dict as Dictionary)[k])


# --- アセット解決・読み込み ---

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
		var bytes := FileAccess.get_file_as_bytes(full_path)
		if not bytes.is_empty():
			var img := Image.new()
			var low := full_path.to_lower()
			if low.ends_with(".webp") and img.load_webp_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
			if (low.ends_with(".jpg") or low.ends_with(".jpeg")) and img.load_jpg_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
			if img.load_png_from_buffer(bytes) == OK:
				return ImageTexture.create_from_image(img)
		if OS.get_name() != "Web":
			var abs_path := ProjectSettings.globalize_path(full_path)
			var img_disk := Image.load_from_file(abs_path)
			if img_disk != null and not img_disk.is_empty():
				return ImageTexture.create_from_image(img_disk)
	return null


# --- エンディング達成記録・総数取得 ---

func get_total_endings(episode_id: String = "") -> int:
	var target_id := episode_id if not episode_id.is_empty() else current_episode_id
	if not target_id.is_empty():
		var info := get_episode_info(target_id)
		if info.has("total_endings"):
			return int(info["total_endings"])
	if target_id == current_episode_id or target_id.is_empty():
		var meta: Variant = current_scenario.get("meta", {})
		if meta is Dictionary and (meta as Dictionary).has("totalEndings"):
			return int((meta as Dictionary)["totalEndings"])
	return 5


func unlock_ending(episode_id: String, ending_id: String) -> void:
	if episode_id.is_empty() or ending_id.is_empty():
		return
	if not unlocked_endings.has(episode_id) or not (unlocked_endings[episode_id] is Array):
		unlocked_endings[episode_id] = []
	var list: Array = unlocked_endings[episode_id]
	if not list.has(ending_id):
		list.append(ending_id)
		save_data()


func get_unlocked_count(episode_id: String) -> int:
	if unlocked_endings.has(episode_id) and unlocked_endings[episode_id] is Array:
		return (unlocked_endings[episode_id] as Array).size()
	return 0


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(unlocked_endings, "\t"))


func load_save_data() -> void:
	var parsed: Variant = _read_json_file(SAVE_PATH)
	if parsed is Dictionary:
		unlocked_endings = parsed as Dictionary


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
