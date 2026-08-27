---
name: amazon-linkfox-image-sop
description: Run a stable Amazon product-image workflow through LinkFox and an image model, with browser preflight, 270-compute defaults, human generation handoff, slot QA, dimension-image isolation, and final archiving. Use for LinkFox套图、Amazon主图/A+批量生图、九图修补或尺寸图归档；do not use for general image generation or unrelated browser automation.
---

# Amazon LinkFox 套图 SOP

这个 Skill 把公用 Amazon 套图流程变成固定的状态机。它先读取本次产品资料和使用者自己的配置，再做浏览器接管检查；没有接管证据时不得上传、填写或消耗 LinkFox 算力。

## 开工顺序

1. 读取当前项目中的产品资料、真实尺寸、正式参考图、禁用项、拍摄文档（如有）和 `templates/user-preferences.md` 对应的偏好卡。
2. 读取 [references/public-configuration.md](references/public-configuration.md)，确认项目路径、最终归档位置、命名规则和使用者自己的首次权限指南。
3. 建立任务状态，先写“资料待确认”；把缺失的产品事实、尺寸、禁用项、归档位置或命名规则一次性问全。
4. 收到“确认继续”后，读取 [references/browser-preflight.md](references/browser-preflight.md)，完成浏览器接管闸门，再读取 [references/linkfox-270-config.md](references/linkfox-270-config.md) 配置 LinkFox。

## 不可改变的生产规则

- 默认 LinkFox 任务为 `Img2`、`1K`、`中品质`，普通图白底 1、卖点 2、场景 1、特写 1、特写白底 0，A+ 自定比例 `W 9:H 6` 共 4 张，总计 9 张/270 算力。
- 尺寸图不进入 LinkFox，只能由图像模型直接生成；尺寸线、尺寸数字和单位不能写入 LinkFox 商品信息。
- 商品信息必须是 S1、S3–S6、A1–A4 的逐图蓝图，不能只写产品简介，也不能让白底图代替场景图。
- 配置完成后停在“开始生成”前，由使用者亲自点击、下载并回传九张图；Skill 绝不点击该按钮。
- 用户提供并明确验收主图时，才允许记录 8 张/240 的例外；不得因页面显示 240 自行跳过主图。

## 回传与收尾

收到九张图或明确缺陷后，读取 [references/image-qa-and-repair.md](references/image-qa-and-repair.md)，只修失败槽位。内置图像模型两次失败后转 GPT 网页图像模型；网页也失败就报告并停止，不改用代码、拼图或设计软件。

九张合格后直接制作尺寸图，提交十图验收；只有收到“确认十张”或“按此归档”才复制、命名和归档。任务状态字段和回执格式使用 [templates/task-status.md](templates/task-status.md)。

## 正常等待点

只有三处需要等待使用者：资料确认、亲自点击并回传九图、十图最终确认。其他颜色、模板、逐图措辞、修补方式和尺寸图风格，按已确认资料、拍摄文档、偏好和 references 自动推进。

## 公开使用边界

仓库内不保存账号、Token、私人飞书地址、个人电脑路径、产品图片或下载记录。使用者必须把自己的路径、命名规则、权限指南和偏好放在自己的项目中；更新公用规则时修改源仓库、运行校验器并更新 `CHANGELOG.md`，不要只改个人本地副本。
