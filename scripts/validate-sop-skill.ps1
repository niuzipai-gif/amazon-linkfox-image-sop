[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SkillPath
)

$ErrorActionPreference = 'Stop'
$failures = 0

function Add-Failure {
    param([string]$Rule)
    $script:failures++
    Write-Output "FAIL [$Rule]"
}

try {
    $resolvedPath = (Resolve-Path -LiteralPath $SkillPath -ErrorAction Stop).Path
} catch {
    Write-Output "FAIL [path] Skill path does not exist"
    exit 1
}

if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    Add-Failure 'path'
}

$folderName = Split-Path -Leaf $resolvedPath.TrimEnd('\', '/')
if ($folderName -notmatch '^[a-z0-9-]{1,64}$') {
    Add-Failure 'folder-name'
}

$requiredFiles = @(
    'SKILL.md',
    'agents/openai.yaml',
    'references/browser-preflight.md',
    'references/linkfox-270-config.md',
    'references/image-qa-and-repair.md',
    'references/public-configuration.md',
    'templates/task-status.md',
    'templates/user-preferences.md'
)

foreach ($relativeFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedPath $relativeFile) -PathType Leaf)) {
        Add-Failure "structure:$relativeFile"
    }
}

$skillFile = Join-Path $resolvedPath 'SKILL.md'
if (Test-Path -LiteralPath $skillFile -PathType Leaf) {
    $skillText = Get-Content -LiteralPath $skillFile -Raw -Encoding UTF8
    if ($skillText -notmatch '(?sm)^---\s*.*?^name:\s*[^\r\n]+.*?^description:\s*[^\r\n]+.*?^---') {
        Add-Failure 'frontmatter'
    }
}

$runtimeFiles = @()
foreach ($relativeFile in @('SKILL.md', 'README.md', 'CHANGELOG.md', 'LICENSE')) {
    $candidate = Join-Path $resolvedPath $relativeFile
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $runtimeFiles += $candidate }
}
foreach ($directory in @('agents', 'references', 'templates')) {
    $candidate = Join-Path $resolvedPath $directory
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        $runtimeFiles += Get-ChildItem -LiteralPath $candidate -Recurse -File | Select-Object -ExpandProperty FullName
    }
}

$combinedText = (($runtimeFiles | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`n")

$hardRules = [ordered]@{
    '270' = '270'
    'Img2' = 'Img2'
    '1K' = '1K'
    'quality' = '中品质'
    'a-plus-ratio' = 'W\s*9\s*:\s*H\s*6'
    'four-a-plus' = '(?i)(四张\s*A\+|A\+[^\r\n]{0,80}4\s*张|four\s+A\+\s+images)'
    'human-click' = '(?i)(亲自点击|human\s+click|由使用者亲自点击)'
    'dimension-isolation' = '(?i)(尺寸图.{0,40}(不进入|不在|外)\s*LinkFox|LinkFox.{0,40}(不做|不能做)尺寸图|dimension.{0,40}outside\s+LinkFox)'
    'browser-stop' = '(?i)(三次|three\s+checks|最多三次)'
    'image-fallback' = '(?i)(两次|two).{0,50}(内置|internal).{0,50}(网页|web|GPT)'
}

foreach ($rule in $hardRules.GetEnumerator()) {
    if ($combinedText -notmatch $rule.Value) {
        Add-Failure "hard-rule:$($rule.Key)"
    }
}

$publicSafetyRules = [ordered]@{
    'private-domain' = '(?i)(feishu\.cn|chatgpt\.com/share|plugin://)'
    'local-path' = '(?i)[A-Z]:\\Users\\[^\s`"''<>)]+' 
    'workspace-path' = '(?i)(E:\\批量出图指挥区|C:\\Users\\Administrator)'
    'secret-value' = '(?i)(api[_-]?key|access[_-]?token|secret|password)\s*[:=]\s*[''"“”]?[^\s''"“”]{12,}'
    'personal-email' = '(?i)\b[A-Z0-9._%+-]+@(?!example\.com\b|users\.noreply\.github\.com\b)[A-Z0-9.-]+\.[A-Z]{2,}\b'
}

foreach ($rule in $publicSafetyRules.GetEnumerator()) {
    $matchedFile = $null
    foreach ($file in $runtimeFiles) {
        $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        if ($text -match $rule.Value) {
            $matchedFile = [IO.Path]::GetFileName($file)
            break
        }
    }
    if ($null -ne $matchedFile) {
        Add-Failure "public:$($rule.Key):$matchedFile"
    }
}

if ($failures -gt 0) {
    Write-Output "Validation failed: $failures rule(s)."
    exit 1
}

Write-Output 'PASS: Skill structure, hard rules, and public safety checks passed.'
exit 0
