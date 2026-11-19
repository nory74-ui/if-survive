extends RefCounted
## 永続セーブデータ・既読管理・環境設定・マルチエピソード対応ストア

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 3
const DEFAULT_EPISODE_ID := "01_nobunaga"
const CHAPTER_ORDER: Array[String] = [
	"pro_01", "pro_02", "pro_03", "pro_04",
	"routeA_01", "routeA_02", "routeA_03", "routeA_04", "routeA_05",
	"end_01", "end_02", "end_05_true",
	"routeB_01", "routeB_02", "routeB_03", "routeB_04", "routeB_05",
	"end_03", "end_04",
]
const SLOT_IDS: Array[String] = ["quick", "1", "2", "3"]
const SLOT_LABELS := {
	"quick": "急速の栞（クイックセーブ）",
	"1": "記録帳・壱",
	"2": "記録帳・弐",
	"3": "記録帳・参",
}

const CHAR_INTERVALS: Array[float] = [0.052, 0.032, 0.014, 0.0]
const TEXT_SPEED_LABELS: Array[String] = ["遅い", "標準", "速い", "瞬間"]
const AUTO_MULTIPLIERS: Array[float] = [1.45, 1.0, 0.62]
const AUTO_SPEED_LABELS: Array[String] = ["遅め", "標準", "速め"]

var _active_episode_id: String = DEFAULT_EPISODE_ID
var _episodes_state: Dictionary = {} # episode_id -> { unlocked_endings, visited_scenes, visited_lines, slots }

var unlocked_endings: Array[String] = []
var visited_scenes: Dictionary = {} # scene_id -> true
var visited_lines: Dictionary = {}  # "scene_id:line_index" -> true
var slots: Dictionary = {}          # slot_id -> Dictionary
var settings: Dictionary = {}
var _dirty: bool = false


func _init() -> void:
	reset_settings_to_default(false)
	_load_active_bucket(_active_episode_id)


func reset_settings_to_default(mark_dirty: bool = true) -> void:
	settings = {
		"bgm_volume": 0.85,
		"se_volume": 0.90,
		"text_speed": 1,
		"auto_speed": 1,
		"skip_unread": false,
	}
	if mark_dirty:
		_dirty = true


func get_active_episode_id() -> String:
	return _active_episode_id


func set_active_episode(episode_id: String) -> void:
	var target := episode_id if not episode_id.is_empty() else DEFAULT_EPISODE_ID
	_sync_active_bucket()
	_active_episode_id = target
	_load_active_bucket(_active_episode_id)


func _ensure_bucket(episode_id: String) -> Dictionary:
	if not _episodes_state.has(episode_id) or not (_episodes_state[episode_id] is Dictionary):
		_episodes_state[episode_id] = {
			"unlocked_endings": [] as Array[String],
			"visited_scenes": {},
			"visited_lines": {},
			"slots": {},
		}
	return _episodes_state[episode_id] as Dictionary


func _sync_active_bucket() -> void:
	var bucket := _ensure_bucket(_active_episode_id)
	bucket["unlocked_endings"] = unlocked_endings.duplicate()
	bucket["visited_scenes"] = visited_scenes.duplicate(true)
	bucket["visited_lines"] = visited_lines.duplicate(true)
	bucket["slots"] = slots.duplicate(true)


func _load_active_bucket(episode_id: String) -> void:
	var bucket := _ensure_bucket(episode_id)
	unlocked_endings.clear()
	var arr: Variant = bucket.get("unlocked_endings", [])
	if arr is Array:
		for item in arr:
			var eid := str(item)
			if not eid.is_empty() and not unlocked_endings.has(eid):
				unlocked_endings.append(eid)

	var vs: Variant = bucket.get("visited_scenes", {})
	visited_scenes = (vs as Dictionary).duplicate(true) if vs is Dictionary else {}

	var vl: Variant = bucket.get("visited_lines", {})
	visited_lines = (vl as Dictionary).duplicate(true) if vl is Dictionary else {}

	var sl: Variant = bucket.get("slots", {})
	slots = (sl as Dictionary).duplicate(true) if sl is Dictionary else {}


func _parse_episode_bucket_from_dict(src: Dictionary) -> Dictionary:
	var out_endings: Array[String] = []
	var arr_end: Variant = src.get("unlocked_endings", [])
	if arr_end is Array:
		for item in arr_end:
			var eid := str(item)
			if not eid.is_empty() and not out_endings.has(eid):
				out_endings.append(eid)

	var out_scenes: Dictionary = {}
	var arr_sc: Variant = src.get("visited_scenes", [])
	if arr_sc is Array:
		for item in arr_sc:
			var sid := str(item)
			if not sid.is_empty():
				out_scenes[sid] = true

	var out_lines: Dictionary = {}
	var arr_ln: Variant = src.get("visited_lines", [])
	if arr_ln is Array:
		for item in arr_ln:
			var key := str(item)
			if not key.is_empty():
				out_lines[key] = true

	var out_slots: Dictionary = {}
	var saved_slots: Variant = src.get("slots", null)
	if saved_slots is Dictionary:
		for slot_id in SLOT_IDS:
			var s_val: Variant = (saved_slots as Dictionary).get(slot_id, null)
			if s_val is Dictionary and not (s_val as Dictionary).is_empty():
				out_slots[slot_id] = (s_val as Dictionary).duplicate(true)

	return {
		"unlocked_endings": out_endings,
		"visited_scenes": out_scenes,
		"visited_lines": out_lines,
		"slots": out_slots,
	}


