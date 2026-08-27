[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Destination = (Join-Path $env:USERPROFILE '.codex\skills\amazon-linkfox-image-sop'),

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot 'validate-sop-skill.ps1'

if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw "Validator missing: $validator"
}

$validationOutput = & $validator -SkillPath $source 2>&1
$validationCode = $LASTEXITCODE
$validationOutput | ForEach-Object { Write-Host $_ }
if ($validationCode -ne 0) {
    throw "Skill validation failed; installation stopped."
}

if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
    throw "Destination already exists: $Destination. Back it up or rerun with -Force; no files were deleted."
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$runtimeItems = @('SKILL.md', 'agents', 'references', 'templates', 'scripts', 'README.md', 'CHANGELOG.md', 'LICENSE')
foreach ($item in $runtimeItems) {
    $sourceItem = Join-Path $source $item
    if (Test-Path -LiteralPath $sourceItem) {
        Copy-Item -LiteralPath $sourceItem -Destination $Destination -Recurse -Force
    }
}

Write-Host "Installed Amazon LinkFox SOP Skill to: $Destination"
Write-Host 'Trigger example: Use $amazon-linkfox-image-sop to run the Amazon LinkFox image SOP.'
Write-Host 'First-use Feishu bridge: run scripts/bootstrap-feishu-bridge.ps1 -Authorize before reading Feishu or LinkFox.'
