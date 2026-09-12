class_name UITheme
extends RefCounted
## 统一 UI 主题：配色 + 控件样式（黑暗生物实验室 + 霓虹因子风）。
## 用法：在 UI 场景根 Control 的 _ready() 里 `theme = UITheme.build_theme()`，
## 其下所有 Button / LineEdit / Label 自动继承；面板用 stylebox 单独设置。

# ---- 调色板 ----
const BG_DEEP := Color("0a0a16")      # 最深底
const BG := Color("10101f")           # 常规底
const PANEL := Color("1a1a2e")        # 面板底
const PANEL_ALT := Color("151525")    # 面板底（次级）
const PANEL_BORDER := Color("2e2e4a") # 面板描边
const CYAN := Color("4dd8ff")         # 因子·精准（主色）
const PURPLE := Color("b06bff")       # 混沌·失控
const RAGE := Color("ff4d5e")         # 怒
const GOLD := Color("ffd166")         # 喜/货币
const HP := Color("4ade80")           # 生命
const FEAR := Color("a06bff")         # 惧
const TEXT := Color("e8e8f5")         # 主文字
const TEXT_DIM := Color("9a9ab5")     # 次级文字

## 因子主题色：统一取数据表 color（唯一色源）；查不到时回退 UI 主色 CYAN。
static func factor_color(id: String) -> Color:
	var f := DataManager.get_factor(id)
	if f.is_empty():
		return CYAN
	return Color(str(f.get("color", "#4dd8ff")))

## 生成一个圆角描边样式盒。
static func stylebox(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, border_width: int = 1, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## 卡片素材样式盒：art/items/card.png（九宫格拉伸）；素材缺失回退程序样式盒。
static func card_stylebox(border_color: Color) -> StyleBox:
	var card_tex := Art.item_icon("card")
	if card_tex == null:
		return stylebox(PANEL, border_color, 16, 1, 30)
	var sb := StyleBoxTexture.new()
	sb.texture = card_tex
	sb.texture_margin_left = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_bottom = 28.0
	sb.content_margin_left = 56.0
	sb.content_margin_right = 56.0
	sb.content_margin_top = 28.0
	sb.content_margin_bottom = 28.0
	return sb

## 构建全局控件主题（字体沿用系统默认，只统一大小/配色/样式）。
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16

	# Button
	t.set_stylebox("normal", "Button", stylebox(Color("1e1e33"), PANEL_BORDER, 9, 1, 18))
	t.set_stylebox("hover", "Button", stylebox(Color("262642"), CYAN, 9, 1, 18))
	t.set_stylebox("pressed", "Button", stylebox(Color("13132a"), PURPLE, 9, 1, 18))
	t.set_stylebox("disabled", "Button", stylebox(Color("171722"), Color("232338"), 9, 1, 18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("55556e"))
	t.set_font_size("font_size", "Button", 18)

	# LineEdit
	t.set_stylebox("normal", "LineEdit", stylebox(Color("13131f"), PANEL_BORDER, 7, 1, 10))
	t.set_stylebox("focus", "LineEdit", stylebox(Color("13131f"), CYAN, 7, 1, 10))
	t.set_stylebox("read_only", "LineEdit", stylebox(Color("13131f"), PANEL_BORDER, 7, 1, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)

	# Label
	t.set_color("font_color", "Label", TEXT)

	# Panel
	t.set_stylebox("panel", "Panel", stylebox(PANEL, PANEL_BORDER, 12, 1, 16))
	return t

## 给 Label 统一加：字号 + 描边 + 阴影（霓虹观感）。
static func label(l: Label, size: int, color: Color, outline: int = 6, shadow: int = 3) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", shadow)
	l.add_theme_constant_override("shadow_offset_y", shadow)
