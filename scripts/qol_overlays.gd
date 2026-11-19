extends Control
## 周回プレイ快適化オーバーレイ（記録帳セーブ/ロード・歴史年表章選択・環境設定・トースト通知）

const SaveStore = preload("res://scripts/save_store.gd")

signal save_slot_requested(slot_id: String)
signal load_slot_requested(slot_id: String)
signal delete_slot_requested(slot_id: String)
signal chapter_selected(scene_id: String)
signal settings_changed()
signal test_se_requested()
signal overlay_closed(kind: String)

const COLOR_SUMI := Color(0.0941, 0.0941, 0.1216, 0.96)
const COLOR_DARK := Color(0.062, 0.062, 0.082, 0.96)
const COLOR_CRIMSON := Color("9E1B1B")
const COLOR_GOLD := Color("C8A86B")
const COLOR_PAPER := Color("F2EFE9")
const COLOR_MUTED := Color("A8A296")

var _store: SaveStore = null
var _scenes: Dictionary = {}
var _episode_id: String = SaveStore.DEFAULT_EPISODE_ID
var _can_save: bool = false
var _save_mode_write: bool = false

# Save / Load overlay
var _save_overlay: Control
var _save_title_lbl: Label
var _tab_save_btn: Button
var _tab_load_btn: Button
var _save_list: VBoxContainer
var _save_close_btn: Button

# Chapter Select overlay
var _chapter_overlay: Control
var _chapter_summary_lbl: Label
var _chapter_grid: GridContainer
var _chapter_scroll: ScrollContainer
var _chapter_close_btn: Button

# Settings overlay
var _settings_overlay: Control
var _bgm_slider: HSlider
var _bgm_pct_lbl: Label
var _se_slider: HSlider
var _se_pct_lbl: Label
var _text_speed_btns: Array[Button] = []
var _auto_speed_btns: Array[Button] = []
var _skip_mode_btns: Array[Button] = []
var _settings_reset_btn: Button
var _settings_close_btn: Button

# Toast banner
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween = null


func setup(store: SaveStore, scenes_ref: Dictionary, episode_id: String = SaveStore.DEFAULT_EPISODE_ID) -> void:
	_store = store
	_scenes = scenes_ref
	_episode_id = episode_id if not episode_id.is_empty() else SaveStore.DEFAULT_EPISODE_ID
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_save_overlay()
	_build_chapter_overlay()
	_build_settings_overlay()
	_build_toast_banner()


func set_scenes(scenes_ref: Dictionary, episode_id: String = "") -> void:
	_scenes = scenes_ref
	if not episode_id.is_empty():
		_episode_id = episode_id


func is_any_open() -> bool:
	return _save_overlay.visible or _chapter_overlay.visible or _settings_overlay.visible


func close_top_overlay() -> bool:
	if _settings_overlay.visible:
		close_settings()
		return true
	if _chapter_overlay.visible:
		close_chapter_select()
		return true
	if _save_overlay.visible:
		close_save_load()
		return true
	return false


func show_toast(message: String, is_warn: bool = false) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = "◆ " + message
	var border_col := COLOR_CRIMSON.lightened(0.28) if is_warn else COLOR_GOLD
	_toast_panel.add_theme_stylebox_override("panel", _make_box(Color(0.055, 0.055, 0.075, 0.94), border_col, 2, 28, 12))
	_toast_label.add_theme_color_override("font_color", COLOR_PAPER)
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_interval(1.65)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void:
		_toast_panel.visible = false
	)


func open_save_load(can_save_now: bool, start_write_mode: bool = false) -> void:
	_can_save = can_save_now
	_save_mode_write = start_write_mode and can_save_now
	_tab_save_btn.visible = can_save_now
	_refresh_save_overlay()
	_save_overlay.visible = true
	_focus_target(_tab_save_btn if _save_mode_write else _tab_load_btn)


func close_save_load() -> void:
	if not _save_overlay.visible:
		return
	_save_overlay.visible = false
	overlay_closed.emit("save")


func refresh_save_overlay_if_open() -> void:
	if _save_overlay.visible:
		_refresh_save_overlay()


