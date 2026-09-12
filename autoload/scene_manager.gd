extends Node
## SceneManager —— 场景切换与参数传递。

var _pending_params: Dictionary = {}

## 切换到指定场景（路径需是 .tscn）。
## 注意：延迟到帧末执行，避免在 autoload _ready（节点树忙）期间直接换场景。
func goto(scene_path: String, params: Dictionary = {}) -> void:
	_pending_params = params
	get_tree().call_deferred("change_scene_to_file", scene_path)

## 读取上一个场景传入的参数。
func get_params() -> Dictionary:
	return _pending_params

## 清空参数。
func clear_params() -> void:
	_pending_params = {}
