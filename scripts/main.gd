extends Control
## IF : SURVIVE 戦国・幕末異聞 マルチタイトル統合コントローラ

const SaveStore = preload("res://scripts/save_store.gd")
const QolOverlays = preload("res://scripts/qol_overlays.gd")
const GameManagerScript = preload("res://scripts/game_manager.gd")

const COLOR_VOID := Color("0B0B0E")
const COLOR_SUMI := Color(0.0941, 0.0941, 0.1216, 0.90)
const COLOR_SUMI_SOLID := Color("18181F")
const COLOR_CRIMSON := Color("9E1B1B")
const COLOR_GOLD := Color("C8A86B")
const COLOR_PAPER := Color("F2EFE9")
const COLOR_MUTED := Color("A8A296")

const FONT_PATH := "res://common_assets/fonts/mincho.ttf"
const LEGACY_FONT_PATH := "res://assets/fonts/mincho.ttf"

const CHAR_INTERVAL := 0.035
const SKIP_INTERVAL := 0.055
const SHAKE_DURATION := 0.35
const SHAKE_MAX_OFFSET := 19.5

# --- シリーズ・シナリオ・セーブデータ ---
var _current_episode: Dictionary = {}
var _current_episode_id: String = SaveStore.DEFAULT_EPISODE_ID
var _current_episode_dir: String = "res://episodes/01_nobunaga"
var _scenario_data: Dictionary = {}
var _meta: Dictionary = {}
var _assets_cfg: Dictionary = {}
var _scenes: Dictionary = {}
var _endings_catalog: Array[Dictionary] = []
var _unlocked_endings: Array[String] = []
var _save_store := SaveStore.new()
var _fallback_gm: Node = null

# --- 進行状態 ---
var _in_game: bool = false
var _current_scene_id: String = ""
var _current_scene: Dictionary = {}
var _line_index: int = 0
var _full_text: String = ""
var _parsed_text: String = ""
var _total_chars: int = 0
var _is_typing: bool = false
var _char_timer: float = 0.0
var _char_step_delay: float = CHAR_INTERVAL
var _auto_mode: bool = false
var _auto_wait_timer: float = 0.0
var _skip_mode: bool = false
var _skip_timer: float = 0.0
var _current_line_was_read: bool = false
var _at_choices: bool = false
var _is_transitioning: bool = false
var _ui_hidden: bool = false
var _opened_gallery_from_ending: bool = false
var _opened_gallery_from_portal: bool = false
var _suppress_sfx_for_skip: bool = false
var _backlog_entries: Array[Dictionary] = []

# --- 立ち絵状態 ---
var _sprite_slots: Dictionary = {} # "left" / "right" -> Dictionary
var _sprite_tweens: Dictionary = {}
var _crossfade_tweens: Dictionary = {}
var _action_tweens: Dictionary = {}
var _slot_base_pos: Dictionary = {}

# --- 演出状態 ---
var _shake_timer: float = 0.0
var _flash_tween: Tween = null
var _indicator_time: float = 0.0
var _bg_breath_time: float = 0.0
var _bg_impact_zoom: float = 0.0
var _current_bgm_id: String = ""
var _mood_bgm_id: String = ""
var _current_bg_id: String = ""
var _current_effect_name: String = ""
var _last_speaker_key: String = ""
var _speaker_accent_tween: Tween = null
var _vignette_tween: Tween = null
var _vignette_edge: Color = Color(0.03, 0.03, 0.05, 0.44)
var _vignette_glow: Color = Color(0.0, 0.0, 0.0, 0.0)
var _vignette_strength: float = 0.44
var _banner_tween: Tween = null
var _transition_tween: Tween = null
var _bgm_tween: Tween = null
var _audio_cache: Dictionary = {}
var _synth_wav_cache: Dictionary = {}

# --- フォント・テーマ ---
var _main_font: Font = null
var _app_theme: Theme = null

# --- シーンノード参照 ---
@onready var _shake_root: Control = $ShakeRoot
@onready var _title_screen: Control = $ShakeRoot/TitleScreen
@onready var _title_bg_host: Control = $ShakeRoot/TitleScreen/TitleBgHost
@onready var _title_particles: AtmosphericEffects = $ShakeRoot/TitleScreen/TitleParticles
@onready var _title_art_host: Control = $ShakeRoot/TitleScreen/TitleArtHost
@onready var _start_button: Button = $ShakeRoot/TitleScreen/MenuBox/StartButton
@onready var _gallery_button: Button = $ShakeRoot/TitleScreen/MenuBox/GalleryButton
@onready var _version_label: Label = $ShakeRoot/TitleScreen/VersionLabel

@onready var _game_screen: Control = $ShakeRoot/GameScreen
@onready var _bg_fallback_host: Control = $ShakeRoot/GameScreen/BackgroundLayer/FallbackBgHost
@onready var _bg_texture_rect: TextureRect = $ShakeRoot/GameScreen/BackgroundLayer/BgTextureRect
@onready var _bg_watermark: Label = $ShakeRoot/GameScreen/BackgroundLayer/BgWatermark
@onready var _bg_fade_rect: ColorRect = $ShakeRoot/GameScreen/BackgroundLayer/BgFadeRect

@onready var _left_slot: Control = $ShakeRoot/GameScreen/CharacterLayer/LeftSlot
@onready var _right_slot: Control = $ShakeRoot/GameScreen/CharacterLayer/RightSlot
@onready var _atmosphere_particles: AtmosphericEffects = $ShakeRoot/GameScreen/AtmosphereParticles
@onready var _chapter_banner: Control = $ShakeRoot/GameScreen/ChapterBanner
@onready var _chapter_banner_label: Label = $ShakeRoot/GameScreen/ChapterBanner/BannerPanel/BannerLabel

@onready var _click_advance_layer: Control = $ShakeRoot/GameScreen/ClickAdvanceLayer
@onready var _message_window: Control = $ShakeRoot/GameScreen/MessageWindow
@onready var _msg_top_fade: TextureRect = $ShakeRoot/GameScreen/MessageWindow/TopFadeRect
@onready var _msg_body_rect: ColorRect = $ShakeRoot/GameScreen/MessageWindow/BodyRect
@onready var _speaker_row: Control = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/SpeakerRow
@onready var _speaker_accent: ColorRect = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/SpeakerRow/SpeakerAccent
@onready var _speaker_label: Label = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/SpeakerRow/SpeakerLabel
@onready var _gold_divider: ColorRect = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/GoldDivider
@onready var _body_text: RichTextLabel = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/TextArea/BodyText
@onready var _next_indicator: Label = $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox/TextArea/NextIndicator

@onready var _top_hud: Control = $ShakeRoot/GameScreen/TopHUD
@onready var _location_panel: PanelContainer = $ShakeRoot/GameScreen/TopHUD/LocationPanel
@onready var _chapter_label: Label = $ShakeRoot/GameScreen/TopHUD/LocationPanel/LocMargin/LocVBox/ChapterLabel
@onready var _location_label: Label = $ShakeRoot/GameScreen/TopHUD/LocationPanel/LocMargin/LocVBox/LocationLabel
@onready var _backlog_button: Button = $ShakeRoot/GameScreen/TopHUD/HudButtons/BacklogButton
@onready var _auto_button: Button = $ShakeRoot/GameScreen/TopHUD/HudButtons/AutoButton
@onready var _title_return_button: Button = $ShakeRoot/GameScreen/TopHUD/HudButtons/TitleReturnButton

@onready var _choice_overlay: Control = $ShakeRoot/ChoiceOverlay
@onready var _choice_blur_rect: ColorRect = $ShakeRoot/ChoiceOverlay/BlurBackdrop
@onready var _choice_panel: PanelContainer = $ShakeRoot/ChoiceOverlay/ChoiceCenter/ChoicePanel
@onready var _choice_prompt_label: Label = $ShakeRoot/ChoiceOverlay/ChoiceCenter/ChoicePanel/ChoiceMargin/ChoiceVBox/ChoicePromptLabel
@onready var _choices_container: VBoxContainer = $ShakeRoot/ChoiceOverlay/ChoiceCenter/ChoicePanel/ChoiceMargin/ChoiceVBox/ChoicesContainer

@onready var _backlog_overlay: Control = $ShakeRoot/BacklogOverlay
@onready var _backlog_dim: ColorRect = $ShakeRoot/BacklogOverlay/BacklogDim
@onready var _backlog_panel: PanelContainer = $ShakeRoot/BacklogOverlay/BacklogCenter/BacklogPanel
@onready var _backlog_scroll: ScrollContainer = $ShakeRoot/BacklogOverlay/BacklogCenter/BacklogPanel/BacklogMargin/BacklogVBox/BacklogScroll
@onready var _backlog_list: VBoxContainer = $ShakeRoot/BacklogOverlay/BacklogCenter/BacklogPanel/BacklogMargin/BacklogVBox/BacklogScroll/BacklogList
@onready var _backlog_close_btn: Button = $ShakeRoot/BacklogOverlay/BacklogCenter/BacklogPanel/BacklogMargin/BacklogVBox/BacklogHeader/BacklogCloseButton

@onready var _ending_card_overlay: Control = $ShakeRoot/EndingCardOverlay
@onready var _ending_num_label: Label = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel/EndingMargin/EndingVBox/EndingNumberLabel
@onready var _ending_title_label: Label = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel/EndingMargin/EndingVBox/EndingTitleLabel
@onready var _ending_sub_label: Label = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel/EndingMargin/EndingVBox/EndingSubLabel
@onready var _ending_gallery_btn: Button = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel/EndingMargin/EndingVBox/EndingActions/EndingGalleryBtn
@onready var _ending_title_btn: Button = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel/EndingMargin/EndingVBox/EndingActions/EndingTitleBtn
@onready var _ending_card_panel: PanelContainer = $ShakeRoot/EndingCardOverlay/EndingCenter/EndingCardPanel

@onready var _gallery_overlay: Control = $ShakeRoot/EndingGalleryOverlay
@onready var _gallery_dim: ColorRect = $ShakeRoot/EndingGalleryOverlay/GalleryDim
@onready var _gallery_panel: PanelContainer = $ShakeRoot/EndingGalleryOverlay/GalleryCenter/GalleryPanel
@onready var _gallery_count_label: Label = $ShakeRoot/EndingGalleryOverlay/GalleryCenter/GalleryPanel/GalleryMargin/GalleryVBox/GalleryHeader/GalleryCountLabel
@onready var _gallery_grid: GridContainer = $ShakeRoot/EndingGalleryOverlay/GalleryCenter/GalleryPanel/GalleryMargin/GalleryVBox/GalleryGrid
@onready var _gallery_close_btn: Button = $ShakeRoot/EndingGalleryOverlay/GalleryCenter/GalleryPanel/GalleryMargin/GalleryVBox/GalleryFooter/GalleryCloseBtn

@onready var _confirm_overlay: Control = $ShakeRoot/ConfirmTitleOverlay
@onready var _confirm_dim: ColorRect = $ShakeRoot/ConfirmTitleOverlay/ConfirmDim
@onready var _confirm_panel: PanelContainer = $ShakeRoot/ConfirmTitleOverlay/ConfirmCenter/ConfirmPanel
@onready var _confirm_yes_btn: Button = $ShakeRoot/ConfirmTitleOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtons/ConfirmYesBtn
@onready var _confirm_no_btn: Button = $ShakeRoot/ConfirmTitleOverlay/ConfirmCenter/ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtons/ConfirmNoBtn

@onready var _flash_overlay: ColorRect = $ShakeRoot/FlashOverlay
@onready var _bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var _se_players_root: Node = $SePlayers

# --- 動的生成ビュー & QoL UI ---
var _title_backdrop: TitleBackdropView
var _main_title_backdrop: TitleBackdropView
var _portal_backdrop: TitleBackdropView
var _fallback_bg_view: FallbackBgView
var _vignette_rect: ColorRect
var _vignette_mat: ShaderMaterial
var _qol_overlays: QolOverlays
var _main_title_screen: Control
var _main_title_particles: AtmosphericEffects
var _main_series_btn: Button
var _main_continue_btn: Button
var _main_gallery_btn: Button
var _main_settings_btn: Button
var _main_title_logo: TextureRect
var _portal_screen: Control
var _portal_particles: AtmosphericEffects
var _portal_cards_box: VBoxContainer
var _portal_stats_lbl: Label
var _portal_back_btn: Button
var _prelude_tag: Label
var _title_episode_logo: TextureRect
var _gallery_title_label: Label
var _continue_button: Button
var _load_menu_button: Button
var _chapter_menu_button: Button
var _settings_menu_button: Button
var _portal_return_button: Button
var _ep_menu_host: VBoxContainer
var _skip_button: Button
var _record_button: Button
var _settings_hud_button: Button
var _mute_hud_button: Button
var _read_badge: Label
var _shortcut_hint: Label
var _se_pool: Array[AudioStreamPlayer] = []
var _se_pool_cursor: int = 0


func _ready() -> void:
	_setup_font_and_theme()
	_setup_audio_pool()
	_setup_styles_and_shaders()
	_setup_character_slots()
	_setup_qol_ui()
	_setup_portal_ui()
	_setup_main_title_ui()
	_connect_signals()

	_load_save_data()
	_init_default_episode_context()
	_apply_live_audio_volumes()
	_update_mute_button_visual()
	_qol_overlays.set_scenes(_scenes, _current_episode_id)
	_show_main_title_screen()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_store.flush_if_dirty()


func _exit_tree() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
		_bgm_tween = null
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.stream = null
	for p in _se_pool:
		if p != null:
			p.stop()
			p.stream = null
	_audio_cache.clear()
	_synth_wav_cache.clear()


func _setup_font_and_theme() -> void:
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray([
		"Shippori Mincho",
		"Hiragino Mincho ProN",
		"Yu Mincho",
		"Noto Serif CJK JP",
		"Noto Serif JP",
		"MS PMincho",
		"Serif"
	])

	var loaded_font: Font = null
	var use_sys_fallback := (OS.get_name() != "Web")
	for fp in [FONT_PATH, LEGACY_FONT_PATH]:
		if ResourceLoader.exists(fp):
			var res := ResourceLoader.load(fp)
			if res is FontFile:
				var ff := res as FontFile
				if use_sys_fallback:
					ff.fallbacks = [sys_font]
				loaded_font = ff
				break
		elif FileAccess.file_exists(fp):
			var ff := FontFile.new()
			var bytes := FileAccess.get_file_as_bytes(fp)
			if not bytes.is_empty():
				ff.data = bytes
				if use_sys_fallback:
					ff.fallbacks = [sys_font]
				loaded_font = ff
				break

	if loaded_font == null:
		loaded_font = sys_font

	_main_font = loaded_font

	var th := Theme.new()
	th.default_font = _main_font
	th.default_font_size = 30

	th.set_color("font_color", "Label", COLOR_PAPER)
	th.set_color("default_color", "RichTextLabel", COLOR_PAPER)
	th.set_color("font_color", "Button", COLOR_PAPER)
	th.set_color("font_hover_color", "Button", COLOR_GOLD)
	th.set_color("font_focus_color", "Button", COLOR_GOLD)
	th.set_color("font_pressed_color", "Button", COLOR_PAPER)

	var btn_normal := _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 21, 12)
	var btn_hover := _make_box_style(Color(0.22, 0.08, 0.09, 0.94), COLOR_GOLD, 1, 21, 12)
	var btn_pressed := _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 21, 12)
	var btn_disabled := _make_box_style(Color(0.06, 0.06, 0.08, 0.65), Color(0.45, 0.40, 0.34, 0.45), 1, 21, 12)
	th.set_stylebox("normal", "Button", btn_normal)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("focus", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_pressed)
	th.set_stylebox("disabled", "Button", btn_disabled)
	th.set_color("font_disabled_color", "Button", Color(0.56, 0.53, 0.48, 0.68))

	# 和風 HSlider スタイル（音量調整用）
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	slider_bg.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.55)
	slider_bg.set_border_width_all(1)
	slider_bg.set_corner_radius_all(4)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = COLOR_CRIMSON
	slider_fill.set_corner_radius_all(4)
	var slider_fill_hi := StyleBoxFlat.new()
	slider_fill_hi.bg_color = COLOR_GOLD
	slider_fill_hi.set_corner_radius_all(4)
	th.set_stylebox("slider", "HSlider", slider_bg)
	th.set_stylebox("grabber_area", "HSlider", slider_fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hi)

	var grab_tex := _make_slider_grabber_tex(22, COLOR_GOLD, COLOR_CRIMSON)
	var grab_hi_tex := _make_slider_grabber_tex(24, COLOR_PAPER, COLOR_GOLD)
	th.set_icon("grabber", "HSlider", grab_tex)
	th.set_icon("grabber_highlight", "HSlider", grab_hi_tex)

	_app_theme = th
	self.theme = _app_theme


func _make_slider_grabber_tex(diameter: int, ring_col: Color, core_col: Color) -> Texture2D:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := float(diameter - 1) * 0.5
	var r_outer := c - 0.5
	var r_inner := r_outer * 0.52
	for y in diameter:
		for x in diameter:
			var dx := float(x) - c
			var dy := float(y) - c
			var d := sqrt(dx * dx + dy * dy)
			if d <= r_inner:
				img.set_pixel(x, y, core_col)
			elif d <= r_outer:
				var a := clampf(r_outer - d + 0.8, 0.0, 1.0)
				img.set_pixel(x, y, Color(ring_col.r, ring_col.g, ring_col.b, a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _make_box_style(bg: Color, border: Color, border_w: int, pad_x: int = 24, pad_y: int = 15) -> StyleBoxFlat:
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


func _setup_audio_pool() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.name = "SePlayer_%d" % i
		_se_players_root.add_child(p)
		_se_pool.append(p)
	_bgm_player.finished.connect(_on_bgm_finished)


func _on_bgm_finished() -> void:
	if not _current_bgm_id.is_empty() and _current_bgm_id != "silence" and _bgm_player.stream != null:
		_bgm_player.play()


func _setup_styles_and_shaders() -> void:
	# タイトル背景
	_title_backdrop = TitleBackdropView.new()
	_title_backdrop.crest_center_ratio = Vector2(0.5, 0.29)
	_title_backdrop.crest_radius = 290.0
	_title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bg_host.add_child(_title_backdrop)

	# フォールバック背景描画
	_fallback_bg_view = FallbackBgView.new()
	_fallback_bg_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_bg_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_fallback_host.add_child(_fallback_bg_view)

	# メッセージウィンドウ：上端が背景に溶け込むグラデーション＋下部墨色
	var grad := Gradient.new()
	grad.set_color(0, Color(COLOR_SUMI_SOLID.r, COLOR_SUMI_SOLID.g, COLOR_SUMI_SOLID.b, 0.0))
	grad.set_color(1, COLOR_SUMI)
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 16
	grad_tex.height = 72
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	_msg_top_fade.texture = grad_tex
	_msg_body_rect.color = COLOR_SUMI

	_gold_divider.color = COLOR_GOLD
	_speaker_label.add_theme_color_override("font_color", COLOR_GOLD)
	_speaker_label.add_theme_font_size_override("font_size", 35)

	_body_text.bbcode_enabled = false
	_body_text.scroll_active = false
	_body_text.fit_content = false
	_body_text.add_theme_font_size_override("normal_font_size", 32)
	_body_text.add_theme_constant_override("line_separation", 12)
	_body_text.add_theme_color_override("default_color", COLOR_PAPER)

	_next_indicator.add_theme_color_override("font_color", COLOR_GOLD)
	_next_indicator.add_theme_font_size_override("font_size", 27)

	# 上部HUD場所パネル
	var loc_sb := _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 27, 15)
	loc_sb.border_width_left = 4
	_location_panel.add_theme_stylebox_override("panel", loc_sb)
	_chapter_label.add_theme_color_override("font_color", COLOR_GOLD)
	_chapter_label.add_theme_font_size_override("font_size", 21)
	_location_label.add_theme_color_override("font_color", COLOR_PAPER)
	_location_label.add_theme_font_size_override("font_size", 26)

	# 透かしラベル
	_bg_watermark.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.30))
	_bg_watermark.add_theme_font_size_override("font_size", 20)

	# 章タイトルバナー
	var banner_panel := $ShakeRoot/GameScreen/ChapterBanner/BannerPanel as PanelContainer
	var banner_sb := _make_box_style(Color(0.043, 0.043, 0.055, 0.86), COLOR_GOLD, 1, 54, 21)
	banner_panel.add_theme_stylebox_override("panel", banner_sb)
	_chapter_banner_label.add_theme_color_override("font_color", COLOR_GOLD)
	_chapter_banner_label.add_theme_font_size_override("font_size", 36)

	# 選択肢ブラーシェーダー
	var blur_shader := Shader.new()
	blur_shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius : hint_range(0.0, 18.0) = 7.5;