func open_chapter_select() -> void:
	_refresh_chapter_overlay()
	_chapter_overlay.visible = true
	_focus_target(_chapter_close_btn)
	await get_tree().process_frame
	if _chapter_scroll != null:
		_chapter_scroll.scroll_vertical = 0


func close_chapter_select() -> void:
	if not _chapter_overlay.visible:
		return
	_chapter_overlay.visible = false
	overlay_closed.emit("chapter")


func open_settings() -> void:
	_sync_settings_ui()
	_settings_overlay.visible = true
	_focus_target(_settings_close_btn)


func close_settings() -> void:
	if not _settings_overlay.visible:
		return
	_settings_overlay.visible = false
	if _store != null:
		_store.save_to_disk()
	overlay_closed.emit("settings")


# --- 記録帳（セーブ / ロード） ---

func _build_save_overlay() -> void:
	var shell := _create_modal_shell("SaveLoadOverlay", Vector2(1280, 820), close_save_load)
	_save_overlay = shell["root"]
	var vbox: VBoxContainer = shell["vbox"]
	add_child(_save_overlay)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vbox.add_child(header)

	_save_title_lbl = Label.new()
	_save_title_lbl.text = "記録帳 ― 栞の保存と再開"
	_save_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_title_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	_save_title_lbl.add_theme_font_size_override("font_size", 36)
	header.add_child(_save_title_lbl)

	_tab_save_btn = Button.new()
	_tab_save_btn.text = "記録する（書込）"
	_tab_save_btn.custom_minimum_size = Vector2(240, 56)
	_tab_save_btn.pressed.connect(func() -> void:
		if _can_save:
			_save_mode_write = true
			_refresh_save_overlay()
	)
	header.add_child(_tab_save_btn)

	_tab_load_btn = Button.new()
	_tab_load_btn.text = "再開する（読込）"
	_tab_load_btn.custom_minimum_size = Vector2(240, 56)
	_tab_load_btn.pressed.connect(func() -> void:
		_save_mode_write = false
		_refresh_save_overlay()
	)
	header.add_child(_tab_load_btn)

	_save_close_btn = Button.new()
	_save_close_btn.text = "閉じる"
	_save_close_btn.custom_minimum_size = Vector2(160, 56)
	_save_close_btn.pressed.connect(close_save_load)
	header.add_child(_save_close_btn)

	vbox.add_child(_make_gold_line())

	_save_list = VBoxContainer.new()
	_save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_save_list.add_theme_constant_override("separation", 16)
	vbox.add_child(_save_list)


func _refresh_save_overlay() -> void:
	_apply_toggle_style(_tab_save_btn, _save_mode_write)
	_apply_toggle_style(_tab_load_btn, not _save_mode_write)
	_save_title_lbl.text = "記録帳 ― 栞を挟む（保存先を選択）" if _save_mode_write else "記録帳 ― 栞から物語を再開"

	for c in _save_list.get_children():
		c.queue_free()

	for slot_id in SaveStore.SLOT_IDS:
		_save_list.add_child(_create_slot_row(slot_id))


