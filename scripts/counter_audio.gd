extends Node
## Owns playback only. Gameplay sends semantic events.
var enabled: bool = true
var _effect: AudioStreamPlayer
var _music: AudioStreamPlayer

func _ready() -> void:
    _effect = AudioStreamPlayer.new()
    _music = AudioStreamPlayer.new()
    _music.volume_db = -22
    add_child(_effect)
    add_child(_music)
    var wave: AudioStreamWAV = load("res://assets/original/ambient.wav")
    wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wave.loop_end = wave.data.size() / 2 / (2 if wave.stereo else 1)
    _music.stream = wave

func set_enabled(value: bool) -> void:
    enabled = value
    if value and not _music.playing: _music.play()
    elif not value: _music.stop()

func play_event(event: String) -> void:
    if enabled:
        _effect.stream = load("res://assets/original/%s.wav" % event)
        _effect.play()

func _exit_tree() -> void:
    _effect.stop()
    _music.stop()
    _effect.stream = null
    _music.stream = null
