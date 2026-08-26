# Amazon LinkFox SOP Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将公用 Amazon 套图 V3.4 流程制作成可自动触发、可公开复制、能防止浏览器失控和错误生成的 Codex Skill，并发布到独立公开 GitHub 仓库。

**Architecture:** 以一个短 `SKILL.md` 作为路由入口，把浏览器接管闸门、LinkFox 270 配置、图片 QA/修补和公开配置拆成 references；用模板保存任务状态和用户偏好；用确定性的 PowerShell 校验器检查硬规则、占位符和私密路径。源仓库只含通用规则，个人飞书地址、本地路径、账号和产品资料由使用者在自己的项目中提供。

**Tech Stack:** Markdown、YAML、PowerShell 7+/Windows PowerShell、Python（仅用于 Codex `quick_validate.py` 和测试，不参与制图）、Git/GitHub CLI（发布阶段）。

---

## 文件结构

- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\SKILL.md` — 触发条件、硬规则、状态机和 references 路由。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\agents\openai.yaml` — 自动触发时的显示名称、摘要和默认提示。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\README.md` — 公开安装、首次准备、最短触发口令和使用边界。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\references\browser-preflight.md` — Chrome/Edge 接管前检查、会话互斥和三次停止规则。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\references\linkfox-270-config.md` — Img2/1K/中品质、9 张、270 算力和逐图蓝图。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\references\image-qa-and-repair.md` — 九图验收、槽位补位、图像模型路由和尺寸图隔离。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\references\public-configuration.md` — 项目路径、归档路径、命名规则、权限指南和偏好卡的占位配置。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\templates\task-status.md` — 任务状态、确认点、槽位 QA 和归档回读模板。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\templates\user-preferences.md` — 仅允许调整视觉、文案、拍摄文档和回执方式的偏好卡模板。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\scripts\validate-sop-skill.ps1` — 公开发布前的规则、私密信息和文件结构扫描。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\scripts\install-skill.ps1` — 将仓库内 Skill 安装到当前用户的 Codex skills 目录，支持 `-Destination` 覆盖。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\tests\test_validate_sop_skill.py` — 校验器和公开安全规则的隔离测试。
- Create: `C:\Users\Administrator\Documents\amazon-linkfox-image-sop\CHANGELOG.md` — 版本、规则变更和兼容性说明。

## Task 1: 建立失败测试和测试夹具

**Files:**
- Create: `tests/test_validate_sop_skill.py`
- Create: `tests/fixtures/valid-skill/SKILL.md`
- Create: `tests/fixtures/invalid-private-link/SKILL.md`
- Create: `tests/fixtures/invalid-hard-rule/SKILL.md`

- [ ] **Step 1: 写出校验器的失败测试**

测试必须覆盖三个可观察行为：合规 Skill 通过；含私人飞书链接或本机路径的内容失败；缺少 270/四张 9:6 A+/人工点击交接任一硬规则时失败。测试调用 `scripts/validate-sop-skill.ps1`，读取退出码和标准输出中的规则名称，不匹配文案细节。

```python
import subprocess
from pathlib import Path

ROOT = Path(__file__).parents[1]
VALIDATOR = ROOT / "scripts" / "validate-sop-skill.ps1"

def run_validator(skill_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(VALIDATOR), "-SkillPath", str(skill_dir)],
        text=True,
        capture_output=True,
        check=False,
    )

def test_valid_fixture_passes():
    result = run_validator(ROOT / "tests" / "fixtures" / "valid-skill")
    assert result.returncode == 0, result.stdout + result.stderr

def test_private_fixture_fails_closed():
    result = run_validator(ROOT / "tests" / "fixtures" / "invalid-private-link")
    assert result.returncode != 0
    assert "private" in (result.stdout + result.stderr).lower()

def test_hard_rule_fixture_fails_closed():
    result = run_validator(ROOT / "tests" / "fixtures" / "invalid-hard-rule")
    assert result.returncode != 0
    assert "270" in (result.stdout + result.stderr)
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `python -m pytest tests/test_validate_sop_skill.py -q`  
Expected: FAIL because `scripts/validate-sop-skill.ps1` and the fixture files do not yet exist.

- [ ] **Step 3: 建立最小夹具内容**

`valid-skill/SKILL.md` 只包含完整 frontmatter 和 270、四张 A+ 9:6、人工点击、尺寸图隔离、三次停止等短语；两个 invalid 夹具分别加入 `https://z41qdaw50z.feishu.cn/...` 和删除 `270` 硬规则。

- [ ] **Step 4: 提交测试夹具**