func _create_slot_row(slot_id: String) -> PanelContainer:
	var data := _store.get_slot(slot_id) if _store != null else {}
	var has_data := not data.is_empty()
	var is_quick := slot_id == "quick"

	var border_col := COLOR_GOLD if has_data else Color(0.35, 0.33, 0.30, 0.65)
	var bg_col := Color(0.115, 0.10, 0.135, 0.94) if has_data else Color(0.065, 0.065, 0.085, 0.88)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_box(bg_col, border_col, 1, 24, 16))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 6)
	row.add_child(info_col)

	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 14)
	info_col.add_child(top_line)

	var name_lbl := Label.new()
	name_lbl.text = str(SaveStore.SLOT_LABELS.get(slot_id, slot_id))
	name_lbl.add_theme_color_override("font_color", COLOR_CRIMSON.lightened(0.35) if is_quick else COLOR_GOLD)
	name_lbl.add_theme_font_size_override("font_size", 25)
	top_line.add_child(name_lbl)

	if has_data:
		var ch := str(data.get("chapter", ""))
		var st := str(data.get("title", ""))
		var chap_lbl := Label.new()
		chap_lbl.text = "%s　%s" % [ch, st] if not ch.is_empty() else st
		chap_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chap_lbl.add_theme_color_override("font_color", COLOR_PAPER)
		chap_lbl.add_theme_font_size_override("font_size", 24)
		top_line.add_child(chap_lbl)

		if bool(data.get("at_choices", false)):
			var ch_badge := Label.new()
			ch_badge.text = "【分岐選択中】"
			ch_badge.add_theme_color_override("font_color", COLOR_GOLD)
			ch_badge.add_theme_font_size_override("font_size", 21)
			top_line.add_child(ch_badge)

		var time_lbl := Label.new()
		time_lbl.text = str(data.get("saved_at", ""))
		time_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		time_lbl.add_theme_font_size_override("font_size", 20)
		top_line.add_child(time_lbl)

		var spk := str(data.get("speaker", ""))
		var exc := str(data.get("excerpt", ""))
		var text_line := Label.new()
		text_line.text = ("【%s】%s" % [spk, exc]) if not spk.is_empty() else exc
		text_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_line.add_theme_color_override("font_color", COLOR_PAPER.darkened(0.12))
		text_line.add_theme_font_size_override("font_size", 23)
		info_col.add_child(text_line)

		var loc_lbl := Label.new()
		loc_lbl.text = str(data.get("location", ""))
		loc_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		loc_lbl.add_theme_font_size_override("font_size", 19)
		info_col.add_child(loc_lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "（記録はまだありません）"
		empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 23)
		info_col.add_child(empty_lbl)

	var btn_box := HBoxContainer.new()
	btn_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_box.add_theme_constant_override("separation", 10)
	row.add_child(btn_box)

	var act_btn := Button.new()
	act_btn.custom_minimum_size = Vector2(180, 60)
	if _save_mode_write:
		act_btn.text = "上書き保存" if has_data else "ここに記録"
		act_btn.pressed.connect(func() -> void:
			save_slot_requested.emit(slot_id)
		)
	else:
		act_btn.text = "この栞から再開" if has_data else "記録なし"
		act_btn.disabled = not has_data
		act_btn.pressed.connect(func() -> void:
			load_slot_requested.emit(slot_id)
		)
	btn_box.add_child(act_btn)

	if has_data:
		var del_btn := Button.new()
		del_btn.text = "消去"
		del_btn.custom_minimum_size = Vector2(96, 60)
		del_btn.pressed.connect(func() -> void:
			delete_slot_requested.emit(slot_id)
		)
		btn_box.add_child(del_btn)

	return card


# --- 歴史年表（章選択） ---

func _build_chapter_overlay() -> void:
	var shell := _create_modal_shell("ChapterSelectOverlay", Vector2(1520, 880), close_chapter_select)
	_chapter_overlay = shell["root"]
	var vbox: VBoxContainer = shell["vbox"]
	add_child(_chapter_overlay)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "歴史年表 ― 到達済みの章へ跳躍"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 36)
	header.add_child(title_lbl)

	_chapter_summary_lbl = Label.new()
	_chapter_summary_lbl.add_theme_color_override("font_color", COLOR_PAPER)
	_chapter_summary_lbl.add_theme_font_size_override("font_size", 24)
	header.add_child(_chapter_summary_lbl)

	_chapter_close_btn = Button.new()
	_chapter_close_btn.text = "閉じる"
	_chapter_close_btn.custom_minimum_size = Vector2(180, 56)
	_chapter_close_btn.pressed.connect(close_chapter_select)
	header.add_child(_chapter_close_btn)

	vbox.add_child(_make_gold_line())

	_chapter_scroll = ScrollContainer.new()
	_chapter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chapter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_chapter_scroll)

	var scroll_pad := MarginContainer.new()
	scroll_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_pad.add_theme_constant_override("margin_right", 16)
	scroll_pad.add_theme_constant_override("margin_top", 4)
	scroll_pad.add_theme_constant_override("margin_bottom", 4)
	_chapter_scroll.add_child(scroll_pad)

	_chapter_grid = GridContainer.new()
	_chapter_grid.columns = 2
	_chapter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_grid.add_theme_constant_override("h_separation", 24)
	_chapter_grid.add_theme_constant_override("v_separation", 20)
	scroll_pad.add_child(_chapter_grid)


