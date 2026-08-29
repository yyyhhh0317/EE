extends Node
## AudioManager —— BGM / 音效管理（骨架：暂未接入音频资源）。
## 通过 EventBus 触发，例如 combat.hit → 播放对应音效。

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

## 播放音效（接入资源后按 id 查找播放）。
func play_sfx(id: String) -> void:
	EventBus.emit("audio.sfx", id)

## 播放 BGM（每章一个情绪主基调）。
func play_bgm(id: String) -> void:
	EventBus.emit("audio.bgm", id)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
