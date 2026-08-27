[CmdletBinding()]
param(
    [switch]$Authorize,
    [string]$DeviceCode,
    [string]$QrOutput = 'feishu-auth-qr.png',
    [switch]$InstallSkillPack,
    [switch]$SkipSkillPack,
    [switch]$SkipUpdate
)

$ErrorActionPreference = 'Stop'
$env:LARKSUITE_CLI_NO_UPDATE_NOTIFIER = '1'
$env:LARKSUITE_CLI_NO_SKILLS_NOTIFIER = '1'

function Get-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) { return $null }
    if ($command.PSObject.Properties.Name -contains 'Source' -and $command.Source) { return $command.Source }
    return $command.Path
}

function Convert-OutputToJson {
    param([Parameter(Mandatory = $true)][object[]]$Output)
    $text = ($Output | ForEach-Object { [string]$_ }) -join "`n"
    try {
        return ($text | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw "Expected JSON from lark-cli but could not parse its output."
    }
}

function Find-JsonValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names
    )
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($name in $Names) {
            if ($Object.Contains($name)) { return $Object[$name] }
        }
        foreach ($value in $Object.Values) {
            $found = Find-JsonValue -Object $value -Names $Names
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        foreach ($item in $Object) {
            $found = Find-JsonValue -Object $item -Names $Names
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    foreach ($property in $Object.PSObject.Properties) {
        if ($Names -contains $property.Name) { return $property.Value }
    }
    foreach ($property in $Object.PSObject.Properties) {
        $found = Find-JsonValue -Object $property.Value -Names $Names
        if ($null -ne $found) { return $found }
    }
    return $null
}

$larkCli = Get-CommandPath -Name 'lark-cli'
if ($null -eq $larkCli) {
    $npm = Get-CommandPath -Name 'npm'
    if ($null -eq $npm) {
        Write-Output 'NEEDS_INSTALL lark-cli is missing and npm is not available on PATH.'
        exit 2
    }
    Write-Output 'INSTALL @larksuite/cli via npm'
    & $npm install --global '@larksuite/cli' 2>&1 | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'INSTALL_FAILED official @larksuite/cli installation failed.'
        exit 2
    }
    $larkCli = Get-CommandPath -Name 'lark-cli'
    if ($null -eq $larkCli) {
        Write-Output 'INSTALL_FAILED lark-cli is still missing after official installation.'
        exit 2
    }
}

if ($InstallSkillPack -and -not $SkipSkillPack) {
    $npx = Get-CommandPath -Name 'npx'
    if ($null -eq $npx) {
        Write-Output 'WARN npx is not available; skipped official Lark CLI Skill pack bootstrap.'
    } else {
        Write-Output 'BOOTSTRAP official Lark CLI Skill pack'
        & $npx skills add larksuite/cli -g -y 2>&1 | ForEach-Object { Write-Output $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Output 'WARN official Lark CLI Skill pack bootstrap failed; continuing with lark-cli bridge checks.'
        }
    }
}

if (-not $SkipUpdate) {
    Write-Output 'UPDATE lark-cli and its AI Skills'
    & $larkCli update 2>&1 | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'WARN lark-cli update failed; auth verification will still be attempted.'
    }
}

if ($DeviceCode) {
    Write-Output 'COMPLETE pending Feishu user authorization'
    & $larkCli auth login --device-code $DeviceCode 2>&1 | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'AUTH_FAILED device-code completion failed.'
        exit 4
    }
}

$statusOutput = @(& $larkCli auth status --json --verify 2>&1)
$status = $null
try { $status = Convert-OutputToJson -Output $statusOutput } catch { $status = $null }
$verified = $false
if ($null -ne $status) {
    $verifiedValue = Find-JsonValue -Object $status -Names @('verified')
    if ($verifiedValue -eq $true) { $verified = $true }
}

if ($verified) {
    Write-Output 'PASS Feishu user identity is verified; control board may be read.'
    exit 0
}

if (-not $Authorize) {
    Write-Output 'NEEDS_AUTH run with -Authorize to start split-flow authorization.'
    exit 3
}

$authOutput = @(& $larkCli auth login --domain docs --domain wiki --no-wait --json 2>&1)
$auth = $null
try { $auth = Convert-OutputToJson -Output $authOutput } catch { $auth = $null }
if ($null -eq $auth) {
    Write-Output 'AUTH_FAILED lark-cli did not return structured authorization data.'
    exit 4
}

$verificationUrl = Find-JsonValue -Object $auth -Names @('verification_url', 'verificationUrl')
$newDeviceCode = Find-JsonValue -Object $auth -Names @('device_code', 'deviceCode')
if ([string]::IsNullOrWhiteSpace([string]$verificationUrl) -or [string]::IsNullOrWhiteSpace([string]$newDeviceCode)) {
    Write-Output 'AUTH_FAILED authorization response did not include verification URL and device code.'
    exit 4
}

if ([IO.Path]::IsPathRooted($QrOutput)) {
    Write-Output 'AUTH_FAILED QrOutput must be a relative filename.'
    exit 4
}
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) 'amazon-linkfox-feishu-bootstrap'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
Push-Location -LiteralPath $tempRoot
try {
    & $larkCli auth qrcode ([string]$verificationUrl) --output $QrOutput 2>&1 | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'AUTH_FAILED could not generate local QR code.'
        exit 4
    }
    $qrPath = Join-Path $tempRoot $QrOutput
} finally {
    Pop-Location
}

Write-Output "AUTH_URL=$verificationUrl"
Write-Output "QR_PATH=$qrPath"
Write-Output "DEVICE_CODE=$newDeviceCode"
Write-Output 'WAITING_USER_AUTH reply 已完成授权 after browser authorization, then rerun with -DeviceCode.'
exit 5
