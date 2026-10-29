[CmdletBinding()]
param(
    [string] $SettingsPath = (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),

    [ValidateSet('Keep', 'Curved', 'Flat')]
    [string] $ShaderVariant = 'Keep',

    [ValidateSet('Dark', 'Light')]
    [string] $Theme = 'Dark'
)

$ErrorActionPreference = 'Stop'

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory)] [psobject] $Object,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] $Value
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

$curvedShaderPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fallout-terminal.hlsl'))
$flatShaderPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fallout-terminal-flat.hlsl'))
$curvedLightShaderPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fallout-terminal-light.hlsl'))
$flatLightShaderPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fallout-terminal-flat-light.hlsl'))
$palettePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fallout-color-scheme.json'))

foreach ($requiredShaderPath in @(
    $curvedShaderPath,
    $flatShaderPath,
    $curvedLightShaderPath,
    $flatLightShaderPath
)) {
    if (-not (Test-Path -LiteralPath $requiredShaderPath -PathType Leaf)) {
        throw "Shader was not found: $requiredShaderPath"
    }
}

$settings = Get-Content -Raw -LiteralPath $resolvedSettingsPath | ConvertFrom-Json
$paletteFile = Get-Content -Raw -LiteralPath $palettePath | ConvertFrom-Json
$paletteName = if ($Theme -eq 'Light') { 'Fallout Terminal Light' } else { 'Fallout Terminal Color' }
$palette = $paletteFile.schemes | Where-Object { $_.name -eq $paletteName } | Select-Object -First 1

if ($null -eq $palette) {
    throw "Palette was not found in ${palettePath}: $paletteName"
}

$currentShaderPath = $settings.profiles.defaults.'experimental.pixelShaderPath'
$resolvedVariant = switch ($ShaderVariant) {
    'Curved' { 'Curved' }
    'Flat' { 'Flat' }
    default {
        if ($currentShaderPath -in @($flatShaderPath, $flatLightShaderPath)) {
            'Flat'
        }
        else {
            'Curved'
        }
    }
}

$shaderPath = if ($Theme -eq 'Light') {
    if ($resolvedVariant -eq 'Flat') { $flatLightShaderPath } else { $curvedLightShaderPath }
}
else {
    if ($resolvedVariant -eq 'Flat') { $flatShaderPath } else { $curvedShaderPath }
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
$otherSchemes = @($settings.schemes | Where-Object { $_.name -notin $managedPaletteNames })
$settings.schemes = @($otherSchemes) + @($paletteFile.schemes)

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
