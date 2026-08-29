extends Node
## SceneManager —— 场景切换与参数传递。

var _pending_params: Dictionary = {}

## 切换到指定场景（路径需是 .tscn）。
func goto(scene_path: String, params: Dictionary = {}) -> void:
	_pending_params = params
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneManager.goto 失败: %s (err=%s)" % [scene_path, err])

## 读取上一个场景传入的参数。
func get_params() -> Dictionary:
	return _pending_params

## 清空参数。
func clear_params() -> void:
	_pending_params = {}
