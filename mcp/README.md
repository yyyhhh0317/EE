# 文生图接入（Pollinations.ai）

这里给 DeepSeek Harness 接入 **Pollinations.ai** 的文生图能力——**免费、无需注册、无需 API Key、无需显卡**。

| 工具名（模型视角） | 作用 |
| --- | --- |
| `mcp__pollinations__generate_image` | 文生图，PNG/JPG 保存到 `art/`，返回路径 + 参数 |

## 已完成的接入

- 桥接脚本：`mcp/pollinations-imagegen.mjs`（Node，直连 `image.pollinations.ai`，Flux 模型）
  - **输出一定是真 PNG**：接口返回的通常是 JPEG，桥会用 `sharp`（位于 dsh profile 的 node_modules）
    重编码成 PNG 再写盘，避免「JPEG 字节配 .png 后缀」导致 Godot 首见导入失败。
- 已写入 DSH profile 配置：`C:\Users\17801\.dsh\profiles\web\cordis.patch.yml`

## 你只需要做 1 步

**重启 `dsh web` 进程**，工具列表里就会出现 `mcp__pollinations__generate_image`。
不需要任何 Key、账号或额外安装。

## 使用示例

> 生成一张 16:9 的像素风地牢场景图，存到 art/ 目录

模型会调用工具，把图存进 `D:\yyy\EE\art\`，并回报路径。

## 参数说明（我会按需传）

- `prompt`：提示词（支持中文）
- `width` / `height`：默认 1024
- `model`：默认 `flux`；`turbo` 更快但质量略低
- `seed`：固定种子可复现
- `enhance`：true 时让 Pollinations 自动润色提示词

## 提示与限制

- **免费服务的代价**：质量中上（Flux 级），偶尔慢或限流，高峰期可能要重试。
- 已默认加 `nologo=true`，去掉水印。
- 当前模型 `deepseek-v4-pro` 是纯文本：图会落盘、返回路径，但模型自己看不到图；
  想让我看图迭代，请在模型选择器切到 `deepseek-v4-flash-vision-exp`。
- 备用方案：`mcp/byte-imagegen.mjs` 是之前字节 Seedream 的桥（暂时闲置），
  以后若能开通火山方舟，把 `cordis.patch.yml` 换回去即可。