func _refresh_chapter_overlay() -> void:
	for c in _chapter_grid.get_children():
		c.queue_free()

	var ordered_ids := _get_ordered_scene_ids()
	var unlocked_cnt := 0
	for sid in ordered_ids:
		if _store != null and _store.is_scene_visited(sid):
			unlocked_cnt += 1
	_chapter_summary_lbl.text = "到達章： %d / %d" % [unlocked_cnt, ordered_ids.size()]

	for sid in ordered_ids:
		var sc: Dictionary = _scenes.get(sid, {})
		var visited := _store != null and _store.is_scene_visited(sid)
		_chapter_grid.add_child(_create_chapter_card(sid, sc, visited))


func _get_ordered_scene_ids() -> Array[String]:
	var result: Array[String] = []
	if _episode_id == SaveStore.DEFAULT_EPISODE_ID:
		for sid in SaveStore.CHAPTER_ORDER:
			if _scenes.has(sid):
				result.append(sid)
	for k in _scenes.keys():
		var sid := str(k)
		if not result.has(sid):
			result.append(sid)
	return result


func _route_badge_info(sid: String, sc: Dictionary) -> Dictionary:
	if sid == "end_05_true" or (sc.has("ending") and sc["ending"] is Dictionary and str((sc["ending"] as Dictionary).get("id", "")) == "END_5_TRUE"):
		return {"text": "真・終幕", "color": Color("E6C675")}
	if sid.begins_with("pro_"):
		return {"text": "序章", "color": COLOR_GOLD}
	if sid.begins_with("routeA_"):
		return {"text": "覇道篇", "color": COLOR_CRIMSON.lightened(0.32)}
	if sid.begins_with("routeB_"):
		return {"text": "暗躍篇", "color": Color("7E6BB8").lightened(0.2)}
	if sc.has("ending"):
		return {"text": "終幕", "color": COLOR_GOLD.lightened(0.15)}
	return {"text": "本編", "color": COLOR_MUTED}


