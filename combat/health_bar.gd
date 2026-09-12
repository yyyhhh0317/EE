class_name HealthBar
extends Node2D
## 世界空间血条（挂在敌人头顶）· v0.2.1 素材接入：
## 优先用 art/items/ 的进度条素材（bar_frame/bar_fill_hp 或 boss_bar_frame/boss_bar_fill），
## 素材缺失时回退程序绘制（圆角背景 + 圆角填充 + 细描边）。

@export var bar_width: float = 44.0
@export var bar_height: float = 7.0
@export var bar_color: Color = Color(0.92, 0.28, 0.3, 0.95)
@export var use_boss_style: bool = false

var _ratio: float = 1.0
var _frame: Texture2D
var _fill: Texture2D

func _ready() -> void:
	if use_boss_style:
		_frame = Art.item_icon("boss_bar_frame")
		_fill = Art.item_icon("boss_bar_fill")
	else:
		_frame = Art.item_icon("bar_frame")
		_fill = Art.item_icon("bar_fill_hp")
	queue_redraw()

func set_value(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if _frame != null and _fill != null:
		_draw_texture_bar()
	else:
		_draw_programmatic()

## 素材血条：按外框宽高比缩放（以 bar_height 定高），填充用源区域裁剪实现扣血。
func _draw_texture_bar() -> void:
	var fw := float(_frame.get_width())
	var fh := float(_frame.get_height())
	var w := bar_height * fw / fh
	var rect := Rect2(-w * 0.5, -bar_height * 0.5, w, bar_height)
	if _ratio > 0.0:
		# 填充按外框内边距比例内缩
		var inset_x := (fw - float(_fill.get_width())) * 0.5 * (w / fw)
		var inset_y := (fh - float(_fill.get_height())) * 0.5 * (bar_height / fh)
		var fill_rect := rect.grow(-inset_x)
		fill_rect.position.y = rect.position.y + inset_y
		fill_rect.size.y = rect.size.y - inset_y * 2.0
		var ratio := clampf(_ratio, 0.0, 1.0)
		var src := Rect2(0, 0, float(_fill.get_width()) * ratio, float(_fill.get_height()))
		var dst := Rect2(fill_rect.position, Vector2(fill_rect.size.x * ratio, fill_rect.size.y))
		draw_texture_rect_region(_fill, dst, src)
	draw_texture_rect(_frame, rect, false)

## 回退：程序绘制（素材缺失时）。
func _draw_programmatic() -> void:
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
