extends Node
## リアルタイムSE・環境音合成＆外部SEハイブリッドマネージャ（Autoload: SoundManager）
## デスクトップでは AudioStreamGenerator を使用し、Web（シングルスレッド）では事前生成 WAV へ自動切替する

signal mute_changed(is_muted: bool)

const SAMPLE_RATE := 44100.0
const BUFFER_LENGTH := 0.08
const EXT_SE_POOL_SIZE := 4
const WAV_SE_POOL_SIZE := 6
const WEB_AMBIENT_SEC := 2.5

var master_volume: float = 0.85
var se_volume: float = 0.90
var ambient_volume: float = 0.16
var voice_volume: float = 1.0
var muted: bool = false

var _use_stream_generator: bool = true
var _gen_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _ext_se_pool: Array[AudioStreamPlayer] = []
var _ext_se_cursor: int = 0
var _wav_se_pool: Array[AudioStreamPlayer] = []
var _wav_se_cursor: int = 0
var _web_ambient_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer

var _active_voices: Array[Dictionary] = []
var _se_cache: Dictionary = {} # se_key -> PackedVector2Array
var _wav_se_cache: Dictionary = {} # se_key -> AudioStreamWAV
var _ext_se_cache: Dictionary = {} # path -> AudioStream
var _web_ambient_cache: Dictionary = {} # ambient_type -> AudioStreamWAV
var _voice_cache: Dictionary = {} # path -> AudioStream

var _current_ambient: String = "none"
var _ambient_gain: float = 0.0
var _ambient_target_gain: float = 0.0

var _pink_b0: float = 0.0
var _pink_b1: float = 0.0
var _pink_b2: float = 0.0
var _lp_state: float = 0.0
var _lp_state2: float = 0.0
var _ambient_phase: float = 0.0
var _droplet_timer: float = 0.0
var _droplet_freq: float = 1800.0
var _droplet_env: float = 0.0


func _ready() -> void:
	for _i in EXT_SE_POOL_SIZE:
		var ep := AudioStreamPlayer.new()
		add_child(ep)
		_ext_se_pool.append(ep)

	for _i in WAV_SE_POOL_SIZE:
		var wp := AudioStreamPlayer.new()
		add_child(wp)
		_wav_se_pool.append(wp)

	_web_ambient_player = AudioStreamPlayer.new()
	add_child(_web_ambient_player)

	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)

	_use_stream_generator = (OS.get_name() != "Web" and DisplayServer.get_name() != "headless")
	if _use_stream_generator:
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = SAMPLE_RATE
		generator.buffer_length = BUFFER_LENGTH

		_gen_player = AudioStreamPlayer.new()
		_gen_player.stream = generator
		add_child(_gen_player)
		_gen_player.play()
		_playback = _gen_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			_use_stream_generator = false


func _exit_tree() -> void:
	if _gen_player != null:
		_gen_player.stop()
		_gen_player.stream = null
	if _web_ambient_player != null:
		_web_ambient_player.stop()
		_web_ambient_player.stream = null
	if _voice_player != null:
		_voice_player.stop()
		_voice_player.stream = null
	for ep in _ext_se_pool:
		if ep != null:
			ep.stop()
			ep.stream = null
	for wp in _wav_se_pool:
		if wp != null:
			wp.stop()
			wp.stream = null
	_playback = null
	_active_voices.clear()
	_se_cache.clear()
	_wav_se_cache.clear()
	_ext_se_cache.clear()
	_web_ambient_cache.clear()
	_voice_cache.clear()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		stop_voice()
		for ep in _ext_se_pool:
			if ep.playing:
				ep.stop()
		for wp in _wav_se_pool:
			if wp.playing:
				wp.stop()
	_sync_web_ambient_volume()
	mute_changed.emit(muted)
	return muted


func set_volumes(new_master: float, new_se: float, new_ambient: float = -1.0, new_voice: float = -1.0) -> void:
	master_volume = clampf(new_master, 0.0, 1.0)
	se_volume = clampf(new_se, 0.0, 1.0)
	if new_ambient >= 0.0:
		ambient_volume = clampf(new_ambient, 0.0, 1.0)
	if new_voice >= 0.0:
		voice_volume = clampf(new_voice, 0.0, 1.0)
	_sync_web_ambient_volume()