Run: `git add tests && git commit -m "test: define public SOP skill contract"`  
Expected: commit succeeds and only test files are included.

## Task 2: 编写公开 Skill 入口和界面元数据

**Files:**
- Create: `SKILL.md`
- Create: `agents/openai.yaml`

- [ ] **Step 1: 写入最小可路由的 `SKILL.md`**

入口必须声明仅在 Amazon 商品套图、LinkFox、A+ 批量生图、Chrome 接管或尺寸图归档任务时触发；明确不用于一般图片生成、普通网页自动化或不涉及 LinkFox 的 Amazon 文案任务。正文只保留以下决策规则，并链接到对应 reference：先读任务资料和本项目配置；先做浏览器接管闸门；默认 9 张/270；停在生成按钮前；九图回传后只修失败槽位；尺寸图由图像模型单独制作；最终确认后才归档。

- [ ] **Step 2: 按 `skill-creator` 的 openai YAML 规范创建元数据**

`agents/openai.yaml` 使用 `display_name: "Amazon LinkFox 套图 SOP"`、一条明确的中文 `short_description`、与入口一致的 `default_prompt`，并保持 `policy.allow_implicit_invocation: true`。创建前读取该版本 `skill-creator/references/openai_yaml.md`，不要添加不存在的依赖字段。

- [ ] **Step 3: 运行结构校验**

Run: `python -X utf8 C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py .`  
Expected: `Skill is valid!`；若报占位符错误，删除未替换的脚手架文本后重跑。

- [ ] **Step 4: 提交入口文件**

Run: `git add SKILL.md agents/openai.yaml && git commit -m "feat: add LinkFox SOP skill entrypoint"`  
Expected: commit succeeds.

## Task 3: 拆分浏览器闸门、LinkFox 配置和图片 QA references

**Files:**
- Create: `references/browser-preflight.md`
- Create: `references/linkfox-270-config.md`
- Create: `references/image-qa-and-repair.md`

- [ ] **Step 1: 写浏览器接管闸门**

写成 Agent 能直接照做的检查：列出标签页 → 按标题/网址/标签组/时间匹配 → 接管 → 读标题/网址/加载状态 → 再检查 LinkFox 四个页面状态。规定一个控制面、一个 Agent 持有标签页；只做短状态检查，不固定等待；同一问题最多三次；失败只报告阻塞并指向使用者自己的权限指南。保留 `openTabs()`/`claimTab()` 的语义，但不泄露私有会话 ID。

- [ ] **Step 2: 写 270 算力配置和人类交接**

明确 `Img2`、`1K`、`中品质`、白底 1、卖点 2、场景 1、特写 1、特写白底 0、A+ 自定 `W 9:H 6` 共 4、LinkFox 9 张/270 算力。明确尺寸图不进 LinkFox；Agent 配置后停在“开始生成”前，人亲自点击并回传九张；只有用户提供并验收主图才允许 8 张/240 例外。

- [ ] **Step 3: 写逐图蓝图和 QA/修补路由**

给出 S1、S3、S4、S5、S6、A1、A2、A3、A4 的不同职责和全局禁止项。收到九图后检查真实数量/轮廓/颜色/包装、白底和场景职责、重复构图、A+ 实际像素比例和水印；只补失败槽位。图像模型路由为内置第 1 次、同问题第 2 次、两次失败转 GPT 网页图像模型，网页再失败就报告并停止，不能改用代码或拼图。

- [ ] **Step 4: 运行 references 交叉检查**

Run: `rg -n "270|W 9:H 6|开始生成|尺寸图|claimTab|三次|两次" SKILL.md references`  
Expected: 入口和三个 references 之间的硬规则一致；任何 240 文本都只出现在“已验收主图例外”段落。

- [ ] **Step 5: 提交 references**

Run: `git add references && git commit -m "feat: codify browser and image workflow rules"`  
Expected: commit succeeds.

## Task 4: 增加公开配置、状态和偏好模板

**Files:**
- Create: `references/public-configuration.md`
- Create: `templates/task-status.md`
- Create: `templates/user-preferences.md`

- [ ] **Step 1: 写公开配置说明**

只使用 `PROJECT_ROOT`、`FINAL_ARCHIVE_ROOT`、`NAMING_SPEC`、`HUMAN_SETUP_GUIDE` 等占位变量，说明使用者必须自己填写；禁止 Skill 从旧聊天、下载目录或网页旧内容推测路径和命名。明确偏好只能改视觉、文案、拍摄文档使用和回执方式。

