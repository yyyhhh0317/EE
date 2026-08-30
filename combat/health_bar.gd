class_name HealthBar
extends Node2D
## 世界空间血条（挂在敌人头顶）。

@export var bar_width: float = 44.0
@export var bar_height: float = 6.0
@export var bar_color: Color = Color(0.85, 0.2, 0.2, 0.95)

var _fill: ColorRect

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 0.8)
	bg.position = Vector2(-bar_width / 2.0, 0)
	bg.size = Vector2(bar_width, bar_height)
	add_child(bg)
	_fill = ColorRect.new()
	_fill.color = bar_color
	_fill.position = Vector2(-bar_width / 2.0, 0)
	_fill.size = Vector2(bar_width, bar_height)
	add_child(_fill)

func set_value(ratio: float) -> void:
	if _fill != null:
		_fill.size.x = bar_width * clampf(ratio, 0.0, 1.0)
