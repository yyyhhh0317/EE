class_name Placeholder
extends RefCounted
## 无美术资源时的占位纹理生成（M1 原型用，后续替换为真实素材）。

## 生成实心圆纹理（白色，配合 modulate 上色）。
static func circle(radius: int, color: Color) -> Texture2D:
	var size := radius * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r2 := radius * radius
	for y in size:
		for x in size:
			var dx := x - radius
			var dy := y - radius
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
