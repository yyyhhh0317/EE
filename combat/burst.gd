extends Sprite2D
## 拾取 / 使用爆发特效：圆形快速放大并淡出。

func setup(pos: Vector2, color: Color) -> void:
	global_position = pos
	texture = Placeholder.circle(6, Color.WHITE)
	modulate = color
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(3.0, 3.0), 0.3)
	tween.tween_property(self, "modulate", Color(color.r, color.g, color.b, 0.0), 0.3)
	tween.chain().tween_callback(queue_free)