func _create_chapter_card(sid: String, sc: Dictionary, visited: bool) -> PanelContainer:
	var has_choices := sc.has("choices") and not (sc["choices"] as Array).is_empty()
	var route_info := _route_badge_info(sid, sc)
	var border_col: Color = route_info["color"] if visited else Color(0.32, 0.30, 0.28, 0.6)
	var bg_col := Color(0.105, 0.095, 0.125, 0.94) if visited else Color(0.06, 0.06, 0.08, 0.90)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(670, 178)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_box(bg_col, border_col, 1, 24, 18))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	row.add_child(left_col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	left_col.add_child(top)

	var tag := Label.new()
	tag.text = "【%s】%s" % [route_info["text"], str(sc.get("chapter", "")) if visited else "？？？"]
	tag.add_theme_color_override("font_color", route_info["color"] if visited else COLOR_MUTED)
	tag.add_theme_font_size_override("font_size", 21)
	top.add_child(tag)

	if has_choices:
		var br_lbl := Label.new()
		br_lbl.text = "◆ 分岐あり"
		br_lbl.add_theme_color_override("font_color", COLOR_GOLD if visited else Color(0.55, 0.50, 0.42, 0.7))
		br_lbl.add_theme_font_size_override("font_size", 20)
		top.add_child(br_lbl)

	if visited and _store != null:
		var prog := _store.count_scene_read_progress(_scenes, sid)
		var prog_lbl := Label.new()
		prog_lbl.text = "既読 %d/%d" % [prog["read"], prog["total"]]
		prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prog_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		prog_lbl.add_theme_font_size_override("font_size", 19)
		top.add_child(prog_lbl)

	var title_lbl := Label.new()
	title_lbl.text = str(sc.get("title", "")) if visited else "未到達の章"
	title_lbl.add_theme_color_override("font_color", COLOR_PAPER if visited else COLOR_MUTED)
	title_lbl.add_theme_font_size_override("font_size", 30)
	left_col.add_child(title_lbl)

	var loc_lbl := Label.new()
	loc_lbl.text = str(sc.get("location", "")) if visited else "本編を進めてこの章へ至ると解放されます"
	loc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	loc_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	loc_lbl.add_theme_font_size_override("font_size", 20)
	left_col.add_child(loc_lbl)

	var jump_btn := Button.new()
	jump_btn.text = "この章から\n始める" if visited else "未解放"
	jump_btn.custom_minimum_size = Vector2(165, 86)
	jump_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jump_btn.disabled = not visited
	jump_btn.pressed.connect(func() -> void:
		close_chapter_select()
		chapter_selected.emit(sid)
	)
	row.add_child(jump_btn)

	return card


# --- 環境設定モーダル ---

func _build_settings_overlay() -> void:
	var shell := _create_modal_shell("SettingsOverlay", Vector2(1180, 820), close_settings)
	_settings_overlay = shell["root"]
	var vbox: VBoxContainer = shell["vbox"]
	add_child(_settings_overlay)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "環境設定 ― 音響・進行・操作案内"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	title_lbl.add_theme_font_size_override("font_size", 36)
	header.add_child(title_lbl)

	_settings_close_btn = Button.new()
	_settings_close_btn.text = "閉じる"
	_settings_close_btn.custom_minimum_size = Vector2(180, 56)
	_settings_close_btn.pressed.connect(close_settings)
	header.add_child(_settings_close_btn)

	vbox.add_child(_make_gold_line())

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	vbox.add_child(body)

	# BGM 音量
	var bgm_res := _create_slider_row("BGM 音量")
	body.add_child(bgm_res["row"])
	_bgm_slider = bgm_res["slider"]
	_bgm_pct_lbl = bgm_res["pct"]
	_bgm_slider.value_changed.connect(func(val: float) -> void:
		if _store != null:
			_store.settings["bgm_volume"] = clampf(val / 100.0, 0.0, 1.0)
			_bgm_pct_lbl.text = "%d%%" % int(round(val))
			settings_changed.emit()
	)

	# SE 音量
	var se_res := _create_slider_row("効果音（SE）音量")
	body.add_child(se_res["row"])
	_se_slider = se_res["slider"]
	_se_pct_lbl = se_res["pct"]
	_se_slider.value_changed.connect(func(val: float) -> void:
		if _store != null:
			_store.settings["se_volume"] = clampf(val / 100.0, 0.0, 1.0)
			_se_pct_lbl.text = "%d%%" % int(round(val))
			settings_changed.emit()
	)
	_se_slider.drag_ended.connect(func(_changed: bool) -> void:
		test_se_requested.emit()
	)

	# 文字表示速度
	var ts_res := _create_choice_row("文字表示速度", SaveStore.TEXT_SPEED_LABELS, func(idx: int) -> void:
		if _store != null:
			_store.settings["text_speed"] = idx
			_sync_settings_ui()
			settings_changed.emit()
	)
	body.add_child(ts_res["row"])
	_text_speed_btns = ts_res["buttons"]

	# 自動送り待機
	var as_res := _create_choice_row("自動送り速度", SaveStore.AUTO_SPEED_LABELS, func(idx: int) -> void:
		if _store != null:
			_store.settings["auto_speed"] = idx
			_sync_settings_ui()
			settings_changed.emit()
	)
	body.add_child(as_res["row"])
	_auto_speed_btns = as_res["buttons"]

	# スキップ対象
	var sk_res := _create_choice_row("スキップ対象", ["既読のみ（推奨）", "すべて（未読含む）"], func(idx: int) -> void:
		if _store != null:
			_store.settings["skip_unread"] = (idx == 1)
			_sync_settings_ui()
			settings_changed.emit()
	)
	body.add_child(sk_res["row"])
	_skip_mode_btns = sk_res["buttons"]

	# 操作一覧案内
	var help_panel := PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.05, 0.068, 0.85), Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.45), 1, 24, 16))
	body.add_child(help_panel)

	var help_lbl := Label.new()
	help_lbl.text = (
		"【操作一覧】　左クリック / Space / Enter / Z：文章送り　|　右クリック / M：ウィンドウ非表示\n"
		+ "H / マウス上ホイール：履歴を開く　|　A：自動送り切替　|　S：スキップ切替　|　Ctrl長押し：押下中スキップ\n"
		+ "Q / F5：急速記録（クイックセーブ）　|　L / F9：急速再開（クイックロード）　|　1〜9：選択肢決定　|　Esc：戻る"
	)
	help_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	help_lbl.add_theme_font_size_override("font_size", 21)
	help_panel.add_child(help_lbl)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 18)
	vbox.add_child(footer)

	_settings_reset_btn = Button.new()
	_settings_reset_btn.text = "初期設定に戻す"
	_settings_reset_btn.custom_minimum_size = Vector2(240, 58)
	_settings_reset_btn.pressed.connect(func() -> void:
		if _store != null:
			_store.reset_settings_to_default()
			_sync_settings_ui()
			settings_changed.emit()
			test_se_requested.emit()
	)
	footer.add_child(_settings_reset_btn)


