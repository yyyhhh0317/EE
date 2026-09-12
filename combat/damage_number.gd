extends Node2D
## 飘字伤害数字（表现层，由 run 按 combat.damage_dealt 事件生成）。
## v0.2.1 素材接入：用 art/items/ 的像素数字逐字拼 Sprite2D
## （digit_* 普通 / digit_crit_* 暴击 / sym_* 符号）；素材缺失时跳过字符。

const SYM_FILES := {"+": "plus", "-": "minus", "!": "excl"}
const NORMAL_SCALE := 0.75   # 28px 素材 → 约 21px 显示（与旧字体大小接近）
const CRIT_SCALE := 1.0      # 暴击 45px 素材，更大更醒目

var _color: Color = Color.WHITE

static func _file_for(ch: String, crit: bool) -> String:
	if ch in "0123456789":
		return ("digit_crit_" if crit else "digit_") + ch
	if SYM_FILES.has(ch):
		return "sym_" + str(SYM_FILES[ch])
	return ""

func setup(amount: float, pos: Vector2, color: Color, crit: bool = false) -> void:
	_color = color
	global_position = pos + Vector2(randf_range(-10, 10), randf_range(-16, -4))
	var txt := str(int(round(amount)))
	var s := CRIT_SCALE if crit else NORMAL_SCALE
	var w := 0.0
	for ch in txt:
		var tex := Art.item_icon(_file_for(ch, crit))
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(s, s)
		spr.position = Vector2(w + float(tex.get_width()) * s * 0.5, 0)
		spr.modulate = color
		add_child(spr)
		w += float(tex.get_width()) * s + 2.0
	# 整体水平居中
	for c in get_children():
		c.position.x -= w * 0.5
	z_index = 100
	_animate()

func _animate() -> void:
	scale = Vector2(1.5, 1.5)
	var start := global_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", start + Vector2(0, -40), 0.6)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.5).set_delay(0.15)
	tween.chain().tween_callback(queue_free)
