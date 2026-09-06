class_name FloatingBackground
extends Control
## 漂浮的情绪因子光球背景装饰（主菜单 / 大厅）。

@export var orb_count: int = 14

var _orbs: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette := [UITheme.CYAN, UITheme.PURPLE, UITheme.RAGE, UITheme.GOLD, UITheme.FEAR, UITheme.HP]
	var vp := get_viewport_rect().size
	for i in orb_count:
		var orb := TextureRect.new()
		orb.texture = Placeholder.soft_glow(22, Color.WHITE)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = palette[i % palette.size()]
		var s := randf_range(0.6, 2.2)
		orb.scale = Vector2(s, s)
		orb.modulate = Color(col.r, col.g, col.b, randf_range(0.10, 0.32))
		orb.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		add_child(orb)
		_orbs.append({
			"node": orb,
			"vel": Vector2(randf_range(-16, 16), randf_range(-12, 12)),
			"base_a": orb.modulate.a,
			"phase": randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	for o in _orbs:
		var node: TextureRect = o["node"]
		var vel: Vector2 = o["vel"]
		node.position += vel * delta
		# 环绕回绕
		node.position.x = wrapf(node.position.x, -60.0, vp.x + 60.0)
		node.position.y = wrapf(node.position.y, -60.0, vp.y + 60.0)
		# 呼吸透明度
		o["phase"] += delta * 0.8
		var col: Color = node.modulate
		col.a = o["base_a"] * (0.6 + 0.4 * sin(o["phase"]))
		node.modulate = col
