class_name HealthBar
extends Node2D
## 世界空间血条（挂在敌人头顶）：圆角背景 + 圆角填充 + 细描边。

@export var bar_width: float = 44.0
@export var bar_height: float = 7.0
@export var bar_color: Color = Color(0.92, 0.28, 0.3, 0.95)

var _ratio: float = 1.0

func _ready() -> void:
	queue_redraw()

func set_value(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var r := bar_height * 0.5
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.05, 0.72)
	bg.border_color = Color(1, 1, 1, 0.18)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(int(r))
	draw_style_box(bg, Rect2(-bar_width * 0.5, -r, bar_width, bar_height))
	if _ratio > 0.0:
		var w := maxf(bar_width * _ratio, 2.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar_color
		fill.set_corner_radius_all(int(maxf(1.0, r - 1.0)))
		draw_style_box(fill, Rect2(-bar_width * 0.5 + 1.0, -r + 1.0, w - 2.0, bar_height - 2.0))