func play_voice(voice_key: String, volume_scale: float = 1.0) -> void:
	if muted or voice_key.is_empty():
		return
	stop_voice()
	if not is_inside_tree() or _voice_player == null:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	for ext in [".ogg", ".wav"]:
		var path := str(gm.call("resolve_asset_path", "assets/voice/" + voice_key + ext))
		var stream := _load_audio_stream_from_path(path, _voice_cache)
		if stream != null:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = false
			elif stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
			_voice_player.stream = stream
			_voice_player.volume_db = linear_to_db(clampf(volume_scale * voice_volume * master_volume, 0.001, 1.0))
			_voice_player.play()
			return


func stop_voice() -> void:
	if _voice_player != null and _voice_player.playing:
		_voice_player.stop()


func play_se(se_key: String, volume_scale: float = 1.0) -> void:
	if muted or se_key.is_empty():
		return

	if _try_play_external_se(se_key, volume_scale):
		return

	match se_key:
		"ui_confirm":
			_trigger_synth("tsuba", 0.75 * volume_scale)
			_trigger_synth("taiko_low", 0.85 * volume_scale)
			return
		"gun_volley":
			for i in range(5):
				var delay := i * 0.045 + randf_range(0.0, 0.03)
				var timer := get_tree().create_timer(delay)
				timer.timeout.connect(func() -> void:
					if not muted and is_inside_tree():
						_trigger_synth("gunshot", randf_range(0.6, 0.95) * volume_scale)
				)
			return

	_trigger_synth(se_key, volume_scale)


func set_ambient(ambient_type: String) -> void:
	match ambient_type:
		"rain", "ocean", "ocean_waves":
			var target_name := "ocean" if ambient_type == "ocean_waves" else ambient_type
			if _current_ambient != target_name:
				_ambient_phase = 0.0
				_pink_b0 = 0.0
				_pink_b1 = 0.0
				_pink_b2 = 0.0
				_lp_state = 0.0
				_lp_state2 = 0.0
			_current_ambient = target_name
			_ambient_target_gain = 1.0
		_:
			_ambient_target_gain = 0.0


func stop_all_ambient() -> void:
	_ambient_target_gain = 0.0


func _process(delta: float) -> void:
	_ambient_gain = move_toward(_ambient_gain, _ambient_target_gain, delta * 1.2)
	if _ambient_gain <= 0.001 and _ambient_target_gain == 0.0:
		_current_ambient = "none"

	if not _use_stream_generator or _playback == null:
		_update_web_ambient()
		return

	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	var chunk := PackedVector2Array()
	chunk.resize(frames_available)

	for i in range(frames_available):
		var mix_l := 0.0
		var mix_r := 0.0

		if _ambient_gain > 0.001 and _current_ambient != "none":
			var amb := _sample_ambient()
			mix_l += amb.x * _ambient_gain * ambient_volume
			mix_r += amb.y * _ambient_gain * ambient_volume

		var v_idx := _active_voices.size() - 1
		while v_idx >= 0:
			var voice := _active_voices[v_idx]
			var samples: PackedVector2Array = voice["samples"]
			var cur: int = int(voice["cursor"])
			if cur < samples.size():
				var g: float = float(voice["gain"]) * se_volume
				mix_l += samples[cur].x * g
				mix_r += samples[cur].y * g
				voice["cursor"] = cur + 1
			else:
				_active_voices.remove_at(v_idx)
			v_idx -= 1

		if muted:
			chunk[i] = Vector2.ZERO
		else:
			chunk[i] = Vector2(tanh(mix_l * master_volume), tanh(mix_r * master_volume))

	_playback.push_buffer(chunk)


