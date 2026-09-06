extends Label
## 飘字伤害数字（表现层，由 run 按 combat.damage_dealt 事件生成）。

var _color: Color = Color.WHITE

func setup(amount: float, pos: Vector2, color: Color) -> void:
	_color = color
	position = pos + Vector2(-40, -12) + Vector2(randf_range(-10, 10), randf_range(-16, -4))
	size = Vector2(80, 24)
	text = str(int(round(amount)))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modulate = color
	z_index = 100
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	_animate()

func _animate() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(1.5, 1.5)
	var start := position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start + Vector2(0, -40), 0.6)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	tween.tween_property(self, "modulate", Color(_color.r, _color.g, _color.b, 0.0), 0.5).set_delay(0.15)
	tween.chain().tween_callback(queue_free)
