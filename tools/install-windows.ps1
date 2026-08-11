<#
.SYNOPSIS
Installs What's due to %LOCALAPPDATA%\WhatsDue and puts it in the Start menu.

.DESCRIPTION
Two things the manual copy-paste install kept getting wrong, both of which cost
a working app:

  * It left the shortcut as a "right-click -> Pin to Start" afterthought. A pin
    made from build\windows\x64\runner\Release points into a disposable
    directory, so it dies the moment the repository is moved or cleaned -- and
    an app you cannot launch never runs its own updater, so it silently falls
    behind every release.

  * Nothing verified where the files actually landed. Anything running inside a
    packaged (MSIX) container -- which includes some editors and agent tools --
    has its writes to %LOCALAPPDATA% redirected into that container's private
    storage. Test-Path then reports success while Explorer correctly reports the
    folder does not exist.

Run this from an ordinary PowerShell window, not from inside a packaged app.

.PARAMETER Version
Release tag to install, e.g. v1.0.7. Defaults to the latest release.

.PARAMETER FromBuild
Install the local build output instead of downloading a release. Expects
app\build\windows\x64\runner\Release to exist.

.EXAMPLE
.\tools\install-windows.ps1

.EXAMPLE
.\tools\install-windows.ps1 -Version v1.0.7

.EXAMPLE
.\tools\install-windows.ps1 -FromBuild
#>
[CmdletBinding()]
param(
  [string] $Version = 'latest',
  [switch] $FromBuild
)

$ErrorActionPreference = 'Stop'
$repo = 'aaqilmodak29/Whats-Due-'
$dest = Join-Path $env:LOCALAPPDATA 'WhatsDue'

# Refuse to run redirected rather than "succeeding" into a container. Probing a
# real write is the only reliable test: the redirection is invisible to
# Test-Path, Get-Item and $env:LOCALAPPDATA alike, and only shows up as a
# reparse target on something actually created.
$probe = Join-Path $env:LOCALAPPDATA ('.whatsdue-probe-{0}' -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
New-Item -ItemType Directory -Force -Path $probe | Out-Null
$redirected = (Get-Item $probe -Force).Target
Remove-Item $probe -Recurse -Force -ErrorAction SilentlyContinue
if ($redirected) {
  throw @"
This shell's writes to %LOCALAPPDATA% are being redirected to:
  $redirected
That is a packaged-app (MSIX) container, so the install would land somewhere
Explorer cannot see. Run this from an ordinary PowerShell window instead.
"@
}

# ---------------------------------------------------------------- the payload

$staging = $null
if ($FromBuild) {
  $source = Join-Path $PSScriptRoot '..\app\build\windows\x64\runner\Release'
  if (-not (Test-Path $source)) {
    throw "No local build at $source. Run: flutter build windows --release"
  }
  $source = (Resolve-Path $source).Path
} else {
  $url = if ($Version -eq 'latest') {
    "https://api.github.com/repos/$repo/releases/latest"
  } else {
    "https://api.github.com/repos/$repo/releases/tags/$Version"
  }
  $release = Invoke-RestMethod $url -Headers @{ 'User-Agent' = 'whats-due-install' }
  $asset = $release.assets | Where-Object { $_.name -like '*-windows.zip' } | Select-Object -First 1
  if (-not $asset) { throw "Release $($release.tag_name) has no Windows zip." }

  Write-Host "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)..."
  $zip = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing

  $staging = Join-Path $env:TEMP ('whats-due-install-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  Expand-Archive -Path $zip -DestinationPath $staging -Force

  # The zip may hold the Release folder's contents at the root or one level
  # down, depending on how it was packed. Follow a lone wrapper directory.
  $source = $staging
  $entries = @(Get-ChildItem $source)
  if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) { $source = $entries[0].FullName }
  if (-not (Test-Path (Join-Path $source 'whats_due.exe'))) {
    throw "whats_due.exe not found in $($asset.name) -- the archive layout changed."
  }
}

# ------------------------------------------------------------------ installing

Get-Process whats_due -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "Closing the running app (pid $($_.Id))..."
  $_.CloseMainWindow() | Out-Null
  if (-not $_.WaitForExit(5000)) { $_ | Stop-Process -Force }
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $source '*') $dest -Recurse -Force
if ($staging) { Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue }

# ------------------------------------------------------------------- shortcut

$exe = Join-Path $dest 'whats_due.exe'
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$link = Join-Path $startMenu "What's due.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($link)
$shortcut.TargetPath = $exe
# Deliberately the install directory, never the repository: the shortcut has to
# keep working after the project is moved, cleaned or deleted.
$shortcut.WorkingDirectory = $dest
$shortcut.IconLocation = $exe
$shortcut.Description = "Coursework tracker"
$shortcut.Save()

$installed = (Get-Item $exe).VersionInfo.ProductVersion
Write-Host ""
Write-Host "Installed $installed to $dest"
Write-Host "Start menu shortcut: $link"
Write-Host "Search the Start menu for `"What's due`" -- then right-click -> Pin to Start."
