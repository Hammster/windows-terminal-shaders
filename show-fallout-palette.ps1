[CmdletBinding()]
param(
    [ValidateSet('Dark', 'Light')]
    [string] $Theme = 'Dark'
)

$schemeName = if ($Theme -eq 'Light') { 'Fallout Terminal Light' } else { 'Fallout Terminal Color' }
$palettePath = Join-Path $PSScriptRoot 'fallout-color-scheme.json'
$paletteFile = Get-Content -Raw -LiteralPath $palettePath | ConvertFrom-Json
$scheme = $paletteFile.schemes | Where-Object { $_.name -eq $schemeName } | Select-Object -First 1

if ($null -eq $scheme) {
    throw "Palette was not found in ${palettePath}: $schemeName"
}

$colors = [ordered]@{
    background   = $scheme.background
    foreground   = $scheme.foreground
    cursor       = $scheme.cursorColor
    selection    = $scheme.selectionBackground
    black        = $scheme.black
    red          = $scheme.red
    green        = $scheme.green
    yellow       = $scheme.yellow
    blue         = $scheme.blue
    purple       = $scheme.purple
    cyan         = $scheme.cyan
    white        = $scheme.white
    brightBlack  = $scheme.brightBlack
    brightRed    = $scheme.brightRed
    brightGreen  = $scheme.brightGreen
    brightYellow = $scheme.brightYellow
    brightBlue   = $scheme.brightBlue
    brightPurple = $scheme.brightPurple
    brightCyan   = $scheme.brightCyan
    brightWhite  = $scheme.brightWhite
}

$escape = [char]27
$reset = "$escape[0m"
$block = [string]::new([char]0x2588, 12)

if ($null -ne $PSStyle) {
    $PSStyle.OutputRendering = 'Ansi'
}

Write-Host "$schemeName`n"
foreach ($entry in $colors.GetEnumerator()) {
    $hex = $entry.Value.TrimStart('#')
    $red = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $green = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $blue = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    $colorStart = "$escape[38;2;$red;$green;$blue`m"
    [Console]::WriteLine("{0}{1}{2}  {3,-16} {4}", $colorStart, $block, $reset, $entry.Key, $entry.Value)
}
