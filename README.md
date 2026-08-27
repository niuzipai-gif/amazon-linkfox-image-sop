# Amazon LinkFox 套图 SOP Skill

这是一个给 Codex 使用的公开 Skill，用来稳定执行 Amazon 商品套图流程：首次使用先自动引导 Feishu bridge，再检查浏览器是否真的能接管，配置 LinkFox 生成九张图，等待人亲自点击，收到图片后做 QA 和修补，最后用图像模型制作尺寸图并在确认后归档。

## 安装

在 PowerShell 中运行：

```powershell
git clone https://github.com/niuzipai-gif/amazon-linkfox-image-sop.git
cd amazon-linkfox-image-sop
pwsh -NoProfile -File .\scripts\install-skill.ps1
```

默认会安装到当前用户的 `.codex\skills\amazon-linkfox-image-sop`。如果目标目录已经存在，安装器会停止，不删除旧文件；确认备份后再加 `-Force` 覆盖同名文件。

## 第一次使用前

Skill 第一次触发时，会先执行 [references/feishu-bridge-bootstrap.md](references/feishu-bridge-bootstrap.md)：检查并尝试安装官方 Lark CLI Skill pack，运行 `lark-cli update` 和 `auth status`。缺少授权时自动启动 `auth login --no-wait --json`，用 `lark-cli auth qrcode` 输出二维码；使用者完成浏览器授权后回复“已完成授权”，Agent 再继续读取飞书控制板。公开 Skill 不保存真实飞书地址、Token 或 device code。

使用者先在自己的 Codex 项目中准备：

- 产品开发文档、卖点、真实尺寸和正式参考图；
- 项目文件夹、最终图片保存位置和命名规则；
- 自己的首次 Codex/Chrome/Edge 权限指南；
- 如有拍摄文档，标明它只能决定镜头、背景、光线、道具和顺序，不能改产品事实。

把自己的配置写进项目，不要把账号、密码、Token 或私人链接放进这个公开仓库。

## 最短触发方式

```text
使用 $amazon-linkfox-image-sop 执行这次 Amazon 套图任务。
项目资料在：[项目文件夹]
最终图片放在：[归档文件夹]
命名规则：[命名文档链接或按公用默认命名]
```

## 流程中的明确等待点

1. Agent 读完资料后，等你回复“确认继续”；
2. LinkFox 配置完成后，Agent 停在“开始生成”前，由你亲自点击并回传九张图；
3. 十张图完成后，等你说“确认十张”或“按此归档”。

其他颜色、模板、逐图蓝图、修补和尺寸图风格，按已确认资料自动推进，不反复追问。

## 默认硬规则

- LinkFox：`Img2`、`1K`、`中品质`，白底 1、卖点 2、场景 1、特写 1、特写白底 0，A+ 自定 `W 9:H 6` 共 4 张，合计 9 张/270 算力。
- 尺寸图不进入 LinkFox，只由图像模型制作。
- Agent 不点击 LinkFox 的开始生成按钮。
- 浏览器恢复不按固定次数停止；每次记录控制面、错误指纹、状态变化、对症动作和时间预算。同一错误指纹在同一状态下不重复，安全动作耗尽或预算用尽时报告原因。

## 后续更新

公用规则只改源仓库，先运行 `scripts/validate-sop-skill.ps1`、Python 测试和 `quick_validate.py`，再更新 `CHANGELOG.md` 并发布新版本。每位同事自己的路径、偏好和权限指南留在自己的项目里。