func load_from_disk() -> void:
	_episodes_state.clear()
	unlocked_endings.clear()
	visited_scenes.clear()
	visited_lines.clear()
	slots.clear()
	reset_settings_to_default(false)
	_dirty = false

	if not FileAccess.file_exists(SAVE_PATH):
		_load_active_bucket(_active_episode_id)
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_load_active_bucket(_active_episode_id)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_load_active_bucket(_active_episode_id)
		return
	var data: Dictionary = parsed

	var cfg: Variant = data.get("settings", null)
	if cfg is Dictionary:
		var c: Dictionary = cfg
		settings["bgm_volume"] = clampf(float(c.get("bgm_volume", 0.85)), 0.0, 1.0)
		settings["se_volume"] = clampf(float(c.get("se_volume", 0.90)), 0.0, 1.0)
		settings["text_speed"] = clampi(int(c.get("text_speed", 1)), 0, CHAR_INTERVALS.size() - 1)
		settings["auto_speed"] = clampi(int(c.get("auto_speed", 1)), 0, AUTO_MULTIPLIERS.size() - 1)
		settings["skip_unread"] = bool(c.get("skip_unread", false))

	var eps: Variant = data.get("episodes", null)
	if eps is Dictionary:
		for ep_k in (eps as Dictionary).keys():
			var ep_id := str(ep_k)
			var val: Variant = (eps as Dictionary)[ep_k]
			if not ep_id.is_empty() and val is Dictionary:
				_episodes_state[ep_id] = _parse_episode_bucket_from_dict(val as Dictionary)
	else:
		# v1/v2 フラット形式の互換マイグレーション
		_episodes_state[DEFAULT_EPISODE_ID] = _parse_episode_bucket_from_dict(data)

	_load_active_bucket(_active_episode_id)


