extends Node
## EventBus —— 全局事件总线。
##
## 逻辑层只 emit，表现层（动画/音效/HUD）on 订阅，彻底解耦。
## 事件命名规范：`domain.action`，例如：
##   combat.damage_dealt / combat.entity_died
##   run.modifier_added / run.instability_changed
##   room.cleared / ui.toast

## 便捷入口：也可直接用 Godot 原生信号订阅该事件流。
signal event_emitted(event_name: String, payload: Variant)

var _listeners: Dictionary = {}  # event_name -> Array[Callable]

## 订阅事件。[br]callback 接收一个参数 payload。
func on(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	_listeners[event_name].append(callback)

## 取消订阅。
func off(event_name: String, callback: Callable) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].erase(callback)

## 广播事件。
func emit(event_name: String, payload: Variant = null) -> void:
	event_emitted.emit(event_name, payload)
	if _listeners.has(event_name):
		var arr: Array = _listeners[event_name]
		var invalid: Array = []
		for cb: Callable in arr:
			if not cb.is_valid():
				invalid.append(cb)
				continue
			cb.call(payload)
		for cb in invalid:
			arr.erase(cb)
