extends Sprite2D
## 拾取 / 使用爆发特效：软辉光快速放大并淡出。

func setup(pos: Vector2, color: Color) -> void:
	global_position = pos
	texture = Placeholder.soft_glow(18, Color.WHITE)
	modulate = color
	scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.6, 2.6), 0.35)
	tween.tween_property(self, "modulate", Color(color.r, color.g, color.b, 0.0), 0.35)
	tween.chain().tween_callback(queue_free)