func save_to_disk() -> void:
	_sync_active_bucket()

	var eps_payload: Dictionary = {}
	for ep_k in _episodes_state.keys():
		var ep_id := str(ep_k)
		var bucket: Dictionary = _episodes_state[ep_id]
		var scene_keys: Array[String] = []
		var vs: Dictionary = bucket.get("visited_scenes", {})
		for k in vs.keys():
			scene_keys.append(str(k))
		scene_keys.sort()

		var line_keys: Array[String] = []
		var vl: Dictionary = bucket.get("visited_lines", {})
		for k in vl.keys():
			line_keys.append(str(k))
		line_keys.sort()

		eps_payload[ep_id] = {
			"unlocked_endings": bucket.get("unlocked_endings", []),
			"visited_scenes": scene_keys,
			"visited_lines": line_keys,
			"slots": bucket.get("slots", {}),
		}

	var payload := {
		"version": SAVE_VERSION,
		"settings": settings,
		"episodes": eps_payload,
		"updated_at": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		_dirty = false


func flush_if_dirty() -> void:
	if _dirty:
		save_to_disk()


func unlock_ending(ending_id: String) -> bool:
	if ending_id.is_empty():
		return false
	var added := false
	if not unlocked_endings.has(ending_id):
		unlocked_endings.append(ending_id)
		added = true
	save_to_disk()
	return added


func get_episode_unlocked_endings(episode_id: String) -> Array[String]:
	if episode_id == _active_episode_id:
		return unlocked_endings.duplicate()
	var bucket: Variant = _episodes_state.get(episode_id, null)
	var res: Array[String] = []
	if bucket is Dictionary:
		var arr: Variant = (bucket as Dictionary).get("unlocked_endings", [])
		if arr is Array:
			for item in arr:
				res.append(str(item))
	return res


func get_episode_visited_count(episode_id: String) -> int:
	if episode_id == _active_episode_id:
		return visited_scenes.size()
	var bucket: Variant = _episodes_state.get(episode_id, null)
	if bucket is Dictionary:
		var vs: Variant = (bucket as Dictionary).get("visited_scenes", {})
		if vs is Dictionary:
			return (vs as Dictionary).size()
	return 0


func has_episode_any_save(episode_id: String) -> bool:
	if episode_id == _active_episode_id:
		return has_any_save()
	var bucket: Variant = _episodes_state.get(episode_id, null)
	if bucket is Dictionary:
		var sl: Variant = (bucket as Dictionary).get("slots", {})
		if sl is Dictionary:
			for sid in SLOT_IDS:
				var item: Variant = (sl as Dictionary).get(sid, null)
				if item is Dictionary and not (item as Dictionary).is_empty():
					return true
	return false


func get_total_unlocked_endings() -> int:
	_sync_active_bucket()
	var total := 0
	for ep_k in _episodes_state.keys():
		var bucket: Variant = _episodes_state[ep_k]
		if bucket is Dictionary:
			var arr: Variant = (bucket as Dictionary).get("unlocked_endings", [])
			if arr is Array:
				total += (arr as Array).size()
	return total


func mark_scene_visited(scene_id: String) -> void:
	if scene_id.is_empty():
		return
	if not visited_scenes.has(scene_id):
		visited_scenes[scene_id] = true
		_dirty = true


func is_scene_visited(scene_id: String) -> bool:
	return visited_scenes.has(scene_id)


static func make_line_key(scene_id: String, line_idx: int) -> String:
	return "%s:%d" % [scene_id, line_idx]


func mark_line_read(scene_id: String, line_idx: int) -> void:
	if scene_id.is_empty() or line_idx < 0:
		return
	var key := make_line_key(scene_id, line_idx)
	if not visited_lines.has(key):
		visited_lines[key] = true
		_dirty = true


func is_line_read(scene_id: String, line_idx: int) -> bool:
	return visited_lines.has(make_line_key(scene_id, line_idx))


func write_slot(slot_id: String, entry: Dictionary) -> void:
	if not SLOT_IDS.has(slot_id):
		return
	var copy := entry.duplicate(true)
	if not copy.has("saved_unix"):
		copy["saved_unix"] = Time.get_unix_time_from_system()
	if not copy.has("saved_at"):
		copy["saved_at"] = Time.get_datetime_string_from_system(false, true)
	slots[slot_id] = copy
	save_to_disk()


func delete_slot(slot_id: String) -> void:
	if slots.has(slot_id):
		slots.erase(slot_id)
		save_to_disk()


func get_slot(slot_id: String) -> Dictionary:
	var val: Variant = slots.get(slot_id, null)
	if val is Dictionary:
		return val as Dictionary
	return {}


func has_slot(slot_id: String) -> bool:
	return slots.has(slot_id) and not (slots[slot_id] as Dictionary).is_empty()


func has_any_save() -> bool:
	for sid in SLOT_IDS:
		if has_slot(sid):
			return true
	return false


func get_latest_save() -> Dictionary:
	var best_id := ""
	var best_unix := -1.0
	var best_at := ""
	for sid in SLOT_IDS:
		var data := get_slot(sid)
		if data.is_empty():
			continue
		var ux := float(data.get("saved_unix", 0.0))
		var at := str(data.get("saved_at", ""))
		if best_id.is_empty() or ux > best_unix or (is_equal_approx(ux, best_unix) and at > best_at):
			best_id = sid
			best_unix = ux
			best_at = at
	if best_id.is_empty():
		return {}
	return {
		"slot_id": best_id,
		"data": get_slot(best_id),
	}


func get_char_interval() -> float:
	var idx := clampi(int(settings.get("text_speed", 1)), 0, CHAR_INTERVALS.size() - 1)
	return CHAR_INTERVALS[idx]


func get_auto_wait_sec(char_count: int) -> float:
	var idx := clampi(int(settings.get("auto_speed", 1)), 0, AUTO_MULTIPLIERS.size() - 1)
	var base := clampf(1.1 + float(char_count) * 0.038, 1.5, 4.2)
	return base * AUTO_MULTIPLIERS[idx]


func get_bgm_gain_db() -> float:
	var v := clampf(float(settings.get("bgm_volume", 0.85)), 0.0, 1.0)
	if v <= 0.01:
		return -80.0
	return linear_to_db(v)


func get_se_gain_db() -> float:
	var v := clampf(float(settings.get("se_volume", 0.90)), 0.0, 1.0)
	if v <= 0.01:
		return -80.0
	return linear_to_db(v)


func count_scene_read_progress(scenes: Dictionary, scene_id: String) -> Dictionary:
	var sc: Variant = scenes.get(scene_id, null)
	if not (sc is Dictionary):
		return {"read": 0, "total": 0}
	var lines: Array = (sc as Dictionary).get("lines", [])
	var read_cnt := 0
	for i in lines.size():
		if is_line_read(scene_id, i):
			read_cnt += 1
	return {"read": read_cnt, "total": lines.size()}


func count_uncollected_endings_from(scenes: Dictionary, start_id: String) -> int:
	if start_id.is_empty() or not scenes.has(start_id):
		return 0
	var queue: Array[String] = [start_id]
	var seen: Dictionary = {}
	var endings_found: Dictionary = {}
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if seen.has(cur) or not scenes.has(cur):
			continue
		seen[cur] = true
		var sc: Dictionary = scenes[cur]
		if sc.has("ending") and sc["ending"] is Dictionary:
			var ed_id := str((sc["ending"] as Dictionary).get("id", ""))
			if not ed_id.is_empty():
				endings_found[ed_id] = true
		var next_id := str(sc.get("next", ""))
		if not next_id.is_empty():
			queue.append(next_id)
		var choices: Array = sc.get("choices", [])
		for ch in choices:
			if ch is Dictionary:
				var tid := str((ch as Dictionary).get("target", ""))
				if not tid.is_empty():
					queue.append(tid)

	var uncollected := 0
	for ed_id in endings_found.keys():
		if not unlocked_endings.has(ed_id):
			uncollected += 1
	return uncollected