uniform vec4 tint_color : source_color = vec4(0.043, 0.043, 0.055, 0.72);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 sum = vec4(0.0);
	sum += texture(screen_texture, SCREEN_UV) * 0.20;
	sum += texture(screen_texture, SCREEN_UV + vec2(ps.x, 0.0)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV - vec2(ps.x, 0.0)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0, ps.y)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV - vec2(0.0, ps.y)) * 0.10;
	sum += texture(screen_texture, SCREEN_UV + vec2(ps.x, ps.y)) * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(-ps.x, ps.y)) * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(ps.x, -ps.y)) * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(-ps.x, -ps.y)) * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(ps.x * 2.0, 0.0)) * 0.025;
	sum += texture(screen_texture, SCREEN_UV - vec2(ps.x * 2.0, 0.0)) * 0.025;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0, ps.y * 2.0)) * 0.025;
	sum += texture(screen_texture, SCREEN_UV - vec2(0.0, ps.y * 2.0)) * 0.025;
	COLOR = vec4(mix(sum.rgb, tint_color.rgb, tint_color.a), 1.0);
}
"""
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = blur_shader
	_choice_blur_rect.material = blur_mat

	# 各種オーバーレイパネル
	var panel_sb := _make_box_style(Color(0.094, 0.094, 0.122, 0.95), COLOR_GOLD, 1, 42, 36)
	_choice_panel.add_theme_stylebox_override("panel", panel_sb)
	_choice_prompt_label.add_theme_color_override("font_color", COLOR_PAPER)
	_choice_prompt_label.add_theme_font_size_override("font_size", 33)

	_backlog_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.07, 0.07, 0.09, 0.95), COLOR_GOLD, 1, 42, 33))
	_gallery_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.07, 0.07, 0.09, 0.96), COLOR_GOLD, 1, 45, 36))
	_confirm_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.094, 0.094, 0.122, 0.96), COLOR_GOLD, 1, 48, 39))

	var end_sb := _make_box_style(Color(0.055, 0.048, 0.062, 0.96), COLOR_GOLD, 3, 72, 57)
	_ending_card_panel.add_theme_stylebox_override("panel", end_sb)
	_ending_num_label.add_theme_color_override("font_color", COLOR_GOLD)
	_ending_num_label.add_theme_font_size_override("font_size", 30)
	_ending_title_label.add_theme_color_override("font_color", COLOR_PAPER)
	_ending_title_label.add_theme_font_size_override("font_size", 60)
	_ending_sub_label.add_theme_color_override("font_color", COLOR_GOLD)
	_ending_sub_label.add_theme_font_size_override("font_size", 30)

	# 映画風ビネット＆環境色調グレーディング（背景＋キャラの上・パーティクルの下）
	var vig_shader := Shader.new()
	vig_shader.code = """
shader_type canvas_item;

