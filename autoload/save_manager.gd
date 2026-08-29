extends Node
## SaveManager —— 存档读写（设置 / 局外进度 / 单局中断）。
## 统一 JSON + 版本号字段，写入 user:// 目录。

const SAVE_VERSION := 1

func _settings_path() -> String: return "user://settings.json"
func _meta_path() -> String: return "user://meta.json"
func _run_path() -> String: return "user://run_continue.json"

## ---- 设置 ----
func save_settings(data: Dictionary) -> void:
	_write_json(_settings_path(), data)

func load_settings() -> Dictionary:
	return _read_json(_settings_path())

## ---- 局外进度（meta 成长 / 图鉴 / 难度） ----
func save_meta(data: Dictionary) -> void:
	_write_json(_meta_path(), {"version": SAVE_VERSION, "data": data})

func load_meta() -> Dictionary:
	var payload := _read_json(_meta_path())
	return payload.get("data", {})

## ---- 单局中断（可选：续玩） ----
func save_run(data: Dictionary) -> void:
	_write_json(_run_path(), {"version": SAVE_VERSION, "data": data})

func load_run() -> Dictionary:
	var payload := _read_json(_run_path())
	return payload.get("data", {})

func has_run_save() -> bool:
	return FileAccess.file_exists(_run_path())

func clear_run() -> void:
	if FileAccess.file_exists(_run_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_run_path()))

## ---- 底层 ----
func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: 无法写入 %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