func _update_web_ambient() -> void:
	if _web_ambient_player == null:
		return
	if _current_ambient == "none" or _ambient_gain <= 0.001:
		if _web_ambient_player.playing:
			_web_ambient_player.stop()
		return
	var target_stream := _get_or_build_web_ambient_wav(_current_ambient)
	if target_stream != null and _web_ambient_player.stream != target_stream:
		_web_ambient_player.stream = target_stream
	if not _web_ambient_player.playing and _web_ambient_player.stream != null:
		_web_ambient_player.play()
	_sync_web_ambient_volume()


func _sync_web_ambient_volume() -> void:
	if _web_ambient_player == null:
		return
	if muted or _current_ambient == "none" or _ambient_gain <= 0.001:
		_web_ambient_player.volume_db = -80.0
		return
	var lin := clampf(_ambient_gain * ambient_volume * master_volume, 0.0, 1.0)
	_web_ambient_player.volume_db = -80.0 if lin <= 0.001 else linear_to_db(lin)


func _sample_ambient() -> Vector2:
	var white := randf_range(-1.0, 1.0)
	_ambient_phase += 1.0 / SAMPLE_RATE

	match _current_ambient:
		"rain":
			_pink_b0 = 0.99765 * _pink_b0 + white * 0.0990460
			_pink_b1 = 0.96300 * _pink_b1 + white * 0.2965164
			_pink_b2 = 0.57000 * _pink_b2 + white * 1.0526913
			var pink := (_pink_b0 + _pink_b1 + _pink_b2 + white * 0.1848) * 0.06
			_lp_state = _lp_state * 0.78 + pink * 0.22

			_droplet_timer -= 1.0 / SAMPLE_RATE
			if _droplet_timer <= 0.0:
				_droplet_timer = randf_range(0.08, 0.42)
				_droplet_freq = randf_range(1100.0, 2400.0)
				_droplet_env = randf_range(0.018, 0.055)
			var drop := sin(TAU * _droplet_freq * _ambient_phase) * _droplet_env
			_droplet_env *= 0.996

			return Vector2(_lp_state + drop, _lp_state * 0.95 - drop * 0.7)

		"ocean":
			_lp_state = _lp_state * 0.96 + white * 0.04
			_lp_state2 = _lp_state2 * 0.96 + _lp_state * 0.04
			var wave_mod := 0.35 + 0.65 * (0.5 + 0.5 * sin(_ambient_phase * 0.85))
			var s := _lp_state2 * 2.2 * wave_mod
			return Vector2(s, s * 0.92)

	return Vector2.ZERO


func _trigger_synth(se_key: String, volume_scale: float) -> void:
	if muted:
		return
	if not _se_cache.has(se_key):
		_se_cache[se_key] = _synthesize_se(se_key)
	var buf: PackedVector2Array = _se_cache[se_key]
	if buf.is_empty():
		return

	if _use_stream_generator and _playback != null:
		_active_voices.append({
			"samples": buf,
			"cursor": 0,
			"gain": volume_scale,
		})
	else:
		var wav := _get_or_build_se_wav(se_key, buf)
		var lin := clampf(volume_scale * se_volume * master_volume, 0.0, 1.0)
		if wav == null or lin <= 0.001 or _wav_se_pool.is_empty():
			return
		var wp := _wav_se_pool[_wav_se_cursor]
		_wav_se_cursor = (_wav_se_cursor + 1) % _wav_se_pool.size()
		wp.stop()
		wp.stream = wav
		wp.volume_db = linear_to_db(lin)
		wp.play()


func _get_or_build_se_wav(se_key: String, samples: PackedVector2Array) -> AudioStreamWAV:
	if _wav_se_cache.has(se_key):
		return _wav_se_cache[se_key] as AudioStreamWAV
	var wav := _samples_to_wav(samples, false)
	_wav_se_cache[se_key] = wav
	return wav