func _sync_settings_ui() -> void:
	if _store == null:
		return
	var bgm_pct := int(round(float(_store.settings.get("bgm_volume", 0.85)) * 100.0))
	var se_pct := int(round(float(_store.settings.get("se_volume", 0.90)) * 100.0))
	_bgm_slider.set_value_no_signal(float(bgm_pct))
	_bgm_pct_lbl.text = "%d%%" % bgm_pct
	_se_slider.set_value_no_signal(float(se_pct))
	_se_pct_lbl.text = "%d%%" % se_pct

	var ts := int(_store.settings.get("text_speed", 1))
	for i in _text_speed_btns.size():
		_apply_toggle_style(_text_speed_btns[i], i == ts)

	var aus := int(_store.settings.get("auto_speed", 1))
	for i in _auto_speed_btns.size():
		_apply_toggle_style(_auto_speed_btns[i], i == aus)

	var su_idx := 1 if bool(_store.settings.get("skip_unread", false)) else 0
	for i in _skip_mode_btns.size():
		_apply_toggle_style(_skip_mode_btns[i], i == su_idx)


func _build_toast_banner() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "QolToastBanner"
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.offset_left = -330.0
	_toast_panel.offset_right = 330.0
	_toast_panel.offset_top = 138.0
	_toast_panel.offset_bottom = 194.0
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)


# --- UI 生成ヘルパー ---

func _create_modal_shell(node_name: String, panel_min_size: Vector2, on_dim_close: Callable) -> Dictionary:
	var root := Control.new()
	root.name = node_name
	root.visible = false
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.025, 0.035, 0.78)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				on_dim_close.call()
	)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_min_size
	panel.add_theme_stylebox_override("panel", _make_box(COLOR_DARK, COLOR_GOLD, 1, 42, 34))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	return {"root": root, "panel": panel, "vbox": vbox}


func _create_slider_row(label_text: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(280, 0)
	lbl.add_theme_color_override("font_color", COLOR_PAPER)
	lbl.add_theme_font_size_override("font_size", 27)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(400, 36)
	row.add_child(slider)

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(90, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", COLOR_GOLD)
	pct.add_theme_font_size_override("font_size", 26)
	row.add_child(pct)

	return {"row": row, "slider": slider, "pct": pct}


func _create_choice_row(label_text: String, options: Array, on_select: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(280, 0)
	lbl.add_theme_color_override("font_color", COLOR_PAPER)
	lbl.add_theme_font_size_override("font_size", 27)
	row.add_child(lbl)

	var btns: Array[Button] = []
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(140, 56)
		b.pressed.connect(on_select.bind(i))
		hbox.add_child(b)
		btns.append(b)

	return {"row": row, "buttons": btns}


func _apply_toggle_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _make_box(COLOR_CRIMSON, COLOR_GOLD, 2, 18, 10))
		btn.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_color_override("font_color")


func _make_gold_line() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.55)
	return line


func _make_box(bg: Color, border: Color, border_w: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func _focus_target(ctrl: Control) -> void:
	if ctrl == null:
		return
	if ctrl.is_visible_in_tree():
		ctrl.grab_focus()
	else:
		ctrl.call_deferred("grab_focus")
