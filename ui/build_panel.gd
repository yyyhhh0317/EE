class_name BuildPanel
extends Control
## 六边形情绪构筑面板（v0.2）：
## 自绘 6 个环形槽位 + 相邻共鸣连线 + 共鸣/对立/污染/回路状态文字。
## 数据实时来自 BuildManager，build.changed 时重绘。

const SLOT_COUNT := 6
const CENTER := Vector2(120.0, 118.0)
const RING_RADIUS := 74.0
const HEX_RADIUS := 30.0

func _ready() -> void:
	EventBus.on("build.changed", _on_build_changed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _on_build_changed(_payload) -> void:
	queue_redraw()

func _slot_center(i: int) -> Vector2:
	# 槽 0 在正上方，顺时针排布（与 BuildManager.ADJACENT_PAIRS 环序一致）
	var ang := -PI / 2.0 + TAU * float(i) / float(SLOT_COUNT)
	return CENTER + Vector2(cos(ang), sin(ang)) * RING_RADIUS

func _hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var ang := TAU * float(k) / 6.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _factor_color(factor_id: String) -> Color:
	if factor_id == "":
		return Color(0.13, 0.13, 0.22)
	var f := DataManager.get_factor(factor_id)
	if f.is_empty():
		return Color(0.3, 0.3, 0.4)
	return Color(str(f.get("color", "#4dd8ff")))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 13
	# 面板底
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.10, 0.82), true)
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.PANEL_BORDER, false, 1.0)
	draw_string(font, Vector2(12, 22), "情绪共鸣构筑", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.CYAN)

	# 共鸣连线（相邻共鸣对）
	var adj := BuildManager.get_adjacent_resonance_stacks()
	var rows := DataManager.get_rows("resonances")
	for id in adj:
		var row: Dictionary = rows.get(id, {})
		var a := str(row.get("emotion_a", ""))
		var b := str(row.get("emotion_b", ""))
		for pair in BuildManager.ADJACENT_PAIRS:
			var i: int = pair[0]
			var j: int = pair[1]
			var ea := BuildManager.emotion_of_slot(i)
			var eb := BuildManager.emotion_of_slot(j)
			if (ea == a and eb == b) or (ea == b and eb == a):
				draw_line(_slot_center(i), _slot_center(j), UITheme.CYAN, 3.5)

	# 槽位六边形
	for i in SLOT_COUNT:
		var s := BuildManager.get_slot(i)
		var c := _slot_center(i)
		var filled := str(s.get("factor_id", "")) != ""
		var col := _factor_color(str(s.get("factor_id", "")))
		var pts := _hex_points(c, HEX_RADIUS)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.9 if filled else 0.35))
		# 因子技能图标（skill_*.png，素材缺失自动跳过）
		if filled:
			var icon := Art.skill_icon(str(s.get("factor_id", "")))
			if icon != null:
				var ics := 30.0
				draw_texture_rect(icon, Rect2(c + Vector2(-ics, -ics) * 0.5 - Vector2(0, 5), Vector2(ics, ics)), false)
		var border := Color(col.r * 1.4, col.g * 1.4, col.b * 1.4) if filled else UITheme.PANEL_BORDER
		draw_polyline(pts + PackedVector2Array([pts[0]]), border, 2.0)
		if filled:
			draw_string(font, c + Vector2(-14, 18), "Lv.%d" % int(s.get("level", 0)), HORIZONTAL_ALIGNMENT_LEFT, 28, 11, Color.WHITE)
		else:
			draw_string(font, c + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 8, 13, UITheme.TEXT_DIM)
		# 槽位号
		draw_string(font, c + Vector2(-4, 20), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 8, 10, UITheme.TEXT_DIM)

	# 状态文字
	var y := 232.0
	for id in adj:
		var row: Dictionary = rows.get(id, {})
		draw_string(font, Vector2(12, y), "%s ×%d" % [str(row.get("name", id)), int(adj[id])], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.CYAN)
		y += 20.0
	for row in BuildManager.get_active_opposites():
		draw_string(font, Vector2(12, y), "对立 · %s" % str(row.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.PURPLE)
		y += 20.0
	if BuildManager.is_full():
		draw_string(font, Vector2(12, y), "◆ 回路闭合 · F 情绪风暴", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.GOLD)
	else:
		draw_string(font, Vector2(12, y), "回路 %d/6" % BuildManager.get_occupied(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.TEXT_DIM)
	y += 20.0
	var pollution := BuildManager.dominant_pollution()
	if pollution != "":
		var row := BuildManager.get_pollution_row(pollution)
		draw_string(font, Vector2(12, y), "污染 · %s" % str(row.get("name", pollution)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITheme.RAGE)
		y += 20.0
	draw_string(font, Vector2(12, y), "同槽重复注射可升级（≤Lv5）", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT_DIM)