func _get_or_build_web_ambient_wav(amb_type: String) -> AudioStreamWAV:
	if _web_ambient_cache.has(amb_type):
		return _web_ambient_cache[amb_type] as AudioStreamWAV
	var count := int(SAMPLE_RATE * WEB_AMBIENT_SEC)
	var buf := PackedVector2Array()
	buf.resize(count)
	var saved_amb := _current_ambient
	_current_ambient = amb_type
	_ambient_phase = 0.0
	_pink_b0 = 0.0
	_pink_b1 = 0.0
	_pink_b2 = 0.0
	_lp_state = 0.0
	_lp_state2 = 0.0
	for i in range(count):
		var s := _sample_ambient()
		# ループ境界のクリック音を抑えるため先頭・末尾をわずかにクロスフェード
		var edge := 1.0
		if i < 1200:
			edge = float(i) / 1200.0
		elif i > count - 1200:
			edge = float(count - i) / 1200.0
		buf[i] = s * clampf(edge, 0.0, 1.0)
	_current_ambient = saved_amb
	var wav := _samples_to_wav(buf, true)
	_web_ambient_cache[amb_type] = wav
	return wav


func _samples_to_wav(samples: PackedVector2Array, loop_audio: bool) -> AudioStreamWAV:
	var count := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 4)
	for i in range(count):
		var lv := clampi(int(round(tanh(samples[i].x) * 32767.0)), -32768, 32767)
		var rv := clampi(int(round(tanh(samples[i].y) * 32767.0)), -32768, 32767)
		if lv < 0:
			lv += 65536
		if rv < 0:
			rv += 65536
		var base := i * 4
		bytes[base] = lv & 0xFF
		bytes[base + 1] = (lv >> 8) & 0xFF
		bytes[base + 2] = rv & 0xFF
		bytes[base + 3] = (rv >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = true
	wav.data = bytes
	if loop_audio:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav


func _synthesize_se(se_key: String) -> PackedVector2Array:
	match se_key:
		"gunshot":
			return _gen_gunshot()
		"tsuba":
			return _gen_tsuba()
		"sword_slash":
			return _gen_sword_slash()
		"shishi_odoshi":
			return _gen_shishi_odoshi()
		"tsuzumi", "ui_hover":
			return _gen_tsuzumi()
		"taiko", "taiko_low", "battle_cry":
			return _gen_taiko(54.0, 1.35)
		"door_slam", "crash_fire":
			return _gen_crash_impact()
		"fire_roar":
			return _gen_fire_burst()
		"war_horn":
			return _gen_war_horn()
		"ringing_ears":
			return _gen_ringing_ears()
		"abacus_coins":
			return _gen_abacus_click()
		"temple_bell":
			return _gen_temple_bell()
		"curtain_open", "water_escape", "armor_march", "ocean_waves":
			return _gen_whoosh_cloth()
		"ui_type":
			return _gen_paper_tick()
		_:
			return _gen_tsuzumi()


func _gen_gunshot() -> PackedVector2Array:
	var duration := 0.95
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var lp := 0.0
	var phase := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var white := randf_range(-1.0, 1.0)
		var cutoff := clampf(0.85 * exp(-t * 4.5) + 0.04, 0.04, 0.9)
		lp += (white - lp) * cutoff
		var crack := white * exp(-t * 95.0) * 1.1
		var freq := 38.0 + 102.0 * exp(-t * 28.0)
		phase += TAU * freq / SAMPLE_RATE
		var punch := sin(phase) * exp(-t * 14.0) * 0.85
		var env := exp(-t * 3.8)
		var sample := (crack + lp * env * 1.1 + punch) * 0.75
		out[i] = Vector2(sample, sample * 0.98)
	return out


func _gen_tsuba() -> PackedVector2Array:
	var duration := 0.75
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var freqs := [1840.0, 2765.0, 4130.0, 5890.0, 7420.0]
	var amps := [0.35, 0.30, 0.24, 0.16, 0.10]
	var decays := [6.5, 8.0, 10.5, 14.0, 18.0]
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var attack := clampf(t / 0.003, 0.0, 1.0)
		var metal := 0.0
		for k in range(freqs.size()):
			metal += sin(TAU * freqs[k] * t) * amps[k] * exp(-t * decays[k])
		var click := randf_range(-1.0, 1.0) * exp(-t * 180.0) * 0.35
		var s := (metal + click) * attack * 0.85
		out[i] = Vector2(s, s * 0.96)
	return out


func _gen_sword_slash() -> PackedVector2Array:
	var duration := 0.55
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var white := randf_range(-1.0, 1.0)
		lp += (white - lp) * clampf(0.45 * exp(-t * 6.0) + 0.05, 0.05, 0.5)
		var whoosh := (white - lp) * sin(clampf(t / 0.14, 0.0, 1.0) * PI) * 0.7
		var ring := (sin(TAU * 3150.0 * t) * 0.25 + sin(TAU * 4820.0 * t) * 0.18) * exp(-t * 9.0)
		var s := (whoosh + ring) * 0.85
		out[i] = Vector2(s, s)
	return out


func _gen_shishi_odoshi() -> PackedVector2Array:
	var duration := 0.90
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		var hit1 := (sin(TAU * 680.0 * t) * 0.35 + sin(TAU * 1340.0 * t) * 0.2) * exp(-t * 38.0)
		var click1 := randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.2
		s += hit1 + click1
		var t2 := t - 0.085
		if t2 >= 0.0:
			var bamboo := (
				sin(TAU * 528.0 * t2) * 0.65 * exp(-t2 * 7.5) +
				sin(TAU * 1065.0 * t2) * 0.32 * exp(-t2 * 12.0) +
				sin(TAU * 1620.0 * t2) * 0.14 * exp(-t2 * 20.0)
			)
			var wood_click := randf_range(-1.0, 1.0) * exp(-t2 * 190.0) * 0.35
			s += bamboo + wood_click
		out[i] = Vector2(s * 0.75, s * 0.72)
	return out


func _gen_tsuzumi() -> PackedVector2Array:
	var duration := 0.24
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var freq := 265.0 + 60.0 * (1.0 - exp(-t * 28.0))
		phase += TAU * freq / SAMPLE_RATE
		var body := sin(phase) * 0.75 + sin(phase * 2.18) * 0.22
		var slap := randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.25
		var env := exp(-t * 17.5) * clampf(t / 0.002, 0.0, 1.0)
		var s := (body * env + slap) * 0.65
		out[i] = Vector2(s, s)
	return out


func _gen_taiko(base_freq: float, duration: float) -> PackedVector2Array:
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var phase := 0.0
	var overtone_phase := 0.0
	var lp := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var freq := base_freq + 95.0 * exp(-t * 26.0)
		phase += TAU * freq / SAMPLE_RATE
		overtone_phase += TAU * (freq * 1.58) / SAMPLE_RATE
		var membrane := sin(phase) * 0.85 * exp(-t * 2.8) + sin(overtone_phase) * 0.28 * exp(-t * 6.5)
		lp = lp * 0.82 + randf_range(-1.0, 1.0) * 0.18
		var stick := lp * exp(-t * 55.0) * 1.2
		var attack := clampf(t / 0.004, 0.0, 1.0)
		var s := (membrane + stick) * attack * 0.9
		out[i] = Vector2(s, s)
	return out


func _gen_temple_bell() -> PackedVector2Array:
	var duration := 2.6
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var beat := 0.85 + 0.15 * sin(TAU * 2.2 * t)
		var bell := (
			sin(TAU * 138.0 * t) * 0.65 * exp(-t * 1.1) +
			sin(TAU * 276.5 * t) * 0.30 * exp(-t * 1.8) +
			sin(TAU * 412.0 * t) * 0.18 * exp(-t * 2.9) +
			sin(TAU * 695.0 * t) * 0.10 * exp(-t * 4.5)
		) * beat
		var attack := clampf(t / 0.015, 0.0, 1.0)
		var s := bell * attack * 0.75
		out[i] = Vector2(s, s * 0.97)
	return out


func _gen_crash_impact() -> PackedVector2Array:
	var taiko := _gen_taiko(42.0, 1.1)
	var gun := _gen_gunshot()
	var count := taiko.size()
	var out := PackedVector2Array()
	out.resize(count)
	for i in range(count):
		var g := gun[i] if i < gun.size() else Vector2.ZERO
		out[i] = taiko[i] * 0.75 + g * 0.65
	return out


func _gen_fire_burst() -> PackedVector2Array:
	var duration := 1.1
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		lp = lp * 0.93 + randf_range(-1.0, 1.0) * 0.07
		var env := sin(clampf(t / duration, 0.0, 1.0) * PI)
		out[i] = Vector2(lp * env * 1.8, lp * env * 1.7)
	return out


func _gen_war_horn() -> PackedVector2Array:
	var duration := 1.6
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var freq := 165.0 + 18.0 * clampf(t / 0.4, 0.0, 1.0) + sin(t * 28.0) * 2.5
		phase += TAU * freq / SAMPLE_RATE
		var horn := sin(phase) * 0.5 + sin(phase * 2.0) * 0.3 + sin(phase * 3.0) * 0.15
		var env := clampf(t / 0.25, 0.0, 1.0) * clampf((duration - t) / 0.45, 0.0, 1.0)
		var s := horn * env * 0.65
		out[i] = Vector2(s, s)
	return out


func _gen_ringing_ears() -> PackedVector2Array:
	var duration := 1.8
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := clampf(t / 0.08, 0.0, 1.0) * exp(-t * 1.8)
		var s := sin(TAU * 4250.0 * t) * env * 0.18
		out[i] = Vector2(s, s)
	return out


func _gen_abacus_click() -> PackedVector2Array:
	var duration := 0.35
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var offsets: Array[float] = [0.0, 0.06, 0.13]
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		for offset in offsets:
			var dt := t - offset
			if dt >= 0.0:
				s += (sin(TAU * 1900.0 * dt) * 0.4 + randf_range(-0.2, 0.2)) * exp(-dt * 85.0)
		out[i] = Vector2(s * 0.55, s * 0.55)
	return out


func _gen_whoosh_cloth() -> PackedVector2Array:
	var duration := 0.45
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		lp = lp * 0.88 + randf_range(-1.0, 1.0) * 0.12
		var env := sin(clampf(t / duration, 0.0, 1.0) * PI)
		out[i] = Vector2(lp * env * 0.9, lp * env * 0.85)
	return out


func _gen_paper_tick() -> PackedVector2Array:
	var duration := 0.03
	var count := int(SAMPLE_RATE * duration)
	var out := PackedVector2Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var s := randf_range(-1.0, 1.0) * exp(-t * 160.0) * 0.08
		out[i] = Vector2(s, s)
	return out


func _try_play_external_se(se_key: String, volume_scale: float) -> bool:
	if not is_inside_tree() or _ext_se_pool.is_empty():
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return false
	for ext in [".ogg", ".wav"]:
		var path := str(gm.call("resolve_asset_path", "assets/se/" + se_key + ext))
		var stream: AudioStream = _load_audio_stream_from_path(path, _ext_se_cache)
		if stream != null:
			var lin := clampf(volume_scale * se_volume * master_volume, 0.0, 1.0)
			if lin <= 0.001:
				return true
			var ep := _ext_se_pool[_ext_se_cursor]
			_ext_se_cursor = (_ext_se_cursor + 1) % _ext_se_pool.size()
			ep.stop()
			ep.stream = stream
			ep.volume_db = linear_to_db(lin)
			ep.play()
			return true
	return false


func _load_audio_stream_from_path(path: String, cache: Dictionary) -> AudioStream:
	if path.is_empty():
		return null
	if cache.has(path):
		return cache[path] as AudioStream

	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is AudioStream:
			stream = res as AudioStream
	elif FileAccess.file_exists(path):
		var low := path.to_lower()
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			if low.ends_with(".ogg"):
				stream = AudioStreamOggVorbis.load_from_buffer(bytes)
			elif low.ends_with(".wav"):
				stream = AudioStreamWAV.load_from_buffer(bytes)
		if stream == null and OS.get_name() != "Web":
			var abs_path := ProjectSettings.globalize_path(path)
			if low.ends_with(".ogg"):
				stream = AudioStreamOggVorbis.load_from_file(abs_path)
			elif low.ends_with(".wav"):
				stream = AudioStreamWAV.load_from_file(abs_path)

	if stream != null:
		cache[path] = stream
	return stream
