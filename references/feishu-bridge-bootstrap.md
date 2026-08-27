# 飞书控制通道首次引导

这个 Skill 在第一次读取飞书资料、飞书控制板或打开 LinkFox 前，必须先完成一次飞书控制通道门禁。宿主已经提供直连 Feishu MCP 时优先使用宿主通道；没有直连工具时使用本地 `lark-cli` 作为可验证的 Feishu bridge，不得把“没有 MCP 工具”伪装成已连接。

## 首次触发时的顺序

在任务专属暂存目录中运行随 Skill 分发的 `scripts/bootstrap-feishu-bridge.ps1 -Authorize`。它会：

1. 检查 `lark-cli`；如果缺失，自动执行官方包安装命令 `npm install --global @larksuite/cli`；
2. 运行 `lark-cli update`，让 CLI 与已绑定的 AI Skills 保持最新；如宿主支持全局 Skill pack，再可选执行 `npx skills add larksuite/cli -g -y`；
3. 运行 `lark-cli auth status --json --verify`；
4. 没有有效用户授权时，启动 `lark-cli auth login --domain docs --domain wiki --no-wait --json`，再用 `lark-cli auth qrcode <verification_url> --output <relative-local-path>` 生成二维码；
5. 输出授权链接和二维码的本机临时路径，然后暂停本次流程。

二维码和授权链接只存在于使用者本机临时目录或任务暂存目录，不写入公开仓库、日志归档或截图。不要索要、粘贴或保存 API key、Token、密码或 device code 到产品资料。

使用者在浏览器完成授权后回复 `已完成授权`。下一次继续时，用首次返回的 device code 执行 `lark-cli auth login --device-code <fresh-device-code>`，然后再次运行 `lark-cli auth status --json --verify`；只有用户身份显示 `verified: true` 才能继续。

如果 `lark-cli` 缺失，bootstrap 会自动调用已确认的官方包安装命令 `npm install --global @larksuite/cli`，再重新检查命令是否出现。若 `npm` 缺失、官方安装失败或无法联网，必须停止并报告准确错误，不能跳过门禁或改用未经确认的第三方安装命令。`npx skills add larksuite/cli -g -y` 仅作为宿主支持时的可选 Skill pack 安装，不把它的全局安装失败误报成 Feishu bridge 失败。

## 读取和写回飞书

授权通过后，先以用户身份读取当前 `飞书控制板`，再读取本次产品开发文档。公开 Skill 只使用占位符，例如 `FEISHU_CONTROL_BOARD_URL` 和 `FEISHU_PRODUCT_DOC_URL`，不要把真实飞书地址写进仓库。

文档写回必须遵守：先 fetch 当前内容，使用最小范围的 `str_replace` 或 block 操作，写入后再次 fetch 并核对实际文本。写回失败时保留原文并报告错误，不用 overwrite 破坏未参与本次变更的内容。
