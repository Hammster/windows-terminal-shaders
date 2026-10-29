[CmdletBinding()]
param(
    [string] $SettingsPath = (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
)

$ErrorActionPreference = 'Stop'

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory)] [psobject] $Object,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [AllowEmptyCollection()] $Value
    )

    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $Object.$Name = $Value
    }
}

$resolvedSettingsPath = [IO.Path]::GetFullPath($SettingsPath)
if (-not (Test-Path -LiteralPath $resolvedSettingsPath -PathType Leaf)) {
    throw "Windows Terminal settings were not found: $resolvedSettingsPath"
}

$shaderPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'cyberpunk-terminal.hlsl'))
$palettePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'cyberpunk-color-scheme.json'))

if (-not (Test-Path -LiteralPath $shaderPath -PathType Leaf)) {
    throw "Shader was not found: $shaderPath"
}

$settings = Get-Content -Raw -LiteralPath $resolvedSettingsPath | ConvertFrom-Json
$paletteFile = Get-Content -Raw -LiteralPath $palettePath | ConvertFrom-Json
$paletteName = 'Cyberpunk 2077 Dark'
$palette = $paletteFile.schemes | Where-Object { $_.name -eq $paletteName } | Select-Object -First 1

if ($null -eq $palette) {
    throw "Palette was not found in ${palettePath}: $paletteName"
}

Set-ObjectProperty -Object $settings.profiles.defaults -Name 'experimental.pixelShaderPath' -Value $shaderPath
Set-ObjectProperty -Object $settings.profiles.defaults -Name 'colorScheme' -Value $palette.name

$defaultProfile = $settings.profiles.list | Where-Object {
    $_.guid -eq $settings.defaultProfile
} | Select-Object -First 1

if ($null -ne $defaultProfile) {
    Set-ObjectProperty -Object $defaultProfile -Name 'colorScheme' -Value $palette.name
}

$managedPaletteNames = @($paletteFile.schemes | ForEach-Object { $_.name })
$otherSchemes = @($settings.schemes | Where-Object { $null -ne $_ -and $_.name -notin $managedPaletteNames })
Set-ObjectProperty -Object $settings -Name 'schemes' -Value (@($otherSchemes) + @($paletteFile.schemes))

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$resolvedSettingsPath.backup-$timestamp"
Copy-Item -LiteralPath $resolvedSettingsPath -Destination $backupPath

$json = $settings | ConvertTo-Json -Depth 100
$utf8NoBom = [Text.UTF8Encoding]::new($false)

try {
    [IO.File]::WriteAllText($resolvedSettingsPath, $json + [Environment]::NewLine, $utf8NoBom)

    # Parse the result once more so a malformed settings file can never go unnoticed.
    $null = Get-Content -Raw -LiteralPath $resolvedSettingsPath | ConvertFrom-Json
}
catch {
    Copy-Item -LiteralPath $backupPath -Destination $resolvedSettingsPath -Force
    throw
}

Write-Output "Installed palette: $($palette.name)"
Write-Output "Installed shader:  $shaderPath"
Write-Output "Settings backup:   $backupPath"