- [ ] **Step 2: 写状态模板**

模板必须包含“资料待确认、LinkFox 配置中、等待人类点击、九图自动 QA/修补、十图待最终确认、已归档”六态；包含唯一确认点、270 配置回执、九图槽位 QA、尺寸图数值、最终确认和归档回读。

- [ ] **Step 3: 写偏好卡模板**

字段包含偏好持有人、原话、确认日期、适用范围、可影响项目和不允许覆盖的硬规则。没有确认偏好时，Agent 必须输出“无已确认偏好，按公用默认”。

- [ ] **Step 4: 提交模板**

Run: `git add references/public-configuration.md templates && git commit -m "feat: add portable task and preference templates"`  
Expected: commit succeeds.

## Task 5: 编写安装器、公开 README 和变更记录

**Files:**
- Create: `scripts/install-skill.ps1`
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: 写安装器的安全行为**

安装器接受 `-Destination`，默认解析为 `$env:USERPROFILE\.codex\skills\amazon-linkfox-image-sop`；目标已存在时停止并提示备份或明确 `-Force`，不删除用户文件。复制前先运行校验器，校验不通过就不安装；成功后输出安装路径和触发口令。

- [ ] **Step 2: 写公开 README**

README 用大白话说明安装、第一次权限准备、最短触发句、三个需要人停留的节点，以及“Agent 不点击 LinkFox 开始生成”的原因。示例不能出现私人飞书地址、真实本地路径、账号或产品资料。

- [ ] **Step 3: 写 CHANGELOG**

记录 `1.0.0` 对应 V3.4 规则，包括 270 算力、A+ 四张 9:6、浏览器接管闸门、两次内置图像模型失败转网页和人工点击交接。

- [ ] **Step 4: 提交公开包装文件**

Run: `git add scripts/install-skill.ps1 README.md CHANGELOG.md && git commit -m "feat: package portable public skill"`  
Expected: commit succeeds.

## Task 6: 实现校验器并让测试通过

**Files:**
- Create: `scripts/validate-sop-skill.ps1`
- Modify: `tests/test_validate_sop_skill.py` only if the real output contract requires a narrow assertion change.

- [ ] **Step 1: 实现目录和 frontmatter 检查**

校验器检查 `SKILL.md` 存在、目录名为小写字母/数字/连字符且不超过 64 字符、YAML frontmatter 含 `name` 和 `description`、`agents/openai.yaml` 和四个 references 存在。

- [ ] **Step 2: 实现硬规则检查**

校验器必须在 Skill 内容和 references 中找到 `270`、`Img2`、`1K`、`中品质`、`W 9:H 6`、四张 A+、停在开始生成前、人工点击、尺寸图不进 LinkFox、三次浏览器停止和两次内置图像模型后转网页。缺任意一项就返回非零。

- [ ] **Step 3: 实现公开安全扫描**

拒绝 `feishu.cn`、`chatgpt.com/share` 之外的个人分享链接、`C:\Users\Administrator`、`E:\批量出图指挥区`、常见 Token/密钥字段和常见个人邮箱；允许 README 中说明“由使用者自行填写”的占位字段。输出只列文件名和规则，不输出整段敏感内容。

- [ ] **Step 4: 实现安装器调用校验器的接口**

让安装器以自身仓库根目录调用 `validate-sop-skill.ps1`；校验退出码非零时立刻停止复制。为路径加引号，支持 Windows PowerShell 和 PowerShell 7 的同一参数名。

- [ ] **Step 5: 运行测试并确认通过**

Run: `python -m pytest tests/test_validate_sop_skill.py -q`  
Expected: 3 tests PASS；随后运行 `pwsh -NoProfile -File scripts/validate-sop-skill.ps1 -SkillPath .`，Expected: `PASS` 且退出码 0。

- [ ] **Step 6: 提交校验器**

Run: `git add scripts/validate-sop-skill.ps1 tests && git commit -m "test: validate public SOP safety and hard rules"`  
Expected: commit succeeds.

## Task 7: 完成隔离烟测和本机 Skill 安装

**Files:**
- Create: `tests/fixtures/smoke-task/资料说明.md`
- Create: `tests/fixtures/smoke-task/任务状态与回执.md`

- [ ] **Step 1: 建立虚构产品烟测资料**

使用不对应任何真实产品的“木质桌面收纳盒”虚构资料，只测试状态输出和规则映射，不打开浏览器、不上传文件、不调用 LinkFox、不调用图像模型。

- [ ] **Step 2: 运行完整本地验证**

