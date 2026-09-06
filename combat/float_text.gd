extends Label
## 通用飘字（拾取 / 注射 / 提示等）。

var _color: Color = Color.WHITE

func setup(text: String, pos: Vector2, color: Color) -> void:
	_color = color
	position = pos + Vector2(-60, -14) + Vector2(randf_range(-8, 8), randf_range(-8, -4))
	size = Vector2(120, 24)
	self.text = text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modulate = color
	z_index = 100
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	_animate()

func _animate() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(1.3, 1.3)
	var start := position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start + Vector2(0, -36), 0.7)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)
	tween.tween_property(self, "modulate", Color(_color.r, _color.g, _color.b, 0.0), 0.6).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