uniform vec4 edge_tint : source_color = vec4(0.03, 0.03, 0.05, 0.42);
uniform vec4 bottom_glow : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float vig_strength : hint_range(0.0, 1.0) = 0.44;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv * vec2(1.0, 0.82));
	float vig = smoothstep(0.32, 0.82, dist) * vig_strength;
	float bot = smoothstep(0.55, 1.0, UV.y) * bottom_glow.a;
	vec3 rgb = mix(edge_tint.rgb, bottom_glow.rgb, clamp(bot / max(vig + bot, 0.001), 0.0, 1.0));
	COLOR = vec4(rgb, clamp(vig + bot, 0.0, 0.72));
}
"""
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = vig_shader
	_vignette_rect = ColorRect.new()
	_vignette_rect.name = "CinematicVignette"
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.material = _vignette_mat
	_game_screen.add_child(_vignette_rect)
	_game_screen.move_child(_vignette_rect, _atmosphere_particles.get_index())

	_bg_texture_rect.resized.connect(func() -> void:
		_bg_texture_rect.pivot_offset = _bg_texture_rect.size * 0.5
	)
	_bg_texture_rect.pivot_offset = Vector2(960.0, 540.0)

	# タイトルボタン文字サイズ
	_start_button.add_theme_font_size_override("font_size", 30)
	_gallery_button.add_theme_font_size_override("font_size", 25)
	_version_label.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.65))
	_version_label.add_theme_font_size_override("font_size", 21)

	# 上部HUDボタンはテキスト送りのSpace/Enterを奪わないようフォーカス対象外にする
	_backlog_button.focus_mode = Control.FOCUS_NONE
	_auto_button.focus_mode = Control.FOCUS_NONE
	_title_return_button.focus_mode = Control.FOCUS_NONE

	_update_auto_button_visual()


func _setup_character_slots() -> void:
	for pair in [["left", _left_slot], ["right", _right_slot]]:
		var side: String = pair[0]
		var slot: Control = pair[1]
		_slot_base_pos[side] = slot.position
		slot.visible = false
		slot.modulate = Color(1, 1, 1, 0)
		slot.scale = Vector2(0.98, 0.98)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.resized.connect(_update_slot_pivot.bind(slot))
		_update_slot_pivot(slot)

		var prev_tex_rect := TextureRect.new()
		prev_tex_rect.name = "PrevSpriteTexture"
		prev_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		prev_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prev_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev_tex_rect.visible = false
		slot.add_child(prev_tex_rect)

		var tex_rect := TextureRect.new()
		tex_rect.name = "SpriteTexture"
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex_rect)

		var card := CharacterCardView.new()
		card.name = "FallbackCard"
		card.font = _main_font
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 1.0
		card.anchor_bottom = 1.0
		card.offset_left = -195.0
		card.offset_right = 195.0
		card.offset_top = -651.0
		card.offset_bottom = -6.0
		card.custom_minimum_size = Vector2(390, 645)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(card)

		_sprite_slots[side] = {
			"slot": slot,
			"prev_tex_rect": prev_tex_rect,
			"tex_rect": tex_rect,
			"card": card,
			"char_id": "",
			"active": false,
			"visible": false,
		}


func _setup_qol_ui() -> void:
	_prelude_tag = $ShakeRoot/TitleScreen/PreludeTag as Label
	_gallery_title_label = $ShakeRoot/EndingGalleryOverlay/GalleryCenter/GalleryPanel/GalleryMargin/GalleryVBox/GalleryHeader/GalleryTitle as Label

	_title_art_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_art_host.offset_left = 0.0
	_title_art_host.offset_top = 0.0
	_title_art_host.offset_right = 0.0
	_title_art_host.offset_bottom = 0.0

	_title_episode_logo = TextureRect.new()
	_title_episode_logo.name = "EpisodeTitleLogo"
	_title_episode_logo.position = Vector2(430, 56)
	_title_episode_logo.size = Vector2(1060, 506)
	_title_episode_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_episode_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_episode_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_episode_logo.visible = false
	_title_screen.add_child(_title_episode_logo)
	_title_screen.move_child(_title_episode_logo, _prelude_tag.get_index())

	if _prelude_tag != null:
		_prelude_tag.offset_left = 260.0
		_prelude_tag.offset_right = 1660.0
		_prelude_tag.offset_top = 568.0
		_prelude_tag.offset_bottom = 608.0
		_prelude_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prelude_tag.add_theme_font_size_override("font_size", 22)
		_prelude_tag.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.88))

	# 1. 第1弾（各作品）タイトル下部：7ボタンを 2 + 4 + 1 の対称構成で中央配置
	var old_menu_box := $ShakeRoot/TitleScreen/MenuBox as VBoxContainer
	old_menu_box.visible = false

	var controls_hint := $ShakeRoot/TitleScreen/ControlsHint as Label
	if controls_hint != null:
		controls_hint.offset_left = 96.0
		controls_hint.offset_right = 1520.0
		controls_hint.text = "操作：クリック / Space / Enter 進行　[H] 履歴　[A] 自動　[S/Ctrl] スキップ　[Q/L] 急速記録・再開　[M/右] 枠消去"

	_ep_menu_host = VBoxContainer.new()
	_ep_menu_host.name = "EpisodeBottomMenuHost"
	_ep_menu_host.position = Vector2(260, 628)
	_ep_menu_host.size = Vector2(1400, 290)
	_ep_menu_host.add_theme_constant_override("separation", 18)
	_title_screen.add_child(_ep_menu_host)

	var top_rule := ColorRect.new()
	top_rule.custom_minimum_size = Vector2(880, 1)
	top_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_rule.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.34)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ep_menu_host.add_child(top_rule)

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 26)
	_ep_menu_host.add_child(row1)

	old_menu_box.remove_child(_start_button)
	_start_button.custom_minimum_size = Vector2(440, 68)
	_start_button.add_theme_font_size_override("font_size", 26)
	row1.add_child(_start_button)

	_continue_button = _make_title_btn("栞から再開（続きから）", 24, 68)
	_continue_button.custom_minimum_size = Vector2(440, 68)
	_continue_button.clip_text = true
	_continue_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row1.add_child(_continue_button)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 18)
	_ep_menu_host.add_child(row2)

	_load_menu_button = _make_title_btn("記録帳（読込）", 21, 56)
	_load_menu_button.custom_minimum_size = Vector2(260, 56)
	row2.add_child(_load_menu_button)

	_chapter_menu_button = _make_title_btn("歴史年表（0/11）", 21, 56)
	_chapter_menu_button.custom_minimum_size = Vector2(290, 56)
	row2.add_child(_chapter_menu_button)

	old_menu_box.remove_child(_gallery_button)
	_gallery_button.custom_minimum_size = Vector2(270, 56)
	_gallery_button.add_theme_font_size_override("font_size", 21)
	row2.add_child(_gallery_button)

	_settings_menu_button = _make_title_btn("環境設定", 21, 56)
	_settings_menu_button.custom_minimum_size = Vector2(240, 56)
	row2.add_child(_settings_menu_button)

	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	_ep_menu_host.add_child(row3)

	_portal_return_button = _make_title_btn("シリーズ選択（時代一覧）へ戻る", 21, 52)
	_portal_return_button.custom_minimum_size = Vector2(420, 52)
	row3.add_child(_portal_return_button)

	_style_title_menu_button(_start_button, true)
	for b in [_continue_button, _load_menu_button, _chapter_menu_button, _gallery_button, _settings_menu_button, _portal_return_button]:
		_style_title_menu_button(b as Button, false)

	# 2. ゲーム画面 TopHUD ボタン拡充（履歴・自動・スキップ・記録・設定・音切替・タイトルへ）
	var hud_btns := $ShakeRoot/GameScreen/TopHUD/HudButtons as HBoxContainer
	hud_btns.offset_left = -1210.0
	hud_btns.offset_right = -36.0
	hud_btns.add_theme_constant_override("separation", 10)

	_skip_button = _make_hud_btn("スキップ")
	hud_btns.add_child(_skip_button)
	hud_btns.move_child(_skip_button, 2)

	_record_button = _make_hud_btn("記録")
	hud_btns.add_child(_record_button)
	hud_btns.move_child(_record_button, 3)

	_settings_hud_button = _make_hud_btn("設定")
	hud_btns.add_child(_settings_hud_button)
	hud_btns.move_child(_settings_hud_button, 4)

	_mute_hud_button = _make_hud_btn("音：入")
	hud_btns.add_child(_mute_hud_button)
	hud_btns.move_child(_mute_hud_button, 5)

	for b in [_backlog_button, _auto_button, _skip_button, _record_button, _settings_hud_button, _mute_hud_button, _title_return_button]:
		(b as Button).add_theme_font_size_override("font_size", 22)
		(b as Button).focus_mode = Control.FOCUS_NONE
	_apply_hud_compact_styles()

	# 3. 終幕録グリッドを5エンド対応のため縦スクロール可能にラップ
	if _gallery_grid != null:
		var gallery_vbox := _gallery_grid.get_parent()
		if gallery_vbox != null:
			var gallery_scroll := ScrollContainer.new()
			gallery_scroll.name = "GalleryScroll"
			gallery_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gallery_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			gallery_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var grid_idx := _gallery_grid.get_index()
			gallery_vbox.add_child(gallery_scroll)
			gallery_vbox.move_child(gallery_scroll, grid_idx)
			_gallery_grid.reparent(gallery_scroll)
			_gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_gallery_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# 4. メッセージ枠内の既読バッジ＆操作ヒントバー
	var spk_spacer := Control.new()
	spk_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spk_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_row.add_child(spk_spacer)

	_read_badge = Label.new()
	_read_badge.text = "◆ 既読"
	_read_badge.visible = false
	_read_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_badge.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.85))
	_read_badge.add_theme_font_size_override("font_size", 20)
	_speaker_row.add_child(_read_badge)

	var msg_vbox := $ShakeRoot/GameScreen/MessageWindow/ContentMargin/VBox as VBoxContainer
	_shortcut_hint = Label.new()
	_shortcut_hint.text = "Click/Space: 進む　|　H/上ホイール: 履歴　|　A: 自動　|　S/Ctrl: スキップ　|　Q: 急速記録　|　M/右クリック: 枠消去"
	_shortcut_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shortcut_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut_hint.add_theme_color_override("font_color", Color(COLOR_MUTED.r, COLOR_MUTED.g, COLOR_MUTED.b, 0.56))
	_shortcut_hint.add_theme_font_size_override("font_size", 17)
	msg_vbox.add_child(_shortcut_hint)

	# 5. 記録帳・章選択・設定オーバーレイ追加
	_qol_overlays = QolOverlays.new()
	_qol_overlays.name = "QolOverlays"
	_qol_overlays.setup(_save_store, _scenes)
	_shake_root.add_child(_qol_overlays)
	_shake_root.move_child(_qol_overlays, _flash_overlay.get_index())

	_update_skip_button_visual()
	_update_mute_button_visual()


func _make_title_btn(txt: String, font_sz: int, min_h: int) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(570, min_h)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.mouse_entered.connect(func() -> void:
		_play_sm_se("ui_hover", 0.42)
	)
	return btn


func _style_title_menu_button(btn: Button, is_primary: bool) -> void:
	if btn == null:
		return
	var norm_border := Color(COLOR_CRIMSON.r, COLOR_CRIMSON.g, COLOR_CRIMSON.b, 0.92) if is_primary else Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.48)
	var norm_bg := Color(0.14, 0.075, 0.085, 0.92) if is_primary else COLOR_SUMI
	var sb_norm := _make_box_style(norm_bg, norm_border, 1, 24, 12)
	sb_norm.border_width_left = 5
	var sb_hi := _make_box_style(Color(0.24, 0.08, 0.09, 0.96), COLOR_GOLD, 1, 24, 12)
	sb_hi.border_width_left = 5
	var sb_press := _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 24, 12)
	sb_press.border_width_left = 5
	var sb_dis := _make_box_style(Color(0.06, 0.06, 0.08, 0.62), Color(0.42, 0.38, 0.32, 0.38), 1, 24, 12)
	sb_dis.border_width_left = 5
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hi)
	btn.add_theme_stylebox_override("focus", sb_hi)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("disabled", sb_dis)


func _make_hud_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_entered.connect(func() -> void:
		_play_sm_se("ui_hover", 0.35)
	)
	return btn


func _apply_hud_compact_styles() -> void:
	var sb_norm := _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 16, 10)
	var sb_hov := _make_box_style(Color(0.22, 0.08, 0.09, 0.94), COLOR_GOLD, 1, 16, 10)
	var sb_prs := _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 16, 10)
	for b in [_backlog_button, _auto_button, _skip_button, _record_button, _settings_hud_button, _mute_hud_button, _title_return_button]:
		var btn := b as Button
		btn.add_theme_stylebox_override("normal", sb_norm)
		btn.add_theme_stylebox_override("hover", sb_hov)
		btn.add_theme_stylebox_override("focus", sb_hov)
		btn.add_theme_stylebox_override("pressed", sb_prs)


func _update_slot_pivot(slot: Control) -> void:
	slot.pivot_offset = Vector2(slot.size.x * 0.5, slot.size.y)


func _connect_signals() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.mouse_entered.connect(func() -> void:
		_play_sm_se("ui_hover", 0.42)
	)
	_continue_button.pressed.connect(_on_continue_pressed)
	_load_menu_button.pressed.connect(_on_open_load_menu)
	_chapter_menu_button.pressed.connect(_on_open_chapter_menu)
	_gallery_button.pressed.connect(_on_open_gallery_pressed)
	_gallery_button.mouse_entered.connect(func() -> void:
		_play_sm_se("ui_hover", 0.42)
	)
	_settings_menu_button.pressed.connect(_on_open_settings_pressed)
	_portal_return_button.pressed.connect(_on_portal_return_pressed)

	if _main_series_btn != null:
		_main_series_btn.pressed.connect(_on_open_series_select_pressed)
	if _main_continue_btn != null:
		_main_continue_btn.pressed.connect(_on_open_load_menu)
	if _main_gallery_btn != null:
		_main_gallery_btn.pressed.connect(_on_open_portal_gallery_pressed)
	if _main_settings_btn != null:
		_main_settings_btn.pressed.connect(_on_open_settings_pressed)
	if _portal_back_btn != null:
		_portal_back_btn.pressed.connect(_on_main_title_return_pressed)

	_click_advance_layer.gui_input.connect(_on_click_advance_gui_input)
	_backlog_button.pressed.connect(_on_backlog_pressed)
	_auto_button.pressed.connect(_on_auto_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_record_button.pressed.connect(_on_record_pressed)
	_settings_hud_button.pressed.connect(_on_open_settings_pressed)
	_mute_hud_button.pressed.connect(_on_mute_pressed)
	_title_return_button.pressed.connect(_on_title_return_pressed)

	_qol_overlays.save_slot_requested.connect(_on_qol_save_slot)
	_qol_overlays.load_slot_requested.connect(_on_qol_load_slot)
	_qol_overlays.delete_slot_requested.connect(_on_qol_delete_slot)
	_qol_overlays.chapter_selected.connect(_on_qol_chapter_selected)
	_qol_overlays.settings_changed.connect(_on_settings_changed)
	_qol_overlays.test_se_requested.connect(func() -> void:
		_play_sm_se("ui_confirm", 0.85)
	)
	_qol_overlays.reset_all_save_requested.connect(_on_qol_reset_all_save)
	_qol_overlays.overlay_closed.connect(_on_qol_overlay_closed)

	_backlog_close_btn.pressed.connect(_close_backlog)
	_gallery_close_btn.pressed.connect(_close_gallery)
	_ending_gallery_btn.pressed.connect(_on_ending_to_gallery)
	_ending_title_btn.pressed.connect(_on_ending_to_title)

	_confirm_yes_btn.pressed.connect(_confirm_return_to_title)
	_confirm_no_btn.pressed.connect(_close_confirm_overlay)

	_backlog_dim.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click_pressed(event):
			_close_backlog()
	)
	_gallery_dim.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click_pressed(event):
			_close_gallery()
	)
	_confirm_dim.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click_pressed(event):
			_close_confirm_overlay()
	)


func _is_left_click_pressed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	return false


func _get_game_manager() -> Node:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		return gm
	if _fallback_gm == null:
		_fallback_gm = GameManagerScript.new()
		_fallback_gm.call("load_catalog")
	return _fallback_gm


func _get_sound_manager() -> Node:
	return get_node_or_null("/root/SoundManager")


func _is_sound_muted() -> bool:
	var sm := _get_sound_manager()
	return sm != null and bool(sm.get("muted"))


func _set_ambient_safe(ambient_type: String) -> void:
	var sm := _get_sound_manager()
	if sm != null:
		sm.call("set_ambient", ambient_type)


func _play_sm_se(se_key: String, volume_scale: float = 1.0) -> void:
	if _is_sound_muted():
		return
	if _save_store.get_se_gain_db() <= -79.0:
		return
	var sm := _get_sound_manager()
	if sm != null:
		sm.call("play_se", se_key, volume_scale)
	else:
		_play_synth_se(se_key, linear_to_db(clampf(volume_scale, 0.01, 1.0)))


func _play_voice_safe(voice_key: String, volume_scale: float = 1.0) -> void:
	if voice_key.is_empty() or _is_sound_muted():
		return
	var sm := _get_sound_manager()
	if sm != null:
		sm.call("play_voice", voice_key, volume_scale)


func _stop_voice_safe() -> void:
	var sm := _get_sound_manager()
	if sm != null:
		sm.call("stop_voice")


func _resolve_episode_path(raw_path: String) -> String:
	var gm := _get_game_manager()
	return str(gm.call("resolve_asset_path", raw_path, _current_episode_dir))


func _init_default_episode_context() -> void:
	var gm := _get_game_manager()
	var eps: Array = gm.call("get_episodes") as Array
	for item in eps:
		if item is Dictionary and bool((item as Dictionary).get("available", false)):
			_load_episode_data(item as Dictionary)
			return
	if not eps.is_empty() and eps[0] is Dictionary:
		_load_episode_data(eps[0] as Dictionary)


func _load_episode_data(ep_info: Dictionary) -> bool:
	var gm := _get_game_manager()
	if not bool(gm.call("load_episode", ep_info)):
		return false

	_current_episode = ep_info.duplicate(true)
	_current_episode_id = str(_current_episode.get("id", SaveStore.DEFAULT_EPISODE_ID))
	_current_episode_dir = str(_current_episode.get("dir", "res://episodes/01_nobunaga"))
	_save_store.set_active_episode(_current_episode_id)
	_unlocked_endings = _save_store.unlocked_endings

	var raw_scen: Variant = gm.get("current_scenario")
	if not (raw_scen is Dictionary):
		return false
	_scenario_data = raw_scen as Dictionary
	_meta = _scenario_data.get("meta", {})
	_assets_cfg = _scenario_data.get("assets", {})
	_scenes = _scenario_data.get("scenes", {})
	_version_label.text = "Ver %s" % str(_meta.get("version", "1.0.0"))

	if _prelude_tag != null:
		var yr := str(_current_episode.get("year", ""))
		var prot := str(_current_episode.get("protagonist", ""))
		if _current_episode_id == "01_nobunaga":
			_prelude_tag.text = "天正十年 六月二日 黎明 ― 織田信長 生存異聞"
		else:
			_prelude_tag.text = "%s ― %s 生存異聞" % [yr, prot]
		_prelude_tag.offset_left = 260.0
		_prelude_tag.offset_right = 1660.0
		_prelude_tag.offset_top = 568.0
		_prelude_tag.offset_bottom = 608.0

	if _title_episode_logo != null:
		var logo_raw := str(_current_episode.get("logo", _meta.get("logo", "assets/title_logo.png")))
		var logo_tex := _load_texture_safe(logo_raw)
		if logo_tex != null:
			_title_episode_logo.texture = logo_tex
			_title_episode_logo.visible = true
		else:
			_title_episode_logo.texture = null
			_title_episode_logo.visible = false

	_endings_catalog.clear()
	for scene_id in _scenes.keys():
		var sc: Dictionary = _scenes[scene_id]
		if sc.has("ending"):
			var ed: Dictionary = sc["ending"].duplicate(true)
			ed["scene_id"] = scene_id
			ed["location"] = sc.get("location", "")
			_endings_catalog.append(ed)
	_endings_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	if _qol_overlays != null:
		_qol_overlays.set_scenes(_scenes, _current_episode_id)
	_build_title_art()
	return true


func _load_save_data() -> void:
	_save_store.load_from_disk()
	_sync_slots_from_game_manager()
	_unlocked_endings = _save_store.unlocked_endings


func _sync_slots_from_game_manager() -> void:
	var gm := _get_game_manager()
	var gm_slots_val: Variant = gm.get("save_slots")
	if not (gm_slots_val is Dictionary):
		return
	var gm_slots := gm_slots_val as Dictionary
	if gm_slots.is_empty():
		return
	var prev_ep := _save_store.get_active_episode_id()
	for slot_id in ["1", "2", "3"]:
		var raw: Variant = gm_slots.get(slot_id, null)
		if not (raw is Dictionary) or (raw as Dictionary).is_empty():
			continue
		var rec := raw as Dictionary
		var ep_id := str(rec.get("episode_id", SaveStore.DEFAULT_EPISODE_ID))
		if ep_id.is_empty():
			ep_id = SaveStore.DEFAULT_EPISODE_ID
		_save_store.set_active_episode(ep_id)
		if not _save_store.has_slot(slot_id):
			var normalized := rec.duplicate(true)
			if not normalized.has("saved_at") and normalized.has("timestamp"):
				normalized["saved_at"] = str(normalized["timestamp"])
			if not normalized.has("line_index") and normalized.has("line_idx"):
				normalized["line_index"] = int(normalized["line_idx"])
			if not normalized.has("excerpt") and normalized.has("preview_text"):
				normalized["excerpt"] = str(normalized["preview_text"])
			if not normalized.has("title") and normalized.has("episode_title"):
				normalized["title"] = str(normalized["episode_title"])
			if not normalized.has("session_flags") and normalized.has("flags"):
				normalized["session_flags"] = (normalized["flags"] as Dictionary).duplicate(true) if normalized["flags"] is Dictionary else {}
			_save_store.slots[slot_id] = normalized
			_save_store._dirty = true
	_save_store.set_active_episode(prev_ep)


func _save_data() -> void:
	_save_store.save_to_disk()


func _unlock_ending(ending_id: String) -> void:
	if ending_id.is_empty():
		return
	_save_store.unlock_ending(ending_id)
	_get_game_manager().call("unlock_ending", _current_episode_id, ending_id)
	_unlocked_endings = _save_store.unlocked_endings
	_refresh_gallery_button_text()


func _refresh_gallery_button_text() -> void:
	var total := int(_meta.get("totalEndings", max(_endings_catalog.size(), 5)))
	_gallery_button.text = "終幕録（%d/%d）" % [_unlocked_endings.size(), total]


func _refresh_title_menu() -> void:
	_refresh_gallery_button_text()
	var latest := _save_store.get_latest_save()
	if latest.is_empty():
		_continue_button.text = "栞から再開（記録なし）"
		_continue_button.disabled = true
	else:
		var data: Dictionary = latest["data"]
		var chap := str(data.get("title", ""))
		_continue_button.text = "栞から再開 ― %s" % chap
		_continue_button.disabled = false

	var ordered_count := _scenes.size() if _scenes.size() > 0 else SaveStore.CHAPTER_ORDER.size()
	var vis_cnt := _save_store.visited_scenes.size()
	_chapter_menu_button.text = "歴史年表（%d/%d）" % [vis_cnt, ordered_count]


func _build_title_art() -> void:
	for c in _title_art_host.get_children():
		c.queue_free()

	# タイトルロゴ画像がある場合はロゴ中心表示を妨げないよう文字タイトルは生成しない
	if _title_episode_logo != null and _title_episode_logo.visible:
		return

	var fb_box := VBoxContainer.new()
	fb_box.position = Vector2(360, 180)
	fb_box.size = Vector2(1200, 320)
	fb_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fb_box.add_theme_constant_override("separation", 18)
	fb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_art_host.add_child(fb_box)

	var ep_title_lbl := Label.new()
	ep_title_lbl.text = str(_current_episode.get("title", "本能寺・残照録"))
	ep_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ep_title_lbl.add_theme_color_override("font_color", COLOR_PAPER)
	ep_title_lbl.add_theme_font_size_override("font_size", 76)
	fb_box.add_child(ep_title_lbl)

	var ep_sub_lbl := Label.new()
	ep_sub_lbl.text = str(_current_episode.get("subtitle", ""))
	ep_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ep_sub_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	ep_sub_lbl.add_theme_font_size_override("font_size", 32)
	fb_box.add_child(ep_sub_lbl)


# --- メインタイトル画面（ロゴ中心の最小構成） ---

func _setup_main_title_ui() -> void:
	_main_title_screen = Control.new()
	_main_title_screen.name = "MainTitleScreen"
	_main_title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_title_screen.visible = false
	_shake_root.add_child(_main_title_screen)
	_shake_root.move_child(_main_title_screen, _title_screen.get_index() + 1)

	_main_title_backdrop = TitleBackdropView.new()
	_main_title_backdrop.crest_center_ratio = Vector2(0.5, 0.39)
	_main_title_backdrop.crest_radius = 365.0
	_main_title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_title_screen.add_child(_main_title_backdrop)

	_main_title_particles = AtmosphericEffects.new()
	_main_title_particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_title_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_title_screen.add_child(_main_title_particles)

	var gm := _get_game_manager()
	var cat: Dictionary = gm.get("catalog_data") as Dictionary
	var series_logo_path := str(cat.get("series_logo", "res://common_assets/logo_series.png"))

	# 中央：シリーズメインロゴ（大きく主役配置）
	var logo_tex := gm.call("load_texture_safe", series_logo_path) as Texture2D
	if logo_tex != null:
		_main_title_logo = TextureRect.new()
		_main_title_logo.name = "MainSeriesLogoTexture"
		_main_title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_main_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_main_title_logo.position = Vector2(430, 128)
		_main_title_logo.size = Vector2(1060, 600)
		_main_title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main_title_logo.texture = logo_tex
		_main_title_screen.add_child(_main_title_logo)
	else:
		var fb_title := Label.new()
		fb_title.text = str(cat.get("series_title", "IF : SURVIVE"))
		fb_title.position = Vector2(360, 340)
		fb_title.size = Vector2(1200, 120)
		fb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb_title.add_theme_color_override("font_color", COLOR_GOLD)
		fb_title.add_theme_font_size_override("font_size", 82)
		_main_title_screen.add_child(fb_title)

	# 下部中央：最小限のボタン群
	var btn_vbox := VBoxContainer.new()
	btn_vbox.position = Vector2(520, 760)
	btn_vbox.size = Vector2(880, 170)
	btn_vbox.add_theme_constant_override("separation", 20)
	_main_title_screen.add_child(btn_vbox)

	_main_series_btn = _make_title_btn("シリーズ・時代選択", 27, 70)
	_main_series_btn.custom_minimum_size = Vector2(460, 70)
	_main_series_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_title_menu_button(_main_series_btn, true)
	btn_vbox.add_child(_main_series_btn)

	var sub_btns := HBoxContainer.new()
	sub_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_btns.add_theme_constant_override("separation", 20)
	btn_vbox.add_child(sub_btns)

	_main_continue_btn = _make_title_btn("途上より（記録再開）", 21, 54)
	_main_continue_btn.custom_minimum_size = Vector2(280, 54)
	_style_title_menu_button(_main_continue_btn, false)
	sub_btns.add_child(_main_continue_btn)

	_main_gallery_btn = _make_title_btn("シリーズ終幕録", 21, 54)
	_main_gallery_btn.custom_minimum_size = Vector2(240, 54)
	_style_title_menu_button(_main_gallery_btn, false)
	sub_btns.add_child(_main_gallery_btn)

	_main_settings_btn = _make_title_btn("環境設定", 21, 54)
	_main_settings_btn.custom_minimum_size = Vector2(240, 54)
	_style_title_menu_button(_main_settings_btn, false)
	sub_btns.add_child(_main_settings_btn)


func _show_main_title_screen() -> void:
	_stop_voice_safe()
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_save_store.flush_if_dirty()
	_in_game = false
	_is_transitioning = false
	_auto_mode = false
	_skip_mode = false
	_at_choices = false
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = false
	_last_speaker_key = ""
	_current_effect_name = ""
	_mood_bgm_id = ""
	_shake_timer = 0.0
	_bg_impact_zoom = 0.0
	_shake_root.position = Vector2.ZERO
	_bg_fade_rect.color.a = 0.0
	_flash_overlay.visible = false
	_chapter_banner.visible = false
	_set_ui_hidden(false)
	_update_auto_button_visual()
	_update_skip_button_visual()

	_game_screen.visible = false
	_title_screen.visible = false
	if _portal_screen != null:
		_portal_screen.visible = false
	if _portal_particles != null:
		_portal_particles.set_effect("none", true)
	_choice_overlay.visible = false
	_backlog_overlay.visible = false
	_ending_card_overlay.visible = false
	_gallery_overlay.visible = false
	_confirm_overlay.visible = false
	if _qol_overlays != null:
		while _qol_overlays.close_top_overlay():
			pass

	_main_title_screen.visible = true
	_main_title_particles.set_effect("embers", true)
	_title_particles.set_effect("none", true)
	_atmosphere_particles.set_effect("none", true)
	_set_ambient_safe("none")
	_play_bgm("title_theme")

	if _main_title_logo != null:
		_main_title_logo.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_main_title_logo, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

	_focus_control(_main_series_btn)


func _on_open_series_select_pressed() -> void:
	_play_sm_se("ui_confirm", 0.85)
	_show_portal_screen()


func _on_main_title_return_pressed() -> void:
	_play_ui_click()
	_show_main_title_screen()


# --- シリーズ選択画面（IF : SURVIVE） ---

func _setup_portal_ui() -> void:
	_portal_screen = Control.new()
	_portal_screen.name = "SeriesPortalScreen"
	_portal_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portal_screen.visible = false
	_shake_root.add_child(_portal_screen)
	_shake_root.move_child(_portal_screen, _title_screen.get_index() + 1)

	_portal_backdrop = TitleBackdropView.new()
	_portal_backdrop.crest_center_ratio = Vector2(0.84, 0.50)
	_portal_backdrop.crest_radius = 310.0
	_portal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portal_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal_screen.add_child(_portal_backdrop)

	_portal_particles = AtmosphericEffects.new()
	_portal_particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portal_particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal_screen.add_child(_portal_particles)

	var gm := _get_game_manager()
	var cat: Dictionary = gm.get("catalog_data") as Dictionary
	var series_title := str(cat.get("series_title", "IF : SURVIVE"))
	var emblem_path := str(cat.get("emblem", "res://common_assets/emblem_kamon.png"))

	# 上部ヘッダー
	var header := HBoxContainer.new()
	header.position = Vector2(144, 68)
	header.size = Vector2(1632, 74)
	header.add_theme_constant_override("separation", 20)
	_portal_screen.add_child(header)

	var kamon_tex := gm.call("load_texture_safe", emblem_path) as Texture2D
	if kamon_tex != null:
		var kamon_rect := TextureRect.new()
		kamon_rect.texture = kamon_tex
		kamon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		kamon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		kamon_rect.custom_minimum_size = Vector2(62, 62)
		kamon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kamon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(kamon_rect)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "時代・人物選択 ― %s" % series_title
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	hdr_lbl.add_theme_font_size_override("font_size", 36)
	header.add_child(hdr_lbl)

	_portal_stats_lbl = Label.new()
	_portal_stats_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portal_stats_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_portal_stats_lbl.add_theme_font_size_override("font_size", 21)
	header.add_child(_portal_stats_lbl)

	_portal_back_btn = _make_title_btn("メインタイトルへ戻る", 21, 52)
	_portal_back_btn.custom_minimum_size = Vector2(270, 52)
	_portal_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_title_menu_button(_portal_back_btn, false)
	header.add_child(_portal_back_btn)

	var h_line := ColorRect.new()
	h_line.position = Vector2(144, 152)
	h_line.size = Vector2(1632, 2)
	h_line.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.45)
	h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal_screen.add_child(h_line)

	# 中央：広々としたエピソード一覧
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(160, 174)
	scroll.size = Vector2(1600, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_portal_screen.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(pad)

	_portal_cards_box = VBoxContainer.new()
	_portal_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portal_cards_box.add_theme_constant_override("separation", 22)
	pad.add_child(_portal_cards_box)

	var footer_hint := Label.new()
	footer_hint.position = Vector2(160, 986)
	footer_hint.size = Vector2(1600, 36)
	footer_hint.text = "操作：作品カードから「この時代を紐解く」を選択　|　[Esc] メインタイトルへ戻る"
	footer_hint.add_theme_color_override("font_color", Color(COLOR_MUTED.r, COLOR_MUTED.g, COLOR_MUTED.b, 0.78))
	footer_hint.add_theme_font_size_override("font_size", 20)
	_portal_screen.add_child(footer_hint)


func _show_portal_screen() -> void:
	_stop_voice_safe()
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_save_store.flush_if_dirty()
	_in_game = false
	_is_transitioning = false
	_auto_mode = false
	_skip_mode = false
	_at_choices = false
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = false
	_last_speaker_key = ""
	_current_effect_name = ""
	_mood_bgm_id = ""
	_shake_timer = 0.0
	_bg_impact_zoom = 0.0
	_shake_root.position = Vector2.ZERO
	_bg_fade_rect.color.a = 0.0
	_flash_overlay.visible = false
	_chapter_banner.visible = false
	_set_ui_hidden(false)
	_update_auto_button_visual()
	_update_skip_button_visual()

	_game_screen.visible = false
	_title_screen.visible = false
	if _main_title_screen != null:
		_main_title_screen.visible = false
	if _main_title_particles != null:
		_main_title_particles.set_effect("none", true)
	_choice_overlay.visible = false
	_backlog_overlay.visible = false
	_ending_card_overlay.visible = false
	_gallery_overlay.visible = false
	_confirm_overlay.visible = false
	if _qol_overlays != null:
		while _qol_overlays.close_top_overlay():
			pass

	_portal_screen.visible = true
	_portal_particles.set_effect("embers", true)
	_title_particles.set_effect("none", true)
	_atmosphere_particles.set_effect("none", true)
	_set_ambient_safe("none")
	_play_bgm("title_theme")
	_refresh_portal_cards()


func _refresh_portal_cards() -> void:
	for c in _portal_cards_box.get_children():
		c.queue_free()

	var gm := _get_game_manager()
	var episodes: Array = gm.call("get_episodes") as Array
	var available_cnt := 0
	var total_unlocked := 0
	var first_play_btn: Button = null

	for item in episodes:
		if not (item is Dictionary):
			continue
		var ep := item as Dictionary
		var ep_id := str(ep.get("id", ""))
		var avail := bool(ep.get("available", false))
		if avail:
			available_cnt += 1
		total_unlocked += _save_store.get_episode_unlocked_endings(ep_id).size()
		var card_res := _create_portal_episode_card(ep)
		_portal_cards_box.add_child(card_res["card"] as Control)
		if first_play_btn == null and card_res.get("play_btn", null) != null:
			first_play_btn = card_res["play_btn"] as Button

	_portal_stats_lbl.text = "収録 %d/%d 篇公開中　|　シリーズ累計終幕：%d" % [available_cnt, episodes.size(), total_unlocked]
	if first_play_btn != null:
		_focus_control(first_play_btn)
	elif _portal_back_btn != null:
		_focus_control(_portal_back_btn)


func _create_portal_episode_card(ep: Dictionary) -> Dictionary:
	var ep_id := str(ep.get("id", ""))
	var avail := bool(ep.get("available", false))
	var accent := Color(str(ep.get("accent_color", "#9E1B1B")))
	var unlocked_cnt := _save_store.get_episode_unlocked_endings(ep_id).size()
	var visited_cnt := _save_store.get_episode_visited_count(ep_id)
	var has_save := _save_store.has_episode_any_save(ep_id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_col := Color(0.095, 0.09, 0.12, 0.94) if avail else Color(0.055, 0.055, 0.075, 0.84)
	var border_col := Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.65) if avail else Color(0.32, 0.30, 0.28, 0.45)
	var sb := _make_box_style(bg_col, border_col, 1, 30, 22)
	sb.border_width_left = 6
	sb.border_color = accent if avail else Color(accent.r, accent.g, accent.b, 0.35)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	var era_lbl := Label.new()
	era_lbl.text = "【%s】 %s ―― 主人公：%s" % [str(ep.get("era", "")), str(ep.get("year", "")), str(ep.get("protagonist", ""))]
	era_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	era_lbl.add_theme_color_override("font_color", COLOR_GOLD if avail else COLOR_MUTED)
	era_lbl.add_theme_font_size_override("font_size", 21)
	top_row.add_child(era_lbl)

	if avail and has_save:
		var save_badge := Label.new()
		save_badge.text = "【栞記録あり】"
		save_badge.add_theme_color_override("font_color", COLOR_GOLD.lightened(0.15))
		save_badge.add_theme_font_size_override("font_size", 20)
		top_row.add_child(save_badge)

	var status_lbl := Label.new()
	if avail:
		var total_ends := int(ep.get("total_endings", _get_game_manager().call("get_total_endings", ep_id)))
		status_lbl.text = "終幕 %d / %d　|　既読章 %d" % [unlocked_cnt, total_ends, visited_cnt]
		status_lbl.add_theme_color_override("font_color", COLOR_GOLD if unlocked_cnt >= total_ends else (COLOR_PAPER if unlocked_cnt > 0 else COLOR_MUTED))
	else:
		status_lbl.text = "【準備中】"
		status_lbl.add_theme_color_override("font_color", Color(0.58, 0.55, 0.50, 0.78))
	status_lbl.add_theme_font_size_override("font_size", 20)
	top_row.add_child(status_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "%s　%s" % [str(ep.get("title", "")), str(ep.get("subtitle", ""))]
	title_lbl.add_theme_color_override("font_color", COLOR_PAPER if avail else Color(0.65, 0.63, 0.58, 0.75))
	title_lbl.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title_lbl)

	var sum_lbl := Label.new()
	sum_lbl.text = str(ep.get("summary", ""))
	sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum_lbl.add_theme_color_override("font_color", COLOR_MUTED if avail else Color(0.55, 0.53, 0.49, 0.72))
	sum_lbl.add_theme_font_size_override("font_size", 21)
	vbox.add_child(sum_lbl)

	var play_btn: Button = null
	if avail:
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 16)
		vbox.add_child(foot)

		play_btn = Button.new()
		play_btn.text = "この時代を紐解く（作品タイトルへ）"
		play_btn.custom_minimum_size = Vector2(400, 54)
		play_btn.add_theme_font_size_override("font_size", 22)
		var btn_norm := _make_box_style(Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 0.94), COLOR_GOLD, 1, 24, 10)
		btn_norm.border_width_left = 5
		var btn_hi := _make_box_style(accent, COLOR_GOLD, 1, 24, 10)
		btn_hi.border_width_left = 5
		play_btn.add_theme_stylebox_override("normal", btn_norm)
		play_btn.add_theme_stylebox_override("hover", btn_hi)
		play_btn.add_theme_stylebox_override("focus", btn_hi)
		play_btn.mouse_entered.connect(func() -> void:
			_play_sm_se("ui_hover", 0.42)
		)
		play_btn.pressed.connect(_select_episode_from_portal.bind(ep, false))
		foot.add_child(play_btn)

		if has_save:
			var resume_btn := Button.new()
			resume_btn.text = "栞から即再開"
			resume_btn.custom_minimum_size = Vector2(220, 54)
			resume_btn.add_theme_font_size_override("font_size", 21)
			resume_btn.mouse_entered.connect(func() -> void:
				_play_sm_se("ui_hover", 0.42)
			)
			resume_btn.pressed.connect(_select_episode_from_portal.bind(ep, true))
			foot.add_child(resume_btn)
	else:
		var soon_lbl := Label.new()
		soon_lbl.text = "※ 次回エピソード格納枠（episodes/%s/）準備済" % ep_id
		soon_lbl.add_theme_color_override("font_color", Color(accent.lightened(0.28).r, accent.lightened(0.28).g, accent.lightened(0.28).b, 0.70))
		soon_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(soon_lbl)

	return {"card": card, "play_btn": play_btn}


func _select_episode_from_portal(ep: Dictionary, direct_continue: bool = false) -> void:
	if not _load_episode_data(ep):
		_qol_overlays.show_toast("この時代のシナリオデータが見つかりません", true)
		return
	_play_sm_se("ui_confirm", 0.85)
	_portal_screen.visible = false
	_portal_particles.set_effect("none", true)
	if direct_continue and _save_store.has_any_save():
		_on_continue_pressed()
	else:
		_show_title_screen()


func _on_portal_return_pressed() -> void:
	_play_ui_click()
	_show_portal_screen()


# --- 画面遷移 ---

func _show_title_screen() -> void:
	_stop_voice_safe()
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_save_store.flush_if_dirty()
	_in_game = false
	_is_transitioning = false
	_auto_mode = false
	_skip_mode = false
	_at_choices = false
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = false
	_last_speaker_key = ""
	_current_effect_name = ""
	_mood_bgm_id = ""
	_shake_timer = 0.0
	_bg_impact_zoom = 0.0
	_shake_root.position = Vector2.ZERO
	_bg_fade_rect.color.a = 0.0
	_flash_overlay.visible = false
	_chapter_banner.visible = false
	_set_ui_hidden(false)
	_update_auto_button_visual()
	_update_skip_button_visual()
	_play_bgm("title_theme")

	_game_screen.visible = false
	if _main_title_screen != null:
		_main_title_screen.visible = false
	if _main_title_particles != null:
		_main_title_particles.set_effect("none", true)
	if _portal_screen != null:
		_portal_screen.visible = false
	if _portal_particles != null:
		_portal_particles.set_effect("none", true)
	_choice_overlay.visible = false
	_backlog_overlay.visible = false
	_ending_card_overlay.visible = false
	_gallery_overlay.visible = false
	_confirm_overlay.visible = false
	if _qol_overlays != null:
		while _qol_overlays.close_top_overlay():
			pass

	_title_screen.visible = true
	_title_particles.set_effect("embers", true)
	_atmosphere_particles.set_effect("none", true)
	_set_ambient_safe("none")
	_refresh_title_menu()

	_title_art_host.modulate = Color(1, 1, 1, 0)
	var title_tw := create_tween()
	title_tw.tween_property(_title_art_host, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE)
	if _title_episode_logo != null and _title_episode_logo.visible:
		_title_episode_logo.modulate = Color(1, 1, 1, 0)
		title_tw.parallel().tween_property(_title_episode_logo, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE)

	_focus_control(_start_button)


func _on_start_pressed() -> void:
	_play_sm_se("ui_confirm", 0.85)
	_get_game_manager().call("reset_flags")
	_begin_play_session()
	var start_id := str(_meta.get("startScene", "pro_01"))
	_enter_scene(start_id)


func _on_continue_pressed() -> void:
	var latest := _save_store.get_latest_save()
	if latest.is_empty():
		return
	_play_sm_se("ui_confirm", 0.85)
	_on_qol_load_slot(str(latest["slot_id"]))


func _begin_play_session() -> void:
	_stop_voice_safe()
	_save_store.flush_if_dirty()
	_release_focus()
	_backlog_entries.clear()
	_auto_mode = false
	_skip_mode = false
	_at_choices = false
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = false
	_set_ui_hidden(false)
	_update_auto_button_visual()
	_update_skip_button_visual()
	_current_bg_id = ""
	_current_bgm_id = ""

	if _main_title_screen != null:
		_main_title_screen.visible = false
	if _main_title_particles != null:
		_main_title_particles.set_effect("none", true)
	if _portal_screen != null:
		_portal_screen.visible = false
	if _portal_particles != null:
		_portal_particles.set_effect("none", true)
	_title_screen.visible = false
	_title_particles.set_effect("none", true)
	_choice_overlay.visible = false
	_ending_card_overlay.visible = false
	_gallery_overlay.visible = false
	_backlog_overlay.visible = false
	_confirm_overlay.visible = false
	if _qol_overlays != null:
		while _qol_overlays.close_top_overlay():
			pass
	_game_screen.visible = true
	_in_game = true


func _set_ui_hidden(is_hidden: bool) -> void:
	_ui_hidden = is_hidden
	_message_window.visible = not is_hidden
	_top_hud.visible = not is_hidden


func _toggle_ui_hidden() -> void:
	if not _in_game or _is_transitioning or _is_any_modal_open():
		return
	_set_ui_hidden(not _ui_hidden)


func _focus_control(ctrl: Control) -> void:
	if ctrl == null:
		return
	if ctrl.is_visible_in_tree():
		ctrl.grab_focus()
	else:
		ctrl.call_deferred("grab_focus")


func _release_focus() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()


func _enter_scene(
	scene_id: String,
	show_banner: bool = true,
	start_line: int = 0,
	restore_choices: bool = false,
	append_first_backlog: bool = true
) -> void:
	if not _scenes.has(scene_id):
		push_error("存在しないシーンID: " + scene_id)
		return

	_current_scene_id = scene_id
	_current_scene = _scenes[scene_id]
	_line_index = 0
	_auto_wait_timer = 0.0
	_last_speaker_key = ""
	_at_choices = false
	_choice_overlay.visible = false
	_ending_card_overlay.visible = false
	_save_store.mark_scene_visited(scene_id)

	var ch := str(_current_scene.get("chapter", ""))
	var stitle := str(_current_scene.get("title", ""))
	_chapter_label.text = "%s　%s" % [ch, stitle] if not ch.is_empty() else stitle
	_location_label.text = str(_current_scene.get("location", ""))

	var fx_name := str(_current_scene.get("effect", "none"))
	var amb_name := str(_current_scene.get("ambient", fx_name))
	_current_effect_name = fx_name
	_apply_background(str(_current_scene.get("bg", "")))
	_atmosphere_particles.set_effect(fx_name)
	_clear_all_sprites_immediate()

	var lines: Array = _current_scene.get("lines", [])
	var has_scene_choices := _current_scene.has("choices") and not (_current_scene["choices"] as Array).is_empty()
	if not lines.is_empty() and start_line >= lines.size() and has_scene_choices:
		restore_choices = true
	var clamped_line := clampi(start_line, 0, lines.size() - 1) if not lines.is_empty() else 0
	var gm := _get_game_manager()
	if not lines.is_empty() and (clamped_line > 0 or restore_choices):
		# 途中復帰時は clamped_line までの累積シーン状態（BGM/背景/場所/エフェクト/環境音/立ち絵）を復元する
		var resolved_bgm := str(_current_scene.get("bgm", ""))
		var resolved_bg := ""
		var resolved_loc := ""
		var resolved_fx := fx_name
		var resolved_amb := amb_name
		var resolved_sprites: Variant = null
		for i in clamped_line + 1:
			var ln: Dictionary = lines[i]
			if ln.has("require_flag") and not bool(gm.call("has_flag", str(ln["require_flag"]))):
				continue
			if ln.has("location"):
				resolved_loc = str(ln["location"])
			if ln.has("bg"):
				resolved_bg = str(ln["bg"])
			if ln.has("effect"):
				resolved_fx = str(ln["effect"])
				if not ln.has("ambient"):
					resolved_amb = resolved_fx
			if ln.has("ambient"):
				resolved_amb = str(ln["ambient"])
			if ln.has("bgm"):
				resolved_bgm = str(ln["bgm"])
			if i < clamped_line and ln.has("sprites"):
				resolved_sprites = ln["sprites"]
		if not resolved_loc.is_empty():
			_location_label.text = resolved_loc
		if not resolved_bg.is_empty():
			_apply_background(resolved_bg)
		_current_effect_name = resolved_fx
		_atmosphere_particles.set_effect(resolved_fx, true)
		_set_ambient_safe(resolved_amb)
		_play_bgm(resolved_bgm)
		_apply_vignette_mood(resolved_fx, scene_id, true)
		if resolved_sprites != null and not (lines[clamped_line] as Dictionary).has("sprites"):
			_update_sprites(resolved_sprites, true)
	else:
		_set_ambient_safe(amb_name)
		_play_bgm(str(_current_scene.get("bgm", "")))
		_apply_vignette_mood(fx_name, scene_id, true)

	if show_banner and not _is_skipping():
		_show_chapter_banner(ch, stitle)

	if lines.is_empty():
		_on_scene_finished()
	else:
		_show_line(clamped_line, append_first_backlog, restore_choices)
		if restore_choices and has_scene_choices:
			_finish_typing()
			_show_choices(_current_scene)


func _transition_to_scene(next_id: String) -> void:
	if _is_transitioning:
		return
	_save_store.flush_if_dirty()
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_is_transitioning = true
	var fade_t := 0.12 if _is_skipping() else 0.25
	var fade_in_t := 0.14 if _is_skipping() else 0.30
	_transition_tween = create_tween()
	_transition_tween.tween_property(_bg_fade_rect, "color:a", 1.0, fade_t)
	_transition_tween.tween_callback(func() -> void:
		_enter_scene(next_id)
	)
	_transition_tween.tween_property(_bg_fade_rect, "color:a", 0.0, fade_in_t)
	_transition_tween.tween_callback(func() -> void:
		_is_transitioning = false
	)


func _show_chapter_banner(chapter: String, title: String) -> void:
	if chapter.is_empty() and title.is_empty():
		return
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	var banner_panel := $ShakeRoot/GameScreen/ChapterBanner/BannerPanel as PanelContainer
	banner_panel.pivot_offset = banner_panel.size * 0.5
	_chapter_banner_label.text = "%s　「%s」" % [chapter, title] if not chapter.is_empty() else title
	_chapter_banner.visible = true
	_chapter_banner.modulate = Color(1, 1, 1, 0)
	banner_panel.scale = Vector2(0.95, 0.95)
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.tween_property(_chapter_banner, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_property(banner_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(1.10)
	_banner_tween.chain().tween_property(_chapter_banner, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_callback(func() -> void:
		_chapter_banner.visible = false
	)


# --- 行表示・タイプライター・既読スキップ ---

func _show_line(index: int, append_backlog: bool = true, suppress_oneshot_fx: bool = false) -> void:
	_stop_voice_safe()
	var lines: Array = _current_scene.get("lines", [])
	var gm := _get_game_manager()
	while index >= 0 and index < lines.size():
		var candidate: Variant = lines[index]
		if candidate is Dictionary and (candidate as Dictionary).has("require_flag"):
			if not bool(gm.call("has_flag", str((candidate as Dictionary)["require_flag"]))):
				index += 1
				continue
		break

	if index < 0 or index >= lines.size():
		_on_scene_finished()
		return

	_line_index = index
	_auto_wait_timer = 0.0
	var line: Dictionary = lines[index]

	# 行進入前の既読判定（未読行に踏み込んだ瞬間を検知するため）
	_current_line_was_read = _save_store.is_line_read(_current_scene_id, index)
	_read_badge.visible = _current_line_was_read

	var skipping_now := _is_skipping()
	if skipping_now and not _can_skip_current_line():
		if _skip_mode:
			_skip_mode = false
			_update_skip_button_visual()
			_qol_overlays.show_toast("未読箇所に到達したためスキップを停止しました")
		skipping_now = false

	_suppress_sfx_for_skip = skipping_now

	var line_se := str(line["se"]) if line.has("se") else ""
	var line_flash := str(line["flash"]) if line.has("flash") else ""
	var line_voice := str(line.get("voice", ""))

	# 行単位の動的場面転換（5年後転換など）
	if line.has("location"):
		_location_label.text = str(line["location"])
	if line.has("bg"):
		_apply_background(str(line["bg"]))
	if line.has("effect"):
		var eff := str(line["effect"])
		_current_effect_name = eff
		_atmosphere_particles.set_effect(eff, skipping_now)
	if line.has("bgm"):
		_play_bgm(str(line["bgm"]))
	elif line.has("effect"):
		_apply_vignette_mood(_current_effect_name, _current_scene_id, skipping_now)
	if line.has("ambient"):
		_set_ambient_safe(str(line["ambient"]))
	elif line.has("effect"):
		_set_ambient_safe(_current_effect_name)

	var instant_fx := skipping_now or suppress_oneshot_fx
	if not line_se.is_empty() and not instant_fx:
		_play_se(line_se)
	if not line_voice.is_empty() and not instant_fx:
		_play_voice_safe(line_voice)
	if bool(line.get("shake", false)) and not instant_fx:
		_trigger_shake()
	if not line_flash.is_empty() and not instant_fx:
		_trigger_flash(line_flash)
	if line.has("sprites"):
		_update_sprites(line["sprites"], instant_fx)
	if not instant_fx and (not line_se.is_empty() or not line_flash.is_empty()):
		_trigger_sprite_action(line_se, line_flash)

	_suppress_sfx_for_skip = false

	var speaker := str(line.get("speaker", ""))
	_apply_speaker_style(speaker, instant_fx)

	_full_text = str(line.get("text", ""))
	_body_text.text = _full_text
	_parsed_text = _body_text.get_parsed_text()
	if _parsed_text.is_empty():
		_parsed_text = _full_text
	_total_chars = _body_text.get_total_character_count()
	if _total_chars <= 0:
		_total_chars = _full_text.length()

	var char_int := _save_store.get_char_interval()
	if skipping_now or char_int <= 0.001:
		_finish_typing()
	else:
		_body_text.visible_characters = 0
		_is_typing = true
		_char_timer = 0.0
		_char_step_delay = char_int * 0.45
		_next_indicator.visible = false

	if append_backlog:
		_backlog_entries.append({
			"chapter": str(_current_scene.get("chapter", "")),
			"title": str(_current_scene.get("title", "")),
			"speaker": speaker,
			"text": _full_text,
		})


func _apply_speaker_style(speaker: String, instant: bool = false) -> void:
	_speaker_row.modulate = Color(1, 1, 1, 1)
	if _speaker_accent_tween != null and _speaker_accent_tween.is_valid():
		_speaker_accent_tween.kill()
		_speaker_accent_tween = null

	if speaker.is_empty():
		_last_speaker_key = ""
		_speaker_accent.modulate.a = 0.0
		_speaker_accent.scale = Vector2.ONE
		_speaker_label.modulate.a = 0.0
		_speaker_label.text = "　"
		_gold_divider.modulate = Color(1, 1, 1, 0.25)
		return

	var changed := (speaker != _last_speaker_key)
	_last_speaker_key = speaker

	_speaker_accent.modulate.a = 1.0
	_speaker_accent.pivot_offset = _speaker_accent.size * 0.5
	_speaker_label.text = speaker
	_gold_divider.modulate = Color(1, 1, 1, 0.85)

	var bar_col := COLOR_CRIMSON
	var name_col := COLOR_GOLD
	if speaker.contains("信長"):
		bar_col = Color("C42B2B")
		name_col = Color("F5DFAC")
	elif speaker.contains("蘭丸"):
		bar_col = Color("4B9CB8")
		name_col = Color("D7EEF6")
	elif speaker.contains("弥助"):
		bar_col = Color("D08C45")
		name_col = Color("F5E5CC")
	elif speaker.contains("光秀"):
		bar_col = Color("8B74C9")
		name_col = Color("EAE2FA")
	elif speaker.contains("秀吉"):
		bar_col = Color("D9A83B")
		name_col = Color("F7E9B8")
	elif speaker.contains("宗久"):
		bar_col = Color("63A172")
		name_col = Color("DCF0E0")
	elif speaker.contains("家康"):
		bar_col = Color("4A8B6F")
		name_col = Color("D6F0E3")
	else:
		bar_col = COLOR_GOLD
		name_col = COLOR_PAPER

	_speaker_accent.color = bar_col
	_speaker_label.add_theme_color_override("font_color", name_col)

	if changed and not instant:
		_speaker_accent.scale = Vector2(1.0, 0.15)
		_speaker_label.modulate.a = 0.25
		_speaker_accent_tween = create_tween().set_parallel(true)
		_speaker_accent_tween.tween_property(_speaker_accent, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_speaker_accent_tween.tween_property(_speaker_label, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	else:
		_speaker_accent.scale = Vector2.ONE
		_speaker_label.modulate.a = 1.0


func _mark_current_line_read() -> void:
	if _current_scene_id.is_empty():
		return
	_save_store.mark_line_read(_current_scene_id, _line_index)


func _is_skipping() -> bool:
	if not _in_game or _is_any_modal_open() or _is_transitioning:
		return false
	return _skip_mode or Input.is_key_pressed(KEY_CTRL)


func _can_skip_current_line() -> bool:
	if bool(_save_store.settings.get("skip_unread", false)):
		return true
	return _current_line_was_read


func _finish_typing() -> void:
	_is_typing = false
	_body_text.visible_characters = -1
	_next_indicator.visible = true
	_auto_wait_timer = 0.0


func _advance_or_complete(play_click: bool = true) -> void:
	if not _in_game or _is_transitioning:
		return
	if _is_any_modal_open():
		return

	if _is_typing:
		_finish_typing()
		return

	_mark_current_line_read()
	if play_click and not _suppress_sfx_for_skip:
		_play_ui_click()
	var lines: Array = _current_scene.get("lines", [])
	if _line_index + 1 < lines.size():
		_show_line(_line_index + 1)
	else:
		_on_scene_finished()


func _on_scene_finished() -> void:
	_mark_current_line_read()
	_auto_wait_timer = 0.0
	_skip_mode = false
	_update_skip_button_visual()
	if _current_scene.has("choices") and not (_current_scene["choices"] as Array).is_empty():
		_show_choices(_current_scene)
	elif _current_scene.has("ending"):
		_show_ending_card(_current_scene["ending"])
	elif _current_scene.has("next"):
		_transition_to_scene(str(_current_scene["next"]))


func _process(delta: float) -> void:
	_indicator_time += delta
	_bg_breath_time += delta
	if _next_indicator.visible:
		_next_indicator.modulate.a = 0.45 + 0.55 * absf(sin(_indicator_time * 3.4))

	if _bg_texture_rect.visible:
		_bg_impact_zoom = move_toward(_bg_impact_zoom, 0.0, delta * 0.09)
		var breath := 1.006 + 0.005 * sin(_bg_breath_time * 0.35) + _bg_impact_zoom
		_bg_texture_rect.scale = Vector2(breath, breath)

	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		if _shake_timer > 0.0:
			var ratio := _shake_timer / SHAKE_DURATION
			var amp := SHAKE_MAX_OFFSET * ratio
			_shake_root.position = Vector2(
				randf_range(-amp, amp),
				randf_range(-amp * 0.85, amp * 0.85)
			)
		else:
			_shake_root.position = Vector2.ZERO

	if not _in_game or _is_any_modal_open() or _is_transitioning:
		return

	if _is_skipping():
		if not _can_skip_current_line():
			if _skip_mode:
				_skip_mode = false
				_update_skip_button_visual()
				_qol_overlays.show_toast("未読箇所に到達したためスキップを停止しました")
			return
		_skip_timer += delta
		if _skip_timer >= SKIP_INTERVAL:
			_skip_timer = 0.0
			_suppress_sfx_for_skip = true
			if _is_typing:
				_finish_typing()
			_advance_or_complete(false)
			_suppress_sfx_for_skip = false
		return

	if _is_typing:
		var interval := _save_store.get_char_interval()
		if interval <= 0.001:
			_finish_typing()
		else:
			_advance_char_typing(delta, interval)
	elif _auto_mode:
		_auto_wait_timer += delta
		var wait_sec := _save_store.get_auto_wait_sec(_total_chars)
		if _auto_wait_timer >= wait_sec:
			_advance_or_complete()


func _get_char_step_multiplier(just_revealed: String, next_ch: String) -> float:
	if just_revealed == "。" or just_revealed == "！" or just_revealed == "？":
		if next_ch == "」" or next_ch == "』" or next_ch == "！" or next_ch == "？":
			return 1.0
		return 4.2
	if just_revealed == "、" or just_revealed == "…":
		if next_ch == "…":
			return 1.5
		return 2.5
	if just_revealed == "―":
		if next_ch == just_revealed:
			return 1.0
		return 2.4
	if just_revealed == "\n":
		return 3.0
	return 1.0


func _advance_char_typing(delta: float, interval: float) -> void:
	_char_timer += delta
	while _is_typing and _char_timer >= _char_step_delay:
		_char_timer -= _char_step_delay
		var cur_v := _body_text.visible_characters + 1
		if cur_v >= _total_chars:
			_finish_typing()
			return
		_body_text.visible_characters = cur_v
		var revealed := _parsed_text.substr(cur_v - 1, 1) if cur_v - 1 < _parsed_text.length() else ""
		var upcoming := _parsed_text.substr(cur_v, 1) if cur_v < _parsed_text.length() else ""
		_char_step_delay = interval * _get_char_step_multiplier(revealed, upcoming)


func _on_click_advance_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_ui_hidden()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _ui_hidden and _in_game and not _is_transitioning and not _is_any_modal_open():
				_on_backlog_pressed()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if _ui_hidden:
				_set_ui_hidden(false)
			else:
				if _skip_mode:
					_skip_mode = false
					_update_skip_button_visual()
				_advance_or_complete()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return

		if _confirm_overlay.visible:
			if k.keycode == KEY_ESCAPE:
				_close_confirm_overlay()
				get_viewport().set_input_as_handled()
			return
		if _qol_overlays != null and _qol_overlays.is_any_open():
			if k.keycode == KEY_ESCAPE:
				_play_ui_click()
				_qol_overlays.close_top_overlay()
				get_viewport().set_input_as_handled()
			return
		if _backlog_overlay.visible:
			if k.keycode == KEY_ESCAPE or k.keycode == KEY_H:
				_close_backlog()
				get_viewport().set_input_as_handled()
			return
		if _gallery_overlay.visible:
			if k.keycode == KEY_ESCAPE:
				_close_gallery()
				get_viewport().set_input_as_handled()
			return

		if not _in_game and _title_screen.visible and not _confirm_overlay.visible:
			if k.keycode == KEY_ESCAPE:
				_on_portal_return_pressed()
				get_viewport().set_input_as_handled()
			return

		if not _in_game and _portal_screen != null and _portal_screen.visible:
			if k.keycode == KEY_ESCAPE:
				_on_main_title_return_pressed()
				get_viewport().set_input_as_handled()
			return

		if _in_game and _choice_overlay.visible:
			var choice_idx := -1
			if k.keycode >= KEY_1 and k.keycode <= KEY_9:
				choice_idx = k.keycode - KEY_1
			elif k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
				choice_idx = k.keycode - KEY_KP_1
			if choice_idx >= 0 and choice_idx < _choices_container.get_child_count():
				var btn := _choices_container.get_child(choice_idx) as Button
				if btn != null and not btn.disabled:
					btn.emit_signal("pressed")
					get_viewport().set_input_as_handled()
					return
			if k.keycode == KEY_Q or k.keycode == KEY_F5:
				_quick_save()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_L or k.keycode == KEY_F9:
				_quick_load()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_ESCAPE:
				_on_title_return_pressed()
				get_viewport().set_input_as_handled()
			return

		if _in_game and not _choice_overlay.visible and not _ending_card_overlay.visible:
			if k.keycode == KEY_M:
				_toggle_ui_hidden()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_Z:
				if _ui_hidden:
					_set_ui_hidden(false)
				else:
					if _skip_mode:
						_skip_mode = false
						_update_skip_button_visual()
					_advance_or_complete()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_H:
				_on_backlog_pressed()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_A:
				_on_auto_pressed()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_S:
				_on_skip_pressed()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_Q or k.keycode == KEY_F5:
				_quick_save()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_L or k.keycode == KEY_F9:
				_quick_load()
				get_viewport().set_input_as_handled()
			elif k.keycode == KEY_ESCAPE:
				_on_title_return_pressed()
				get_viewport().set_input_as_handled()


func _is_any_modal_open() -> bool:
	return (
		_choice_overlay.visible
		or _backlog_overlay.visible
		or _ending_card_overlay.visible
		or _gallery_overlay.visible
		or _confirm_overlay.visible
		or (_qol_overlays != null and _qol_overlays.is_any_open())
	)


# --- 背景 & 立ち絵 ---

func _apply_background(bg_id: String) -> void:
	if bg_id == _current_bg_id and not bg_id.is_empty():
		return
	_current_bg_id = bg_id

	var bg_map: Dictionary = _assets_cfg.get("backgrounds", {})
	var rel_path := str(bg_map.get(bg_id, ""))
	var tex := _load_texture_safe(rel_path)

	if tex != null:
		_bg_texture_rect.texture = tex
		_bg_texture_rect.visible = true
		_bg_fallback_host.visible = false
		_bg_watermark.visible = false
	else:
		_bg_texture_rect.texture = null
		_bg_texture_rect.visible = false
		_bg_fallback_host.visible = true
		_fallback_bg_view.set_bg(bg_id)
		_bg_watermark.text = "[BG: %s]" % bg_id if not bg_id.is_empty() else "[BG: none]"
		_bg_watermark.visible = true


func _apply_vignette_mood(effect_name: String, scene_id: String, instant: bool = false) -> void:
	if _vignette_mat == null:
		return
	var edge := Color(0.03, 0.03, 0.05, 0.44)
	var glow := Color(0.0, 0.0, 0.0, 0.0)
	var strength := 0.44
	match effect_name.to_lower():
		"embers":
			edge = Color(0.10, 0.02, 0.02, 0.48)
			glow = Color(0.70, 0.14, 0.04, 0.16)
			strength = 0.50
		"rain":
			edge = Color(0.02, 0.04, 0.08, 0.46)
			strength = 0.48
		"mist":
			edge = Color(0.03, 0.06, 0.06, 0.40)
			strength = 0.38
		"moonlight":
			edge = Color(0.02, 0.03, 0.09, 0.50)
			strength = 0.48
		"sunbeams":
			edge = Color(0.08, 0.05, 0.02, 0.36)
			glow = Color(0.65, 0.42, 0.16, 0.06)
			strength = 0.36
		"dust":
			edge = Color(0.06, 0.04, 0.03, 0.46)
			glow = Color(0.55, 0.28, 0.08, 0.08)
			strength = 0.44
	if scene_id == "end_04":
		strength = 0.54

	match _mood_bgm_id:
		"silence":
			edge = edge.darkened(0.28)
			glow.a *= 1.18
			strength = clampf(strength + 0.14, 0.0, 0.68)
		"suspense_discord":
			edge = edge.lerp(Color(0.015, 0.025, 0.085, 0.60), 0.68)
			strength = clampf(maxf(strength, 0.56), 0.0, 0.68)
		"honnoji_flames":
			glow = Color(maxf(glow.r, 0.72), 0.14, 0.04, maxf(glow.a, 0.16))
			strength = maxf(strength, 0.52)
		"dawn_hope":
			strength = maxf(strength - 0.06, 0.30)

	_tween_vignette_to(edge, glow, strength, 0.0 if instant else 0.55)


func _set_vignette_uniforms(edge: Color, glow: Color, strength: float) -> void:
	_vignette_edge = edge
	_vignette_glow = glow
	_vignette_strength = strength
	if _vignette_mat != null:
		_vignette_mat.set_shader_parameter("edge_tint", edge)
		_vignette_mat.set_shader_parameter("bottom_glow", glow)
		_vignette_mat.set_shader_parameter("vig_strength", strength)


func _tween_vignette_to(target_edge: Color, target_glow: Color, target_strength: float, duration: float) -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
		_vignette_tween = null
	if duration <= 0.01:
		_set_vignette_uniforms(target_edge, target_glow, target_strength)
		return
	var s_edge := _vignette_edge
	var s_glow := _vignette_glow
	var s_str := _vignette_strength
	_vignette_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_vignette_tween.tween_method(func(t: float) -> void:
		_set_vignette_uniforms(s_edge.lerp(target_edge, t), s_glow.lerp(target_glow, t), lerpf(s_str, target_strength, t))
	, 0.0, 1.0, duration)


func _clear_all_sprites_immediate() -> void:
	for side in ["left", "right"]:
		var tw: Tween = _sprite_tweens.get(side, null)
		if tw != null and tw.is_valid():
			tw.kill()
		var xf: Tween = _crossfade_tweens.get(side, null)
		if xf != null and xf.is_valid():
			xf.kill()
		var act_tw: Tween = _action_tweens.get(side, null)
		if act_tw != null and act_tw.is_valid():
			act_tw.kill()
		var info: Dictionary = _sprite_slots[side]
		var slot: Control = info["slot"]
		var prev_tex_rect: TextureRect = info["prev_tex_rect"]
		var tex_rect: TextureRect = info["tex_rect"]
		var card: CharacterCardView = info["card"]
		var base_pos: Vector2 = _slot_base_pos.get(side, slot.position)
		slot.visible = false
		slot.position = base_pos
		slot.modulate = Color(1, 1, 1, 0)
		slot.scale = Vector2(0.98, 0.98)
		prev_tex_rect.visible = false
		prev_tex_rect.texture = null
		prev_tex_rect.modulate = Color.WHITE
		prev_tex_rect.position = Vector2.ZERO
		tex_rect.texture = null
		tex_rect.modulate = Color.WHITE
		tex_rect.self_modulate = Color.WHITE
		tex_rect.position = Vector2.ZERO
		card.self_modulate = Color.WHITE
		card.position = Vector2.ZERO
		info["char_id"] = ""
		info["active"] = false
		info["visible"] = false


func _update_sprites(sprites_data: Variant, instant: bool = false) -> void:
	var wanted := {"left": null, "right": null}
	if sprites_data is Array:
		for item in sprites_data:
			if item is Dictionary:
				var pos := str(item.get("pos", "left"))
				if pos == "left" or pos == "right":
					wanted[pos] = item

	for side in ["left", "right"]:
		var info: Dictionary = _sprite_slots[side]
		var slot: Control = info["slot"]
		var prev_tex_rect: TextureRect = info["prev_tex_rect"]
		var tex_rect: TextureRect = info["tex_rect"]
		var card: CharacterCardView = info["card"]
		var target_item: Variant = wanted[side]
		var base_pos: Vector2 = _slot_base_pos.get(side, slot.position)

		var prev_tw: Tween = _sprite_tweens.get(side, null)
		if prev_tw != null and prev_tw.is_valid():
			prev_tw.kill()
		var prev_act: Tween = _action_tweens.get(side, null)
		if prev_act != null and prev_act.is_valid():
			prev_act.kill()
		tex_rect.position = Vector2.ZERO
		tex_rect.self_modulate = Color.WHITE
		card.position = Vector2.ZERO
		card.self_modulate = Color.WHITE

		if target_item == null:
			var prev_xf_exit: Tween = _crossfade_tweens.get(side, null)
			if prev_xf_exit != null and prev_xf_exit.is_valid():
				prev_xf_exit.kill()
			if info["visible"]:
				info["visible"] = false
				info["char_id"] = ""
				if instant:
					slot.visible = false
					slot.position = base_pos
					slot.modulate.a = 0.0
					prev_tex_rect.visible = false
					prev_tex_rect.texture = null
					tex_rect.modulate = Color.WHITE
				else:
					var out_x := -18.0 if side == "left" else 18.0
					var tw_out := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
					tw_out.tween_property(slot, "modulate:a", 0.0, 0.20)
					tw_out.tween_property(slot, "position:x", base_pos.x + out_x, 0.20)
					tw_out.chain().tween_callback(func() -> void:
						if not info["visible"]:
							slot.visible = false
							slot.position = base_pos
							prev_tex_rect.visible = false
							prev_tex_rect.texture = null
							tex_rect.modulate = Color.WHITE
					)
					_sprite_tweens[side] = tw_out
			continue

		var char_id := str(target_item.get("id", ""))
		var is_active := bool(target_item.get("active", false))
		var was_visible := bool(info["visible"])
		var prev_id := str(info["char_id"])

		info["visible"] = true
		info["char_id"] = char_id
		info["active"] = is_active

		if prev_id != char_id:
			var prev_xf: Tween = _crossfade_tweens.get(side, null)
			if prev_xf != null and prev_xf.is_valid():
				prev_xf.kill()
			var old_tex: Texture2D = tex_rect.texture if (was_visible and tex_rect.visible) else null
			var char_map: Dictionary = _assets_cfg.get("characters", {})
			var rel_path := str(char_map.get(char_id, ""))
			var tex := _load_texture_safe(rel_path)
			if tex != null:
				if not instant and old_tex != null and old_tex != tex:
					prev_tex_rect.texture = old_tex
					prev_tex_rect.visible = true
					prev_tex_rect.modulate = Color(1, 1, 1, 1)
					prev_tex_rect.position = Vector2.ZERO
					tex_rect.texture = tex
					tex_rect.visible = true
					tex_rect.modulate = Color(1, 1, 1, 0)
					card.visible = false
					var xf := create_tween()
					xf.tween_property(tex_rect, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					xf.parallel().tween_property(prev_tex_rect, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					xf.tween_callback(func() -> void:
						prev_tex_rect.visible = false
						prev_tex_rect.texture = null
						prev_tex_rect.modulate = Color.WHITE
					)
					_crossfade_tweens[side] = xf
				else:
					prev_tex_rect.visible = false
					prev_tex_rect.texture = null
					tex_rect.texture = tex
					tex_rect.visible = true
					tex_rect.modulate = Color.WHITE
					card.visible = false
			else:
				prev_tex_rect.visible = false
				prev_tex_rect.texture = null
				tex_rect.texture = null
				tex_rect.visible = false
				tex_rect.modulate = Color.WHITE
				card.set_character(char_id)
				card.visible = true
		elif instant:
			var prev_xf_inst: Tween = _crossfade_tweens.get(side, null)
			if prev_xf_inst != null and prev_xf_inst.is_valid():
				prev_xf_inst.kill()
			prev_tex_rect.visible = false
			prev_tex_rect.texture = null
			tex_rect.modulate = Color.WHITE

		_update_slot_pivot(slot)
		# z_index を上げるとオーバーレイ等より前面に出るため、CharacterLayer 内のノード順のみで前後を制御する
		slot.z_index = 0
		if is_active and slot.get_parent() != null:
			slot.get_parent().move_child(slot, -1)

		var brightness := 1.0 if is_active else 0.72
		var target_color := Color(brightness, brightness, brightness, 1.0)
		var target_scale := Vector2(1.02, 1.02) if is_active else Vector2(0.98, 0.98)
		var target_pos := base_pos + (Vector2(0.0, -5.0) if is_active else Vector2.ZERO)

		if instant:
			slot.visible = true
			slot.modulate = target_color
			slot.scale = target_scale
			slot.position = target_pos
			continue

		if not was_visible:
			slot.visible = true
			var enter_off_x := -28.0 if side == "left" else 28.0
			slot.position = base_pos + Vector2(enter_off_x, 4.0)
			slot.modulate = Color(brightness, brightness, brightness, 0.0)
			slot.scale = target_scale * 0.97

		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(slot, "modulate", target_color, 0.24)
		tw.tween_property(slot, "scale", target_scale, 0.24)
		tw.tween_property(slot, "position", target_pos, 0.24)
		_sprite_tweens[side] = tw


func _trigger_sprite_action(se_id: String, flash_type: String) -> void:
	var jolt_amp := 0.0
	var step_bounce := 0.0
	match se_id:
		"gunshot", "gun_volley", "crash_fire", "sword_slash":
			jolt_amp = 10.0
		"door_slam", "curtain_open", "war_horn", "battle_cry":
			step_bounce = -9.0

	var flash_tint := Color.WHITE
	var flash_dur := 0.0
	match flash_type.to_lower():
		"red":
			flash_tint = Color(1.55, 0.62, 0.58, 1.0)
			flash_dur = 0.42
		"white":
			flash_tint = Color(1.45, 1.45, 1.45, 1.0)
			flash_dur = 0.32
		"gold":
			flash_tint = Color(1.30, 1.20, 0.90, 1.0)
			flash_dur = 0.36

	if jolt_amp == 0.0 and step_bounce == 0.0 and flash_dur == 0.0:
		return

	for side in ["left", "right"]:
		var info: Dictionary = _sprite_slots[side]
		if not bool(info.get("visible", false)):
			continue
		var tex_rect: TextureRect = info["tex_rect"]
		var card: CharacterCardView = info["card"]
		var visual: Control = (tex_rect as Control) if tex_rect.visible else (card as Control)
		var is_active := bool(info.get("active", false))
		var do_motion := is_active and (jolt_amp != 0.0 or step_bounce != 0.0)
		if not do_motion and flash_dur <= 0.0:
			continue

		var prev_act: Tween = _action_tweens.get(side, null)
		if prev_act != null and prev_act.is_valid():
			prev_act.kill()

		var tw := create_tween()
		if do_motion:
			if jolt_amp != 0.0:
				tw.tween_property(visual, "position", Vector2(0.0, jolt_amp), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(visual, "position", Vector2(0.0, -4.0), 0.09).set_trans(Tween.TRANS_SINE)
				tw.tween_property(visual, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				tw.tween_property(visual, "position", Vector2(0.0, step_bounce), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(visual, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if flash_dur > 0.0:
			visual.self_modulate = flash_tint
			if do_motion:
				var ft := create_tween()
				ft.tween_property(visual, "self_modulate", Color.WHITE, flash_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				tw.tween_property(visual, "self_modulate", Color.WHITE, flash_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_action_tweens[side] = tw


func _load_texture_safe(rel_path: String) -> Texture2D:
	if rel_path.is_empty():
		return null
	var res_path := _resolve_episode_path(rel_path)
	var gm := _get_game_manager()
	return gm.call("load_texture_safe", res_path) as Texture2D


# --- 演出（シェイク・フラッシュ） ---

func _trigger_shake() -> void:
	_shake_timer = SHAKE_DURATION
	_bg_impact_zoom = 0.024


func _trigger_flash(flash_type: String) -> void:
	var key := flash_type.to_lower()
	var col: Color
	match key:
		"red":
			col = Color(0.76, 0.08, 0.08, 0.80)
		"white":
			col = Color(1.0, 0.98, 0.95, 0.90)
			_bg_impact_zoom = maxf(_bg_impact_zoom, 0.015)
		"gold":
			col = Color(0.88, 0.70, 0.32, 0.56)
		_:
			return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_overlay.color = col
	_flash_overlay.visible = true
	_flash_tween = create_tween()
	if key == "red":
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.22, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.52, 0.08).set_trans(Tween.TRANS_SINE)
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif key == "gold":
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_callback(func() -> void:
		_flash_overlay.visible = false
	)


# --- 選択肢オーバーレイ ---

func _show_choices(scene: Dictionary) -> void:
	_set_ui_hidden(false)
	_at_choices = true
	_auto_mode = false
	_skip_mode = false
	_update_auto_button_visual()
	_update_skip_button_visual()
	_save_store.flush_if_dirty()

	_choice_prompt_label.text = str(scene.get("choicePrompt", "選べ――"))
	for c in _choices_container.get_children():
		c.queue_free()

	var gm := _get_game_manager()
	var choices: Array = scene.get("choices", [])
	var visible_choices: Array[Dictionary] = []
	for ch in choices:
		if not (ch is Dictionary):
			continue
		var ch_dict := ch as Dictionary
		if ch_dict.has("require_flags"):
			var req_flags: Variant = ch_dict["require_flags"]
			if req_flags is Array and not bool(gm.call("has_all_flags", req_flags as Array)):
				continue
		visible_choices.append(ch_dict)

	var is_compact := visible_choices.size() >= 3
	var first_btn: Button = null
	for ch_dict in visible_choices:
		var label_str := str(ch_dict.get("label", ""))
		var sub_str := str(ch_dict.get("sub", ""))
		var target_id := str(ch_dict.get("target", ""))
		var set_flag_name := str(ch_dict.get("set_flag", ""))
		var is_true_route := bool(ch_dict.get("is_true_route", false))
		var btn := _create_choice_button(label_str, sub_str, target_id, set_flag_name, is_true_route, is_compact)
		_choices_container.add_child(btn)
		if first_btn == null:
			first_btn = btn

	_choice_overlay.visible = true
	_choice_overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_choice_overlay, "modulate:a", 1.0, 0.24)
	if first_btn != null:
		_focus_control(first_btn)


func _create_choice_button(
	main_label: String,
	sub_text: String,
	target_id: String,
	set_flag_name: String = "",
	is_true_route: bool = false,
	is_compact: bool = false
) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(1170, 148 if is_compact else 171)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	var sb_norm: StyleBoxFlat
	var sb_hov: StyleBoxFlat
	var sb_prs: StyleBoxFlat
	if is_true_route:
		sb_norm = _make_box_style(Color("#241F15"), COLOR_GOLD, 2, 0, 0)
		sb_hov = _make_box_style(Color("#3B2E16"), Color("E6C675"), 2, 0, 0)
		sb_prs = _make_box_style(Color("#54401A"), Color("F2DF9F"), 3, 0, 0)
	else:
		sb_norm = _make_box_style(Color(0.094, 0.094, 0.122, 0.92), Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.65), 1, 0, 0)
		sb_hov = _make_box_style(Color(0.20, 0.065, 0.075, 0.96), COLOR_GOLD, 1, 0, 0)
		sb_prs = _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 3, 0, 0)
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("focus", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb_prs)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var default_bar_col := COLOR_GOLD if is_true_route else Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.5)
	var hi_bar_col := Color("F2DF9F") if is_true_route else COLOR_CRIMSON
	var default_lbl_col := COLOR_GOLD if is_true_route else COLOR_PAPER
	var hi_lbl_col := Color("F7E8BC") if is_true_route else COLOR_GOLD

	var left_bar := ColorRect.new()
	left_bar.custom_minimum_size = Vector2(8, 0)
	left_bar.color = default_bar_col
	left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_bar)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 33)
	margin.add_theme_constant_override("margin_right", 33)
	margin.add_theme_constant_override("margin_top", 12 if is_compact else 15)
	margin.add_theme_constant_override("margin_bottom", 12 if is_compact else 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 6 if is_compact else 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var lbl := Label.new()
	lbl.text = ("★ " if is_true_route else "◆ ") + main_label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 27 if is_compact else 30)
	lbl.add_theme_color_override("font_color", default_lbl_col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(lbl)

	# 周回プレイ補助：未踏ルート / 到達済＆未回収終幕ヒントバッジ
	var visited_target := _save_store.is_scene_visited(target_id)
	var uncollected := _save_store.count_uncollected_endings_from(_scenes, target_id)
	var badge_lbl := Label.new()
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_lbl.add_theme_font_size_override("font_size", 20)
	if not visited_target:
		badge_lbl.text = "【未踏ルート】"
		badge_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	elif uncollected > 0:
		badge_lbl.text = "【到達済・先に未回収終幕 %d件】" % uncollected
		badge_lbl.add_theme_color_override("font_color", COLOR_GOLD.lightened(0.15))
	else:
		badge_lbl.text = "【踏破済】"
		badge_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	title_row.add_child(badge_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = sub_text
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 21 if is_compact else 23)
	sub_lbl.add_theme_color_override("font_color", Color("D8C596") if is_true_route else COLOR_MUTED)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	# ホバーライン（下部金線）
	var hover_line := ColorRect.new()
	hover_line.anchor_left = 0.0
	hover_line.anchor_right = 1.0
	hover_line.anchor_top = 1.0
	hover_line.anchor_bottom = 1.0
	hover_line.offset_top = -3.0
	hover_line.offset_bottom = 0.0
	hover_line.color = COLOR_GOLD if is_true_route else Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.0)
	hover_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hover_line)

	var on_hi := func() -> void:
		left_bar.color = hi_bar_col
		hover_line.color = Color("F2DF9F") if is_true_route else COLOR_GOLD
		lbl.add_theme_color_override("font_color", hi_lbl_col)
		_play_sm_se("ui_hover", 0.45)
	var on_unhi := func() -> void:
		left_bar.color = default_bar_col
		hover_line.color = COLOR_GOLD if is_true_route else Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.0)
		lbl.add_theme_color_override("font_color", default_lbl_col)

	btn.mouse_entered.connect(on_hi)
	btn.focus_entered.connect(on_hi)
	btn.mouse_exited.connect(on_unhi)
	btn.focus_exited.connect(on_unhi)
	btn.pressed.connect(func() -> void:
		if not _at_choices or _is_transitioning:
			return
		_at_choices = false
		if not set_flag_name.is_empty():
			_get_game_manager().call("set_flag", set_flag_name, true)
		_play_sm_se("ui_confirm", 0.85)
		_release_focus()
		for ch_node in _choices_container.get_children():
			if ch_node is Button:
				(ch_node as Button).disabled = true
		left_bar.color = COLOR_GOLD
		hover_line.color = COLOR_GOLD
		lbl.add_theme_color_override("font_color", COLOR_GOLD)
		var ptw := create_tween()
		ptw.tween_property(btn, "modulate", Color(1.32, 1.22, 0.92, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_callback(func() -> void:
			_choice_overlay.visible = false
			_transition_to_scene(target_id)
		)
	)

	return btn


# --- HUDボタン・バックログ・確認 ---

func _on_backlog_pressed() -> void:
	if not _in_game or _is_transitioning or _choice_overlay.visible or _ending_card_overlay.visible:
		return
	_play_ui_click()
	_open_backlog()


func _open_backlog() -> void:
	_set_ui_hidden(false)
	for c in _backlog_list.get_children():
		c.queue_free()

	if _backlog_entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "まだ記録された台詞はありません。"
		empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_backlog_list.add_child(empty_lbl)
	else:
		var last_chap_key := ""
		for entry in _backlog_entries:
			var ch := str(entry.get("chapter", ""))
			var st := str(entry.get("title", ""))
			var chap_key := "%s　%s" % [ch, st] if (not ch.is_empty() and not st.is_empty()) else (ch if not ch.is_empty() else st)
			if not chap_key.is_empty() and chap_key != last_chap_key:
				last_chap_key = chap_key
				var ch_lbl := Label.new()
				ch_lbl.text = "―― %s ――" % chap_key
				ch_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ch_lbl.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.78))
				ch_lbl.add_theme_font_size_override("font_size", 23)
				_backlog_list.add_child(ch_lbl)

			var item_box := VBoxContainer.new()
			item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_box.add_theme_constant_override("separation", 6)

			var spk := str(entry.get("speaker", ""))
			if not spk.is_empty():
				var spk_lbl := Label.new()
				spk_lbl.text = "【%s】" % spk
				spk_lbl.add_theme_color_override("font_color", COLOR_GOLD)
				spk_lbl.add_theme_font_size_override("font_size", 27)
				item_box.add_child(spk_lbl)

			var txt_lbl := Label.new()
			txt_lbl.text = str(entry.get("text", ""))
			txt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			txt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			txt_lbl.add_theme_color_override("font_color", COLOR_PAPER)
			txt_lbl.add_theme_font_size_override("font_size", 29)
			item_box.add_child(txt_lbl)

			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(0, 2)
			sep.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.22)
			item_box.add_child(sep)

			_backlog_list.add_child(item_box)

	_backlog_overlay.visible = true
	_focus_control(_backlog_close_btn)
	await get_tree().process_frame
	var vbar := _backlog_scroll.get_v_scroll_bar()
	if vbar != null:
		_backlog_scroll.scroll_vertical = int(vbar.max_value)


func _close_backlog() -> void:
	_play_ui_click()
	_backlog_overlay.visible = false
	_release_focus()


func _on_auto_pressed() -> void:
	if not _in_game or _is_transitioning or _choice_overlay.visible or _ending_card_overlay.visible:
		return
	_play_ui_click()
	_auto_mode = not _auto_mode
	if _auto_mode and _skip_mode:
		_skip_mode = false
		_update_skip_button_visual()
	_auto_wait_timer = 0.0
	_update_auto_button_visual()


func _update_auto_button_visual() -> void:
	if _auto_button == null:
		return
	var sb: StyleBoxFlat
	if _auto_mode:
		_auto_button.text = "自動：ON"
		sb = _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 16, 10)
		_auto_button.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		_auto_button.text = "自動送り"
		sb = _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 16, 10)
		_auto_button.remove_theme_color_override("font_color")
	_auto_button.add_theme_stylebox_override("normal", sb)


func _on_skip_pressed() -> void:
	if not _in_game or _is_transitioning or _choice_overlay.visible or _ending_card_overlay.visible:
		return
	_play_ui_click()
	_skip_mode = not _skip_mode
	_skip_timer = 0.0
	if _skip_mode:
		if _auto_mode:
			_auto_mode = false
			_update_auto_button_visual()
		if not _can_skip_current_line():
			_skip_mode = false
			_qol_overlays.show_toast("この箇所は未読です（設定から未読スキップも可能です）", true)
	_update_skip_button_visual()


func _update_skip_button_visual() -> void:
	if _skip_button == null:
		return
	var sb: StyleBoxFlat
	if _skip_mode:
		_skip_button.text = "スキップ中"
		sb = _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 16, 10)
		_skip_button.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		_skip_button.text = "スキップ"
		sb = _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 16, 10)
		_skip_button.remove_theme_color_override("font_color")
	_skip_button.add_theme_stylebox_override("normal", sb)


func _on_mute_pressed() -> void:
	var sm := _get_sound_manager()
	if sm != null:
		sm.call("toggle_mute")
	_update_mute_button_visual()
	_apply_live_audio_volumes()
	if not _is_sound_muted():
		_play_ui_click()


func _update_mute_button_visual() -> void:
	if _mute_hud_button == null:
		return
	var is_muted := _is_sound_muted()
	var sb: StyleBoxFlat
	if is_muted:
		_mute_hud_button.text = "音：切"
		sb = _make_box_style(COLOR_CRIMSON, COLOR_GOLD, 1, 16, 10)
		_mute_hud_button.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		_mute_hud_button.text = "音：入"
		sb = _make_box_style(COLOR_SUMI, COLOR_GOLD, 1, 16, 10)
		_mute_hud_button.remove_theme_color_override("font_color")
	_mute_hud_button.add_theme_stylebox_override("normal", sb)


func _on_record_pressed() -> void:
	if not _in_game or _is_transitioning or _ending_card_overlay.visible:
		return
	_set_ui_hidden(false)
	_play_ui_click()
	_skip_mode = false
	_auto_mode = false
	_update_skip_button_visual()
	_update_auto_button_visual()
	_qol_overlays.open_save_load(true, true)


func _on_open_load_menu() -> void:
	_play_ui_click()
	_qol_overlays.open_save_load(false, false)


func _on_open_chapter_menu() -> void:
	_play_ui_click()
	_qol_overlays.open_chapter_select()


func _on_open_settings_pressed() -> void:
	if _in_game and (_is_transitioning or _ending_card_overlay.visible):
		return
	if _in_game:
		_set_ui_hidden(false)
	_play_ui_click()
	_qol_overlays.open_settings()


func _build_save_snapshot() -> Dictionary:
	_mark_current_line_read()
	var lines: Array = _current_scene.get("lines", [])
	var cur_line: Dictionary = {}
	if _line_index >= 0 and _line_index < lines.size():
		cur_line = lines[_line_index]
	var txt := str(cur_line.get("text", ""))
	var preview_full := txt
	if txt.length() > 42:
		txt = txt.substr(0, 42) + "…"
	var backlog_start := maxi(0, _backlog_entries.size() - 80)
	var backlog_slice: Array = []
	for i in range(backlog_start, _backlog_entries.size()):
		backlog_slice.append(_backlog_entries[i])
	var gm := _get_game_manager()
	var flags_val: Variant = gm.call("export_flags")
	var flags_copy: Dictionary = (flags_val as Dictionary).duplicate(true) if flags_val is Dictionary else {}
	var loc_now := _location_label.text if (_location_label != null and not _location_label.text.is_empty()) else str(_current_scene.get("location", ""))
	return {
		"episode_id": _current_episode_id,
		"episode_title": str(_current_episode.get("title", "")),
		"scene_id": _current_scene_id,
		"line_index": _line_index,
		"line_idx": _line_index,
		"chapter": str(_current_scene.get("chapter", "")),
		"title": str(_current_scene.get("title", "")),
		"location": loc_now,
		"speaker": str(cur_line.get("speaker", "")),
		"excerpt": txt,
		"preview_text": preview_full,
		"at_choices": _at_choices or _choice_overlay.visible,
		"backlog": backlog_slice,
		"flags": flags_copy,
		"session_flags": flags_copy.duplicate(true),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"saved_unix": Time.get_unix_time_from_system(),
	}


func _quick_save() -> void:
	if not _in_game or _is_transitioning or _ending_card_overlay.visible:
		return
	_save_store.write_slot("quick", _build_save_snapshot())
	_play_sm_se("ui_confirm", 0.78)
	_qol_overlays.show_toast("急速の栞（クイックセーブ）に記録しました")


func _quick_load() -> void:
	if not _save_store.has_slot("quick"):
		_qol_overlays.show_toast("急速の栞に記録がありません", true)
		return
	_play_sm_se("ui_confirm", 0.85)
	_on_qol_load_slot("quick")


func _on_qol_save_slot(slot_id: String) -> void:
	if not _in_game:
		return
	var snap := _build_save_snapshot()
	_save_store.write_slot(slot_id, snap)
	if slot_id == "1" or slot_id == "2" or slot_id == "3":
		_get_game_manager().call("save_slot", int(slot_id), snap)
	_play_sm_se("ui_confirm", 0.80)
	_qol_overlays.refresh_save_overlay_if_open()
	_qol_overlays.show_toast("%s に記録しました" % str(SaveStore.SLOT_LABELS.get(slot_id, slot_id)))


func _on_qol_load_slot(slot_id: String) -> void:
	var gm := _get_game_manager()
	var data := _save_store.get_slot(slot_id)
	if data.is_empty() and (slot_id == "1" or slot_id == "2" or slot_id == "3"):
		var gm_slot: Variant = gm.call("get_slot", int(slot_id))
		if gm_slot is Dictionary:
			data = gm_slot as Dictionary
	if data.is_empty():
		_qol_overlays.show_toast("記録データが見つかりません", true)
		return

	var saved_ep_id := str(data.get("episode_id", ""))
	if not saved_ep_id.is_empty() and saved_ep_id != _current_episode_id:
		var ep_info_val: Variant = gm.call("find_episode_by_id", saved_ep_id)
		if not (ep_info_val is Dictionary) or (ep_info_val as Dictionary).is_empty() or not _load_episode_data(ep_info_val as Dictionary):
			_qol_overlays.show_toast("対象作品のシナリオが見つかりません", true)
			return

	var scene_id := str(data.get("scene_id", ""))
	if not _scenes.has(scene_id):
		_qol_overlays.show_toast("保存先の章が見つかりません", true)
		return

	_qol_overlays.close_save_load()
	_begin_play_session()
	var saved_backlog: Variant = data.get("backlog", [])
	if saved_backlog is Array:
		for item in saved_backlog:
			if item is Dictionary:
				var raw_entry := item as Dictionary
				_backlog_entries.append({
					"chapter": str(raw_entry.get("chapter", "")),
					"title": str(raw_entry.get("title", "")),
					"speaker": str(raw_entry.get("speaker", "")),
					"text": str(raw_entry.get("text", "")),
				})

	var saved_flags: Variant = data.get("session_flags", data.get("flags", {}))
	gm.call("import_flags", saved_flags)
	var target_line := int(data.get("line_index", data.get("line_idx", 0)))
	var restore_choices := bool(data.get("at_choices", false))
	var append_first_backlog := _backlog_entries.is_empty()
	_enter_scene(scene_id, false, target_line, restore_choices, append_first_backlog)
	_qol_overlays.show_toast("%s から再開しました" % str(SaveStore.SLOT_LABELS.get(slot_id, slot_id)))


func _on_qol_delete_slot(slot_id: String) -> void:
	_play_ui_click()
	_save_store.delete_slot(slot_id)
	if slot_id == "1" or slot_id == "2" or slot_id == "3":
		_get_game_manager().call("delete_slot", int(slot_id))
	_qol_overlays.refresh_save_overlay_if_open()
	if not _in_game:
		_refresh_title_menu()
		if _portal_screen != null and _portal_screen.visible and not _qol_overlays.is_any_open():
			_refresh_portal_cards()
	_qol_overlays.show_toast("%s を消去しました" % str(SaveStore.SLOT_LABELS.get(slot_id, slot_id)))


func _on_qol_reset_all_save() -> void:
	_play_sm_se("ui_confirm", 0.85)
	_stop_voice_safe()
	_save_store.reset_all_save_data(false)
	_get_game_manager().call("reset_all_save_data")
	_save_store.set_active_episode(_current_episode_id if not _current_episode_id.is_empty() else SaveStore.DEFAULT_EPISODE_ID)
	_unlocked_endings = _save_store.unlocked_endings
	_backlog_entries.clear()

	if _in_game:
		_show_title_screen()
	else:
		_refresh_title_menu()
		if _portal_screen != null and _portal_screen.visible and not _qol_overlays.is_any_open():
			_refresh_portal_cards()
		if _gallery_overlay.visible:
			_open_gallery(_opened_gallery_from_portal)
		_qol_overlays.refresh_save_overlay_if_open()
		_qol_overlays.refresh_chapter_overlay_if_open()

	_qol_overlays.show_toast("セーブデータを初期化しました")


func _on_qol_chapter_selected(scene_id: String) -> void:
	if not _scenes.has(scene_id):
		return
	_play_sm_se("ui_confirm", 0.85)
	_get_game_manager().call("reset_flags")
	_begin_play_session()
	_enter_scene(scene_id, true, 0, false)


func _on_settings_changed() -> void:
	_apply_live_audio_volumes()


func _on_qol_overlay_closed(kind: String) -> void:
	if _in_game:
		if _choice_overlay.visible and _choices_container.get_child_count() > 0:
			_focus_control(_choices_container.get_child(0) as Control)
		else:
			_release_focus()
		return
	if _main_title_screen != null and _main_title_screen.visible:
		if kind == "settings" and _main_settings_btn != null:
			_focus_control(_main_settings_btn)
		elif kind == "save" and _main_continue_btn != null:
			_focus_control(_main_continue_btn)
		elif _main_series_btn != null:
			_focus_control(_main_series_btn)
		return
	if _portal_screen != null and _portal_screen.visible:
		_refresh_portal_cards()
		return
	match kind:
		"save":
			_refresh_title_menu()
			_focus_control(_load_menu_button)
		"chapter":
			_focus_control(_chapter_menu_button)
		"settings":
			_focus_control(_settings_menu_button)
		_:
			_focus_control(_start_button)


func _on_title_return_pressed() -> void:
	if not _in_game or _is_transitioning:
		return
	_set_ui_hidden(false)
	_skip_mode = false
	_update_skip_button_visual()
	_play_ui_click()
	_confirm_overlay.visible = true
	_focus_control(_confirm_no_btn)


func _close_confirm_overlay() -> void:
	_play_ui_click()
	_confirm_overlay.visible = false
	if _choice_overlay.visible and _choices_container.get_child_count() > 0:
		_focus_control(_choices_container.get_child(0) as Control)
	elif _ending_card_overlay.visible:
		_focus_control(_ending_gallery_btn)
	else:
		_release_focus()


func _confirm_return_to_title() -> void:
	_play_sm_se("ui_confirm", 0.78)
	_show_title_screen()


# --- エンディングカード＆図鑑 ---

func _show_ending_card(ending: Dictionary) -> void:
	_stop_voice_safe()
	_set_ui_hidden(false)
	_skip_mode = false
	_auto_mode = false
	_update_skip_button_visual()
	_update_auto_button_visual()

	var ed_id := str(ending.get("id", ""))
	var ed_num := str(ending.get("number", ""))
	var ed_title := str(ending.get("title", ""))
	var ed_sub := str(ending.get("subtitle", ""))

	_unlock_ending(ed_id)

	var frame_col := COLOR_GOLD
	var border_w := 3
	match ed_id:
		"END_1":
			frame_col = Color("C84A4A")
		"END_2":
			frame_col = Color("6AA6D8")
		"END_3":
			frame_col = Color("C8A86B")
		"END_4":
			frame_col = Color("8C82B8")
		"END_5_TRUE":
			frame_col = Color("E6C675")
			border_w = 4
	var end_sb := _make_box_style(Color(0.055, 0.048, 0.062, 0.96), frame_col, border_w, 72, 57)
	_ending_card_panel.add_theme_stylebox_override("panel", end_sb)
	_ending_num_label.add_theme_color_override("font_color", frame_col.lightened(0.18))

	if ed_id == "END_5_TRUE":
		_ending_num_label.text = "★ TRUE END ―― 終幕・第%s" % ed_num if not ed_num.is_empty() else "★ TRUE END"
	else:
		_ending_num_label.text = "終幕・第%s" % ed_num if not ed_num.is_empty() else "終幕"
	_ending_title_label.text = ed_title
	_ending_sub_label.text = ed_sub
	_play_sm_se("temple_bell", 0.9)

	var actions_row := _ending_gallery_btn.get_parent() as Control
	_ending_num_label.modulate.a = 0.0
	_ending_title_label.modulate.a = 0.0
	_ending_sub_label.modulate.a = 0.0
	if actions_row != null:
		actions_row.modulate.a = 0.0

	_ending_card_overlay.visible = true
	_ending_card_overlay.modulate = Color(1, 1, 1, 0)
	_ending_card_panel.pivot_offset = _ending_card_panel.size * 0.5
	_ending_card_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween()
	tw.tween_property(_ending_card_overlay, "modulate:a", 1.0, 0.50).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_ending_card_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.24)
	tw.tween_property(_ending_num_label, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ending_title_label, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ending_sub_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	if actions_row != null:
		tw.tween_property(actions_row, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	_focus_control(_ending_gallery_btn)


func _on_ending_to_gallery() -> void:
	_play_ui_click()
	_opened_gallery_from_ending = true
	_opened_gallery_from_portal = false
	_ending_card_overlay.visible = false
	_open_gallery(false)


func _on_ending_to_title() -> void:
	_play_ui_click()
	_show_title_screen()


func _on_open_gallery_pressed() -> void:
	_play_ui_click()
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = false
	_open_gallery(false)


func _on_open_portal_gallery_pressed() -> void:
	_play_ui_click()
	_opened_gallery_from_ending = false
	_opened_gallery_from_portal = true
	_open_gallery(true)


func _open_gallery(series_mode: bool = false) -> void:
	for c in _gallery_grid.get_children():
		c.queue_free()

	if series_mode:
		_gallery_grid.columns = 1
		if _gallery_title_label != null:
			_gallery_title_label.text = "シリーズ終幕録 ― IF : SURVIVE"
		var gm := _get_game_manager()
		var episodes: Array = gm.call("get_episodes") as Array
		var total_unlocked := _save_store.get_total_unlocked_endings()
		var avail_total := 0
		for item in episodes:
			if item is Dictionary and bool((item as Dictionary).get("available", false)):
				avail_total += int((item as Dictionary).get("total_endings", 5))
		_gallery_count_label.text = "シリーズ達成状況： %d / %d" % [total_unlocked, maxi(avail_total, 5)]
		_gallery_count_label.add_theme_color_override("font_color", COLOR_GOLD if total_unlocked > 0 else COLOR_PAPER)
		for item in episodes:
			if item is Dictionary:
				_gallery_grid.add_child(_create_series_gallery_row(item as Dictionary))
		_gallery_overlay.visible = true
		_focus_control(_gallery_close_btn)
		return

	_gallery_grid.columns = 2
	var ep_title := str(_current_episode.get("title", "本能寺・残照録"))
	if _gallery_title_label != null:
		_gallery_title_label.text = "終幕録 ― %s" % ep_title
	var total := int(_meta.get("totalEndings", max(_endings_catalog.size(), 5)))
	if _unlocked_endings.size() >= total and total > 0:
		_gallery_count_label.text = "達成状況： %d / %d　【全歴史踏破】" % [_unlocked_endings.size(), total]
		_gallery_count_label.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		_gallery_count_label.text = "達成状況： %d / %d" % [_unlocked_endings.size(), total]
		_gallery_count_label.add_theme_color_override("font_color", COLOR_PAPER)

	for ed in _endings_catalog:
		var ed_id := str(ed.get("id", ""))
		var unlocked := _unlocked_endings.has(ed_id)
		_gallery_grid.add_child(_create_ending_card_item(ed, unlocked))

	_gallery_overlay.visible = true
	_focus_control(_gallery_close_btn)


func _read_episode_endings(ep: Dictionary) -> Array[Dictionary]:
	var ep_id := str(ep.get("id", ""))
	if ep_id == _current_episode_id and not _endings_catalog.is_empty():
		return _endings_catalog
	var res: Array[Dictionary] = []
	var dir_path := str(ep.get("dir", ""))
	var scen_path := dir_path.path_join("scenario.json")
	if not FileAccess.file_exists(scen_path):
		return res
	var f := FileAccess.open(scen_path, FileAccess.READ)
	if f == null:
		return res
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return res
	var scs: Variant = (parsed as Dictionary).get("scenes", {})
	if scs is Dictionary:
		for sid in (scs as Dictionary).keys():
			var sc: Dictionary = (scs as Dictionary)[sid]
			if sc.has("ending") and sc["ending"] is Dictionary:
				var ed := (sc["ending"] as Dictionary).duplicate(true)
				ed["scene_id"] = sid
				res.append(ed)
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return res


func _create_series_gallery_row(ep: Dictionary) -> PanelContainer:
	var ep_id := str(ep.get("id", ""))
	var avail := bool(ep.get("available", false))
	var accent := Color(str(ep.get("accent_color", "#9E1B1B")))
	var unlocked_list := _save_store.get_episode_unlocked_endings(ep_id)
	var total_ends := int(ep.get("total_endings", _get_game_manager().call("get_total_endings", ep_id)))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 198)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _make_box_style(Color(0.095, 0.09, 0.12, 0.94) if avail else Color(0.06, 0.06, 0.08, 0.86), COLOR_GOLD if avail else Color(0.32, 0.30, 0.28, 0.6), 1, 28, 20)
	sb.border_width_left = 6
	sb.border_color = accent if avail else Color(accent.r, accent.g, accent.b, 0.35)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vbox.add_child(top)

	var ep_lbl := Label.new()
	ep_lbl.text = "【%s】 %s　%s（主人公：%s）" % [str(ep.get("era", "")), str(ep.get("title", "")), str(ep.get("subtitle", "")), str(ep.get("protagonist", ""))]
	ep_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ep_lbl.add_theme_color_override("font_color", COLOR_GOLD if avail else COLOR_MUTED)
	ep_lbl.add_theme_font_size_override("font_size", 24)
	top.add_child(ep_lbl)

	var cnt_lbl := Label.new()
	cnt_lbl.text = "終幕 %d / %d" % [unlocked_list.size(), total_ends] if avail else "準備中"
	cnt_lbl.add_theme_color_override("font_color", COLOR_GOLD if (avail and unlocked_list.size() >= total_ends) else (COLOR_PAPER if not unlocked_list.is_empty() else COLOR_MUTED))
	cnt_lbl.add_theme_font_size_override("font_size", 22)
	top.add_child(cnt_lbl)

	if not avail:
		var wait_lbl := Label.new()
		wait_lbl.text = "本編シナリオ実装後、到達した終幕の一覧と再鑑賞が解放されます。"
		wait_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		wait_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(wait_lbl)
		return card

	var eds := _read_episode_endings(ep)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for ed in eds:
		var ed_id := str(ed.get("id", ""))
		var is_true_end := (ed_id == "END_5_TRUE")
		var is_unlocked := unlocked_list.has(ed_id)
		var ed_num := str(ed.get("number", "?"))
		var ed_title := str(ed.get("title", "")) if is_unlocked else "？？？？？？"
		var replay_scene := str(ed.get("scene_id", ""))
		if is_unlocked and not replay_scene.is_empty():
			var rbtn := Button.new()
			rbtn.text = ("★ 真・第%s幕「%s」を再鑑賞" if is_true_end else "◆ 第%s幕「%s」を再鑑賞") % [ed_num, ed_title]
			rbtn.custom_minimum_size = Vector2(0, 48)
			rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rbtn.add_theme_font_size_override("font_size", 20)
			if is_true_end:
				rbtn.add_theme_color_override("font_color", COLOR_GOLD)
			rbtn.pressed.connect(func() -> void:
				_play_sm_se("ui_confirm", 0.85)
				if _load_episode_data(ep):
					_opened_gallery_from_ending = false
					_opened_gallery_from_portal = false
					_gallery_overlay.visible = false
					_begin_play_session()
					_enter_scene(replay_scene, true, 0, false)
			)
			grid.add_child(rbtn)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "・第%s幕「%s」（未到達）" % [ed_num, ed_title]
			lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lock_lbl.add_theme_color_override("font_color", COLOR_MUTED)
			lock_lbl.add_theme_font_size_override("font_size", 20)
			grid.add_child(lock_lbl)

	return card


func _create_ending_card_item(ed: Dictionary, unlocked: bool) -> PanelContainer:
	var ed_id := str(ed.get("id", ""))
	var is_true_end := (ed_id == "END_5_TRUE")
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(660, 232)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var border_col := (Color("E6C675") if is_true_end else COLOR_GOLD) if unlocked else Color(0.32, 0.30, 0.28, 0.7)
	var bg_col := (Color(0.15, 0.125, 0.08, 0.96) if is_true_end else Color(0.11, 0.095, 0.125, 0.95)) if unlocked else Color(0.06, 0.06, 0.08, 0.92)
	var border_w := 2 if (unlocked and is_true_end) else 1
	card.add_theme_stylebox_override("panel", _make_box_style(bg_col, border_col, border_w, 30, 20))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var num_lbl := Label.new()
	var num_str := str(ed.get("number", "?"))
	if unlocked and is_true_end:
		num_lbl.text = "★ 真・第%s幕" % num_str
	elif is_true_end:
		num_lbl.text = "真・第%s幕" % num_str
	else:
		num_lbl.text = "第%s幕" % num_str
	num_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num_lbl.add_theme_color_override("font_color", COLOR_GOLD if unlocked else COLOR_MUTED)
	num_lbl.add_theme_font_size_override("font_size", 24)
	top_row.add_child(num_lbl)

	var badge := Label.new()
	badge.text = ("【真終幕・達成済】" if is_true_end else "【達成済】") if unlocked else "【未到達】"
	badge.add_theme_color_override("font_color", (Color("E6C675") if is_true_end else COLOR_CRIMSON.lightened(0.28)) if unlocked else COLOR_MUTED)
	badge.add_theme_font_size_override("font_size", 23)
	top_row.add_child(badge)

	var title_lbl := Label.new()
	title_lbl.text = str(ed.get("title", "")) if unlocked else "？？？？？？"
	title_lbl.add_theme_color_override("font_color", COLOR_PAPER if unlocked else COLOR_MUTED)
	title_lbl.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = str(ed.get("subtitle", "")) if unlocked else ("真ルート条件を満たすと解放される終幕" if is_true_end else "分岐の選択により解放される終幕")
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_color_override("font_color", COLOR_GOLD if unlocked else Color(0.55, 0.53, 0.50, 0.8))
	sub_lbl.add_theme_font_size_override("font_size", 21)
	vbox.add_child(sub_lbl)

	if unlocked:
		var foot := HBoxContainer.new()
		foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		foot.alignment = BoxContainer.ALIGNMENT_END
		foot.add_theme_constant_override("separation", 14)
		vbox.add_child(foot)

		var loc_lbl := Label.new()
		loc_lbl.text = str(ed.get("location", ""))
		loc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loc_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		loc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		loc_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		loc_lbl.add_theme_font_size_override("font_size", 19)
		foot.add_child(loc_lbl)

		var replay_scene := str(ed.get("scene_id", ""))
		if not replay_scene.is_empty() and _scenes.has(replay_scene):
			var replay_btn := Button.new()
			replay_btn.text = "◆ 再鑑賞"
			replay_btn.custom_minimum_size = Vector2(150, 46)
			replay_btn.add_theme_font_size_override("font_size", 21)
			replay_btn.pressed.connect(func() -> void:
				_play_sm_se("ui_confirm", 0.85)
				_get_game_manager().call("reset_flags")
				_opened_gallery_from_ending = false
				_gallery_overlay.visible = false
				_begin_play_session()
				_enter_scene(replay_scene, true, 0, false)
			)
			foot.add_child(replay_btn)

	return card


func _close_gallery() -> void:
	_play_ui_click()
	_gallery_overlay.visible = false
	if _opened_gallery_from_ending:
		_opened_gallery_from_ending = false
		_ending_card_overlay.visible = true
		_focus_control(_ending_gallery_btn)
	elif _opened_gallery_from_portal:
		_opened_gallery_from_portal = false
		if _main_title_screen != null and _main_title_screen.visible and _main_gallery_btn != null:
			_focus_control(_main_gallery_btn)
		else:
			_refresh_portal_cards()
	elif not _in_game:
		_refresh_title_menu()
		_focus_control(_gallery_button)
	else:
		_release_focus()


# --- オーディオ（実ファイル＋AudioStreamGenerator フォールバック） ---

func _get_bgm_base_db() -> float:
	return -10.0 if _current_bgm_id == "title_theme" else -8.0


func _apply_live_audio_volumes() -> void:
	var sm := _get_sound_manager()
	if sm != null:
		var se_vol := clampf(float(_save_store.settings.get("se_volume", 0.90)), 0.0, 1.0)
		sm.call("set_volumes", 0.85, se_vol, 0.16 * se_vol)

	if _current_bgm_id.is_empty() or _current_bgm_id == "silence":
		return
	var is_muted := _is_sound_muted()
	if is_muted:
		if _bgm_tween != null and _bgm_tween.is_valid():
			_bgm_tween.kill()
			_bgm_tween = null
		if _bgm_player.playing:
			_bgm_player.volume_db = -80.0
		return

	var bgm_dir := str(_get_game_manager().call("resolve_audio_dir", "bgm", _current_episode_dir))
	var target_stream := _load_audio_safe(bgm_dir, _current_bgm_id, "bgm_", true, "bgm")
	if target_stream != null and (_bgm_tween != null and _bgm_tween.is_valid()):
		_bgm_tween.kill()
		_bgm_tween = null
		if _bgm_player.stream != target_stream:
			_bgm_player.stream = target_stream
			_bgm_player.play()
	if _bgm_player.playing:
		_bgm_player.volume_db = _get_bgm_base_db() + _save_store.get_bgm_gain_db()


func _play_bgm(bgm_id: String) -> void:
	if bgm_id.is_empty():
		return
	var mood_changed := (_mood_bgm_id != bgm_id)
	_mood_bgm_id = bgm_id
	if bgm_id == "silence":
		_stop_bgm(false)
		if mood_changed and _in_game and not _current_scene_id.is_empty():
			_apply_vignette_mood(_current_effect_name, _current_scene_id, _suppress_sfx_for_skip)
		return
	if bgm_id == _current_bgm_id and _bgm_player.playing:
		if mood_changed and _in_game and not _current_scene_id.is_empty():
			_apply_vignette_mood(_current_effect_name, _current_scene_id, _suppress_sfx_for_skip)
		return

	_current_bgm_id = bgm_id
	if mood_changed and _in_game and not _current_scene_id.is_empty():
		_apply_vignette_mood(_current_effect_name, _current_scene_id, _suppress_sfx_for_skip)
	var bgm_dir := str(_get_game_manager().call("resolve_audio_dir", "bgm", _current_episode_dir))
	var stream := _load_audio_safe(bgm_dir, bgm_id, "bgm_", true, "bgm")
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
		_bgm_tween = null

	if stream == null:
		# アセット未配置時はエラーを出さず無視
		_bgm_player.stop()
		_bgm_player.stream = null
		return

	var target_db := -80.0 if _is_sound_muted() else (_get_bgm_base_db() + _save_store.get_bgm_gain_db())
	if _bgm_player.playing and _bgm_player.stream != null:
		var prev_id := bgm_id
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0 if _is_sound_muted() else -48.0, 0.22).set_trans(Tween.TRANS_SINE)
		_bgm_tween.tween_callback(func() -> void:
			if _current_bgm_id != prev_id:
				return
			_bgm_player.stream = stream
			_bgm_player.volume_db = -80.0 if _is_sound_muted() else -38.0
			_bgm_player.play()
		)
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0 if _is_sound_muted() else (_get_bgm_base_db() + _save_store.get_bgm_gain_db()), 0.25).set_trans(Tween.TRANS_SINE)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = minf(-26.0, target_db)
		_bgm_player.play()
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", target_db, 0.30).set_trans(Tween.TRANS_SINE)


func _stop_bgm(clear_mood: bool = true) -> void:
	_current_bgm_id = ""
	if clear_mood:
		_mood_bgm_id = ""
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
		_bgm_tween = null
	if _bgm_player.playing:
		_bgm_player.stop()
	_bgm_player.stream = null


func _play_se(se_id: String) -> void:
	if se_id.is_empty() or _is_sound_muted():
		return
	var se_gain := _save_store.get_se_gain_db()
	if se_gain <= -79.0:
		return
	_play_sm_se(se_id, 1.0)


func _play_ui_click() -> void:
	_play_sm_se("ui_type", 0.6)


func _load_audio_safe(
	dir_path: String,
	audio_id: String,
	alt_prefix: String,
	should_loop: bool = false,
	cfg_key: String = ""
) -> AudioStream:
	var cache_key := "%s:%s:%s:%s" % [_current_episode_id, dir_path, audio_id, str(should_loop)]
	if _audio_cache.has(cache_key):
		return _audio_cache[cache_key] as AudioStream

	var candidates: Array[String] = []
	if not cfg_key.is_empty():
		var cfg_map: Variant = _assets_cfg.get(cfg_key, {})
		if cfg_map is Dictionary and (cfg_map as Dictionary).has(audio_id):
			var rel := str((cfg_map as Dictionary)[audio_id])
			if not rel.is_empty():
				candidates.append(_resolve_episode_path(rel))

	var prefixes := ["", alt_prefix]
	var exts := [".ogg", ".wav", ".mp3"]
	for pref in prefixes:
		for ext in exts:
			var path_str := "%s%s%s%s" % [dir_path, pref, audio_id, ext]
			if not candidates.has(path_str):
				candidates.append(path_str)

	for candidate in candidates:
		var stream: AudioStream = null
		if ResourceLoader.exists(candidate):
			var res := ResourceLoader.load(candidate)
			if res is AudioStream:
				stream = res as AudioStream
		elif candidate.ends_with(".ogg") and FileAccess.file_exists(candidate):
			var bytes := FileAccess.get_file_as_bytes(candidate)
			if not bytes.is_empty():
				var ogg_buf := AudioStreamOggVorbis.load_from_buffer(bytes)
				if ogg_buf != null:
					stream = ogg_buf
			if stream == null and OS.get_name() != "Web":
				var abs_path := ProjectSettings.globalize_path(candidate)
				var ogg := AudioStreamOggVorbis.load_from_file(abs_path)
				if ogg != null:
					stream = ogg
		if stream != null:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = should_loop
			_audio_cache[cache_key] = stream
			return stream
	return null


func _acquire_se_player() -> AudioStreamPlayer:
	var p := _se_pool[_se_pool_cursor]
	_se_pool_cursor = (_se_pool_cursor + 1) % _se_pool.size()
	p.stop()
	return p


func _play_synth_se(se_type: String, volume_db: float) -> void:
	var se_gain := _save_store.get_se_gain_db()
	if se_gain <= -79.0:
		return
	var p := _acquire_se_player()
	var dur := 0.25
	match se_type:
		"ui_click":
			dur = 0.06
		"ui_choice":
			dur = 0.14
		"gunshot", "gun_volley":
			dur = 0.48
		"door_slam", "crash_fire", "armor_march":
			dur = 0.38
		"fire_roar", "ocean_waves", "water_escape":
			dur = 0.55
		"war_horn", "battle_cry":
			dur = 0.55
		"sword_slash":
			dur = 0.24
		"shishi_odoshi":
			dur = 0.28
		"abacus_coins":
			dur = 0.24
		"ringing_ears":
			dur = 0.52
		"curtain_open":
			dur = 0.22

	p.stream = _get_or_build_synth_wav(se_type, dur)
	p.volume_db = volume_db + se_gain
	p.play()


func _get_or_build_synth_wav(se_type: String, dur: float) -> AudioStreamWAV:
	if _synth_wav_cache.has(se_type):
		return _synth_wav_cache[se_type] as AudioStreamWAV

	var sr_int := 22050
	var sr := float(sr_int)
	var total := maxi(int(dur * sr), 64)
	var pcm := PackedByteArray()
	pcm.resize(total * 2)

	var phase := 0.0
	var phase2 := 0.0
	var smooth_noise := 0.0

	for i in total:
		var t := float(i) / sr
		var env := 1.0 - (t / dur)
		var val := 0.0

		match se_type:
			"ui_click":
				var e := exp(-t * 68.0)
				val = (sin(TAU * 940.0 * t) * 0.65 + sin(TAU * 1880.0 * t) * 0.25 + randf_range(-0.2, 0.2) * exp(-t * 140.0)) * e * 0.42
			"ui_choice":
				var freq := lerpf(240.0, 155.0, minf(t / 0.10, 1.0))
				phase += TAU * freq / sr
				val = (sin(phase) * 0.65 + sin(TAU * 680.0 * t) * 0.35 * exp(-t * 28.0)) * exp(-t * 16.0) * 0.55
			"gunshot", "gun_volley":
				var echo := 1.0
				if se_type == "gun_volley" and t > 0.14:
					echo = 0.72 * exp(-(t - 0.14) * 14.0)
				var burst := randf_range(-1.0, 1.0) * exp(-t * 24.0)
				var thump := sin(TAU * lerpf(98.0, 34.0, minf(t / 0.16, 1.0)) * t) * exp(-t * 15.0)
				val = (burst * 0.75 + thump * 0.65) * echo * 0.65
			"door_slam", "crash_fire", "armor_march":
				var f := lerpf(118.0, 38.0, minf(t / 0.22, 1.0))
				phase += TAU * f / sr
				var rumble := randf_range(-0.4, 0.4) * exp(-t * 12.0)
				val = (sin(phase) * 0.78 + rumble) * exp(-t * 8.5) * 0.65
			"fire_roar", "ocean_waves", "water_escape", "curtain_open":
				smooth_noise = lerpf(smooth_noise, randf_range(-1.0, 1.0), 0.14)
				var swell := sin(PI * (t / dur))
				val = smooth_noise * swell * 0.55
			"war_horn", "battle_cry":
				var hf := 136.0 + sin(t * 9.0) * 14.0
				phase += TAU * hf / sr
				phase2 += TAU * (hf * 1.5) / sr
				val = (sin(phase) * 0.65 + sin(phase2) * 0.30) * sin(PI * (t / dur)) * 0.48
			"sword_slash":
				var sf := lerpf(3200.0, 880.0, minf(t / 0.18, 1.0))
				phase += TAU * sf / sr
				val = (sin(phase) * 0.5 + randf_range(-0.45, 0.45) * exp(-t * 26.0)) * exp(-t * 15.0) * 0.50
			"shishi_odoshi":
				var e_bamboo := exp(-t * 18.0)
				val = (sin(TAU * 540.0 * t) * 0.7 + sin(TAU * 1085.0 * t) * 0.32) * e_bamboo * 0.52
			"abacus_coins":
				var c1 := sin(TAU * 1650.0 * t) * exp(-t * 32.0)
				var c2 := (sin(TAU * 2210.0 * (t - 0.08)) * exp(-(t - 0.08) * 30.0)) if t > 0.08 else 0.0
				val = (c1 + c2) * 0.42
			"ringing_ears":
				var ring := sin(TAU * 2820.0 * t) * 0.25 * (1.0 - t / dur)
				var drop := sin(TAU * lerpf(90.0, 35.0, minf(t / 0.2, 1.0)) * t) * exp(-t * 14.0) * 0.6
				val = ring + drop
			_:
				var df := lerpf(135.0, 52.0, minf(t / 0.2, 1.0))
				phase += TAU * df / sr
				val = sin(phase) * env * 0.45

		# 末尾フェードアウトでクリックノイズ防止
		if i > total - 64:
			val *= float(total - i) / 64.0
		val = clampf(val, -0.95, 0.95)
		pcm.encode_s16(i * 2, clampi(int(round(val * 32767.0)), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr_int
	wav.stereo = false
	wav.data = pcm
	_synth_wav_cache[se_type] = wav
	return wav


# ==============================================================================
# カスタム描画インナークラス群（タイトル装飾・縦書き・背景フォールバック・立ち絵カード）
# ==============================================================================

class VerticalTitleView extends Control:
	var text: String = ""
	var font: Font = null
	var font_size: int = 72
	var char_step: float = 87.0
	var text_color: Color = Color("F2EFE9")
	var shadow_color: Color = Color(0.62, 0.11, 0.11, 0.7)
	var accent_color: Color = Color("C8A86B")

	const ROTATE_CHARS := ["ー", "〜", "～", "―", "－", "−", "（", "）", "(", ")", "「", "」", "『", "』", "【", "】", "…", "‥"]

	func _draw() -> void:
		if font == null or text.is_empty():
			return
		var cx := size.x * 0.5
		var y := float(font_size)
		for i in text.length():
			var ch := text.substr(i, 1)
			var csize := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			if ROTATE_CHARS.has(ch):
				var center := Vector2(cx, y - float(font_size) * 0.32)
				draw_set_transform(center + Vector2(3, 3), PI * 0.5)
				draw_string(font, Vector2(-csize.x * 0.5, csize.y * 0.25), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
				draw_set_transform(center, PI * 0.5)
				draw_string(font, Vector2(-csize.x * 0.5, csize.y * 0.25), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
				draw_set_transform(Vector2.ZERO, 0.0)
			else:
				var off_x := 0.0
				var off_y := 0.0
				if ch == "、" or ch == "。":
					off_x = float(font_size) * 0.30
					off_y = -float(font_size) * 0.28
				var pos := Vector2(cx - csize.x * 0.5 + off_x, y + off_y)
				draw_string(font, pos + Vector2(3, 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
				draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			y += char_step


class SealStampView extends Control:
	var font: Font = null
	var seal_text: String = "本能残照"

	func _draw() -> void:
		if size.x <= 4.0 or size.y <= 4.0:
			return
		var w := size.x
		var h := size.y
		var vermilion := Color(0.66, 0.12, 0.11, 0.90)
		var border_col := Color(0.84, 0.24, 0.20, 0.95)
		var ink_col := Color(0.95, 0.92, 0.86, 0.94)

		draw_rect(Rect2(0, 0, w, h), vermilion, true)
		draw_rect(Rect2(0, 0, w, h), border_col, false, 2.2)
		draw_rect(Rect2(5, 5, w - 10, h - 10), Color(ink_col.r, ink_col.g, ink_col.b, 0.45), false, 1.2)

		if font != null:
			var chars := seal_text if seal_text.length() >= 4 else "本能残照"
			# 伝統的な右列→左列の縦二行落款
			var slots := [
				Vector2(w * 0.69, h * 0.42),
				Vector2(w * 0.69, h * 0.77),
				Vector2(w * 0.31, h * 0.42),
				Vector2(w * 0.31, h * 0.77),
			]
			var fsz := 20
			for i in 4:
				var ch := chars.substr(i, 1)
				var center: Vector2 = slots[i]
				var csz := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
				draw_string(font, Vector2(center.x - csz.x * 0.5, center.y + csz.y * 0.12), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, ink_col)


class KamonEmblemView extends Control:
	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var r := minf(size.x, size.y) * 0.44
		var gold := Color(0.784, 0.659, 0.420, 0.92)
		var gold_soft := Color(0.784, 0.659, 0.420, 0.36)
		var crimson := Color(0.620, 0.106, 0.106, 0.92)
		var center := Vector2(cx, cy)

		draw_circle(center, r, Color(0.10, 0.08, 0.11, 0.85))
		draw_arc(center, r, 0.0, TAU, 64, gold, 2.4, true)
		draw_arc(center, r * 0.84, 0.0, TAU, 64, gold_soft, 1.4, true)

		# 輪違交差風の二円
		draw_arc(center + Vector2(-r * 0.18, 0.0), r * 0.42, 0.0, TAU, 48, gold, 1.8, true)
		draw_arc(center + Vector2(r * 0.18, 0.0), r * 0.42, 0.0, TAU, 48, gold, 1.8, true)

		# 中央の紅菱
		var d := r * 0.28
		var pts := PackedVector2Array([
			center + Vector2(0, -d),
			center + Vector2(d * 0.75, 0),
			center + Vector2(0, d),
			center + Vector2(-d * 0.75, 0),
		])
		draw_polygon(pts, PackedColorArray([crimson]))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), gold, 1.6)


class TitleBackdropView extends Control:
	var crest_center_ratio: Vector2 = Vector2(0.76, 0.46)
	var crest_radius: float = 330.0
	var _anim_t: float = 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_anim_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pulse := 0.85 + 0.15 * sin(_anim_t * 1.4)
		# 漆黒ベースから下部の紅の残照へ
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([
				Color("0B0B0E"),
				Color("0E0B10"),
				Color(0.28 * pulse, 0.04, 0.05, 1.0),
				Color("0B0B0E"),
			])
		)
		# 家紋風二重金輪（呼吸する残照と回転する繊細な飾り弧）
		var crest_center := Vector2(w * crest_center_ratio.x, h * crest_center_ratio.y)
		var r_breathe := crest_radius + sin(_anim_t * 0.9) * 4.5
		draw_circle(crest_center, r_breathe, Color(0.62, 0.11, 0.11, 0.095 * pulse))
		draw_arc(crest_center, r_breathe, 0.0, TAU, 96, Color(0.784, 0.659, 0.42, 0.22 * pulse), 2.2, true)
		draw_arc(crest_center, r_breathe - 21.0, _anim_t * 0.18, _anim_t * 0.18 + PI * 1.35, 64, Color(0.784, 0.659, 0.42, 0.14), 1.6, true)
		draw_arc(crest_center, r_breathe - 38.0, -_anim_t * 0.12, -_anim_t * 0.12 + PI * 0.90, 48, Color(0.784, 0.659, 0.42, 0.08), 1.2, true)
		# 画面上下の薄い箔金罫線
		draw_line(Vector2(66, 54), Vector2(w - 66, 54), Color(0.784, 0.659, 0.42, 0.25), 1.5)
		draw_line(Vector2(66, h - 54), Vector2(w - 66, h - 54), Color(0.784, 0.659, 0.42, 0.25), 1.5)


class FallbackBgView extends Control:
	var bg_id: String = ""

	func set_bg(new_bg_id: String) -> void:
		bg_id = new_bg_id
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top_col := Color("0B0B0E")
		var mid_col := Color("18181F")
		var bot_col := Color("241517")

		match bg_id:
			"bg_honnoji_fire":
				top_col = Color("0B080C")
				mid_col = Color("2A0D10")
				bot_col = Color("5C1313")
			"bg_kyoto_bamboo":
				top_col = Color("0A1014")
				mid_col = Color("182628")
				bot_col = Color("263936")
			"bg_osaka_council":
				top_col = Color("0D0C14")
				mid_col = Color("191926")
				bot_col = Color("32281B")
			"bg_yamazaki_camp":
				top_col = Color("0D1016")
				mid_col = Color("1D232D")
				bot_col = Color("2C2326")
			"bg_azuchi_throne":
				top_col = Color("09080E")
				mid_col = Color("181326")
				bot_col = Color("342919")
			"bg_sakai_galleon":
				top_col = Color("0A1320")
				mid_col = Color("142C42")
				bot_col = Color("4A3920")
			"bg_sakai_tearoom":
				top_col = Color("0E0B0A")
				mid_col = Color("201813")
				bot_col = Color("3B2A1B")
			"bg_kiyosu_inn":
				top_col = Color("08090F")
				mid_col = Color("141926")
				bot_col = Color("2C1B18")

		# 上下2段グラデーション
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.55), Vector2(0, h * 0.55)]),
			PackedColorArray([top_col, top_col, mid_col, mid_col])
		)
		draw_polygon(
			PackedVector2Array([Vector2(0, h * 0.55), Vector2(w, h * 0.55), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([mid_col, mid_col, bot_col, bot_col])
		)

		# モチーフ別和風シルエット
		var sil := Color(0.03, 0.03, 0.04, 0.62)
		var gold_soft := Color(0.784, 0.659, 0.42, 0.14)
		match bg_id:
			"bg_honnoji_fire":
				# 寺院の反り屋根シルエット
				draw_polygon(
					PackedVector2Array([
						Vector2(w * 0.16, h * 0.52),
						Vector2(w * 0.50, h * 0.36),
						Vector2(w * 0.84, h * 0.52),
						Vector2(w * 0.76, h * 0.56),
						Vector2(w * 0.24, h * 0.56),
					]),
					PackedColorArray([sil])
				)
				draw_rect(Rect2(w * 0.28, h * 0.55, 33, h * 0.35), sil)
				draw_rect(Rect2(w * 0.70, h * 0.55, 33, h * 0.35), sil)
			"bg_kyoto_bamboo":
				for bx in [0.10, 0.17, 0.26, 0.68, 0.78, 0.88]:
					draw_rect(Rect2(w * bx, 0, 18, h), Color(0.05, 0.08, 0.08, 0.48))
			"bg_azuchi_throne":
				draw_circle(Vector2(w * 0.75, h * 0.26), 102.0, Color(0.90, 0.88, 0.80, 0.12))
				draw_line(Vector2(0, h * 0.68), Vector2(w, h * 0.68), gold_soft, 2.2)
			"bg_sakai_galleon":
				draw_line(Vector2(0, h * 0.64), Vector2(w, h * 0.64), gold_soft, 2.2)
				draw_rect(Rect2(w * 0.48, h * 0.20, 12, h * 0.44), sil)
				draw_polygon(
					PackedVector2Array([Vector2(w * 0.49, h * 0.24), Vector2(w * 0.62, h * 0.46), Vector2(w * 0.49, h * 0.52)]),
					PackedColorArray([Color(0.85, 0.80, 0.70, 0.12)])
				)
			"bg_sakai_tearoom":
				draw_circle(Vector2(w * 0.50, h * 0.38), 172.5, Color(0.85, 0.76, 0.60, 0.09))
				draw_arc(Vector2(w * 0.50, h * 0.38), 172.5, 0.0, TAU, 64, gold_soft, 2.2, true)
			"bg_osaka_council":
				# 大坂本陣の金屏風風パネルと格子柱
				var fold_w := w * 0.14
				var start_x := w * 0.22
				for fi in 4:
					var px := start_x + fi * fold_w
					var py := h * (0.20 if fi % 2 == 0 else 0.215)
					draw_rect(Rect2(px, py, fold_w - 6.0, h * 0.44), Color(0.784, 0.659, 0.42, 0.06))
					draw_rect(Rect2(px, py, fold_w - 6.0, h * 0.44), gold_soft, false, 1.5)
				draw_rect(Rect2(w * 0.14, 0, 27, h), sil)
				draw_rect(Rect2(w * 0.86 - 27, 0, 27, h), sil)
			"bg_yamazaki_camp":
				# 山崎の稜線シルエットと陣幕・旗指物
				draw_polygon(
					PackedVector2Array([
						Vector2(0, h * 0.62),
						Vector2(w * 0.22, h * 0.40),
						Vector2(w * 0.48, h * 0.54),
						Vector2(w * 0.78, h * 0.36),
						Vector2(w, h * 0.56),
						Vector2(w, h),
						Vector2(0, h),
					]),
					PackedColorArray([sil])
				)
				for fx in [0.24, 0.31, 0.68, 0.75]:
					draw_line(Vector2(w * fx, h * 0.30), Vector2(w * fx, h * 0.68), gold_soft, 2.2)
					draw_rect(Rect2(w * fx + 3.0, h * 0.31, 27.0, 84.0), Color(0.62, 0.11, 0.11, 0.16))
			"bg_kiyosu_inn":
				# 清洲旅籠の障子格子と行灯の灯り・三日月
				draw_circle(Vector2(w * 0.78, h * 0.22), 51.0, Color(0.88, 0.86, 0.78, 0.14))
				draw_circle(Vector2(w * 0.793, h * 0.208), 45.0, top_col)
				draw_circle(Vector2(w * 0.24, h * 0.52), 81.0, Color(0.92, 0.72, 0.36, 0.09))
				for gx in 5:
					var x_pos := w * (0.16 + gx * 0.17)
					draw_line(Vector2(x_pos, 0), Vector2(x_pos, h), Color(0.784, 0.659, 0.42, 0.07), 1.5)
				for gy in [0.24, 0.46]:
					draw_line(Vector2(0, h * gy), Vector2(w, h * gy), Color(0.784, 0.659, 0.42, 0.05), 1.5)
			_:
				for gx in 5:
					var x_pos := w * (0.16 + gx * 0.17)
					draw_line(Vector2(x_pos, 0), Vector2(x_pos, h), Color(0.784, 0.659, 0.42, 0.05), 1.5)


class CharacterCardView extends Control:
	var font: Font = null
	var char_id: String = ""
	var char_name: String = ""
	var variant_name: String = ""
	var theme_color: Color = Color("9E1B1B")
	var accent_color: Color = Color("C8A86B")

	func set_character(id_str: String) -> void:
		char_id = id_str
		var parts := id_str.split("_", false, 1)
		var base := parts[0] if parts.size() > 0 else id_str
		variant_name = parts[1] if parts.size() > 1 else "default"

		match base:
			"nobunaga":
				char_name = "織田 信長"
				theme_color = Color("9E1B1B")
				accent_color = Color("C8A86B")
			"ranmaru":
				char_name = "森 蘭丸"
				theme_color = Color("3B7A8C")
				accent_color = Color("D2DFDC")
			"yasuke":
				char_name = "弥助"
				theme_color = Color("8A5A2B")
				accent_color = Color("D4B475")
			"mitsuhide":
				char_name = "明智 光秀"
				theme_color = Color("4B4E8A")
				accent_color = Color("C5CAE0")
			"hideyoshi":
				char_name = "羽柴 秀吉"
				theme_color = Color("B87E24")
				accent_color = Color("F0D38A")
			"sokyu":
				char_name = "今井 宗久"
				theme_color = Color("4A6656")
				accent_color = Color("C2B084")
			_:
				char_name = base
				theme_color = Color("555566")
				accent_color = Color("C8A86B")
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return

		var bg_top := Color(0.08, 0.08, 0.11, 0.92)
		var bg_bot := Color(theme_color.r * 0.36, theme_color.g * 0.36, theme_color.b * 0.36, 0.95)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([bg_top, bg_top, bg_bot, bg_bot])
		)

		# 外枠 & コーナー装飾
		draw_rect(Rect2(0, 0, w, h), accent_color, false, 2.2)
		draw_rect(Rect2(9, 9, w - 18, h - 18), Color(theme_color.r, theme_color.g, theme_color.b, 0.65), false, 1.5)
		var clen := 27.0
		for pt in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
			var sx := 1.0 if pt.x == 0.0 else -1.0
			var sy := 1.0 if pt.y == 0.0 else -1.0
			draw_line(pt + Vector2(4.5 * sx, 4.5 * sy), pt + Vector2(clen * sx, 4.5 * sy), accent_color, 3.0)
			draw_line(pt + Vector2(4.5 * sx, 4.5 * sy), pt + Vector2(4.5 * sx, clen * sy), accent_color, 3.0)

		# 背景家紋風オーラ
		var cx := w * 0.5
		draw_circle(Vector2(cx, h * 0.36), 111.0, Color(theme_color.r, theme_color.g, theme_color.b, 0.24))
		draw_arc(Vector2(cx, h * 0.36), 111.0, 0.0, TAU, 48, Color(accent_color.r, accent_color.g, accent_color.b, 0.38), 1.8, true)

		# 和風人物シルエット
		var sil := Color(0.04, 0.04, 0.06, 0.90)
		var rim := Color(accent_color.r, accent_color.g, accent_color.b, 0.45)
		# 胴体（着物・肩衣）
		var body_pts := PackedVector2Array([
			Vector2(cx - 39, h * 0.38),
			Vector2(cx + 39, h * 0.38),
			Vector2(cx + 132, h * 0.50),
			Vector2(cx + 114, h * 0.78),
			Vector2(cx - 114, h * 0.78),
			Vector2(cx - 132, h * 0.50),
		])
		draw_polygon(body_pts, PackedColorArray([sil]))
		draw_polyline(body_pts, rim, 1.8)
		# 頭部
		draw_circle(Vector2(cx, h * 0.27), 46.5, sil)
		draw_arc(Vector2(cx, h * 0.27), 46.5, 0.0, TAU, 32, rim, 1.8, true)

		# 差分アクセント
		if variant_name == "ronin":
			# 浪人編笠シルエット
			draw_polygon(
				PackedVector2Array([Vector2(cx - 84, h * 0.23), Vector2(cx, h * 0.14), Vector2(cx + 84, h * 0.23)]),
				PackedColorArray([sil])
			)
		elif variant_name == "wounded" or variant_name == "injured":
			draw_line(Vector2(cx - 48, h * 0.45), Vector2(cx + 42, h * 0.62), Color("C82828"), 3.8)
		elif variant_name == "combat":
			draw_line(Vector2(cx + 72, h * 0.66), Vector2(cx + 147, h * 0.28), Color(0.86, 0.88, 0.92, 0.75), 3.8)
		elif variant_name == "fan":
			draw_polygon(
				PackedVector2Array([Vector2(cx + 18, h * 0.58), Vector2(cx + 99, h * 0.46), Vector2(cx + 87, h * 0.68)]),
				PackedColorArray([Color(accent_color.r, accent_color.g, accent_color.b, 0.65)])
			)
		elif variant_name == "broker":
			draw_arc(Vector2(cx + 57, h * 0.58), 19.5, 0.0, TAU, 24, Color(accent_color.r, accent_color.g, accent_color.b, 0.72), 2.7, true)
			draw_arc(Vector2(cx + 78, h * 0.62), 16.5, 0.0, TAU, 24, Color(accent_color.r, accent_color.g, accent_color.b, 0.55), 2.4, true)
		elif variant_name == "smile" or variant_name == "joy":
			draw_arc(Vector2(cx, h * 0.27), 66.0, 0.0, TAU, 36, Color(accent_color.r, accent_color.g, accent_color.b, 0.35), 2.1, true)
		elif variant_name == "tears":
			draw_circle(Vector2(cx - 15, h * 0.31), 4.5, Color(0.68, 0.84, 0.98, 0.82))
			draw_circle(Vector2(cx + 15, h * 0.32), 4.5, Color(0.68, 0.84, 0.98, 0.82))

		# 下部ネームプレート
		var plate_y := h - 153.0
		draw_rect(Rect2(18, plate_y, w - 36, 129), Color(0.05, 0.05, 0.07, 0.88))
		draw_line(Vector2(27, plate_y), Vector2(w - 27, plate_y), accent_color, 1.8)

		if font != null:
			var name_sz := font.get_string_size(char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
			draw_string(font, Vector2((w - name_sz.x) * 0.5, plate_y + 51.0), char_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("F2EFE9"))

			var id_text := "[%s]" % char_id
			var id_sz := font.get_string_size(id_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21)
			draw_string(font, Vector2((w - id_sz.x) * 0.5, plate_y + 87.0), id_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, accent_color)

			var var_text := "差分: %s" % variant_name
			var var_sz := font.get_string_size(var_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			draw_string(font, Vector2((w - var_sz.x) * 0.5, plate_y + 114.0), var_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("A8A296"))