Run: `python -m pytest -q`; `pwsh -NoProfile -File scripts/validate-sop-skill.ps1 -SkillPath .`; `python -X utf8 C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py .`  
Expected: 所有测试 PASS、公开安全扫描 PASS、`Skill is valid!`。

- [ ] **Step 3: 安装到当前用户 Skill 目录**

Run: `pwsh -NoProfile -File scripts/install-skill.ps1 -Destination C:\Users\Administrator\.codex\skills\amazon-linkfox-image-sop`  
Expected: 校验通过后复制完成；随后对安装目录再次运行 quick validation。

- [ ] **Step 4: 检查干净状态**

Run: `git status --short`  
Expected: 只剩计划中已提交的文件；不把本机诊断日志、产品图片、任务暂存目录或权限截图加入仓库。

## Task 8: 创建独立公开 GitHub 仓库并发布

**Files:**
- Modify: Git remote metadata only; no private workspace files.

- [ ] **Step 1: 检查 GitHub 登录和仓库可见性**

Run: `gh auth status`; `gh repo view niuzipai-gif/amazon-linkfox-image-sop --json name,isPrivate,url`  
Expected: 如果仓库不存在，记录“待创建”；如果已存在，确认它是公开仓库且为空或只含本次 Skill 文件。若未登录，停止并让用户完成 GitHub 登录。

- [ ] **Step 2: 创建或绑定独立公开仓库**

若仓库不存在，运行：`gh repo create niuzipai-gif/amazon-linkfox-image-sop --public --source . --remote origin --description "Portable Codex skill for Amazon LinkFox batch image SOP"`。若仓库已存在，运行：`git remote add origin https://github.com/niuzipai-gif/amazon-linkfox-image-sop.git`（远程已存在时不重复添加）。

- [ ] **Step 3: 发布并检查远程文件**

Run: `git push -u origin master`; `gh repo view niuzipai-gif/amazon-linkfox-image-sop --web`  
Expected: 推送成功，默认分支可见；随后用 `gh api repos/niuzipai-gif/amazon-linkfox-image-sop/contents` 检查公开根目录只出现 Skill、references、templates、scripts、tests 和 docs，不出现本机路径、诊断日志或产品图。

- [ ] **Step 4: 记录发布版本**

Run: `git tag v1.0.0`; `git push origin v1.0.0`; `gh release create v1.0.0 --title "Amazon LinkFox SOP Skill v1.0.0" --notes-file CHANGELOG.md`  
Expected: tag 和 release 创建成功，release 页面链接可打开。

## Task 9: 发布后回归与交付

**Files:**
- Modify: `CHANGELOG.md` only if the published commit or validation command needs recording.

- [ ] **Step 1: 从远程干净目录做复现安装**

Run: `git clone https://github.com/niuzipai-gif/amazon-linkfox-image-sop.git $env:TEMP\amazon-linkfox-image-sop-smoke`; `pwsh -NoProfile -File .\scripts\install-skill.ps1 -Destination $env:TEMP\codex-skill-install`  
Expected: 干净目录中校验和安装成功，不依赖 `E:\批量出图指挥区` 或本机私有文件。

- [ ] **Step 2: 核对公开使用说明**

确认 README 能让新同事理解：要先准备自己的权限、何时回复“确认继续”、何时亲自点击、何时回传九图、何时确认十张；确认所有专有地址都写成由使用者填写。

- [ ] **Step 3: 给用户交付**

交付 GitHub 仓库链接、Skill 安装命令、本机安装路径、版本号和验证结果；说明后续规则更新必须先改源仓库、跑同一套校验、更新 CHANGELOG，再推送新版本，不能只改某个人的本地副本。

- [ ] **Step 4: 最终提交**

Run: `git status --short`; `git log --oneline --decorate -5`  
Expected: 工作树干净，最新提交和 `v1.0.0` 可见。

## Plan self-review

- Spec coverage: Task 2 covers public Skill entry and automatic routing; Task 3 covers browser gate, 270 configuration, human click handoff, image repair and dimension-image isolation; Task 4 covers portable configuration, task state and preferences; Tasks 5–8 cover packaging, validation, installation and GitHub publication; Task 9 covers clean-room verification and future update discipline.
- Placeholder scan: no `TODO`, `TBD`, vague “later” steps, or unspecified implementation behavior are used; all commands have expected outcomes.
- Type/contract consistency: all references use the exact names from the file structure; validator parameter is consistently `-SkillPath`; installer parameter is consistently `-Destination`; default production contract remains 9 LinkFox images/270 compute plus one separate dimension image.
