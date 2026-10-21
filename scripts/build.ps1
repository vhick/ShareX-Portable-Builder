param([string]$ReleaseTag = 'latest')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if ($ReleaseTag -ne 'latest' -and $ReleaseTag -notmatch '^v?\d+\.\d+\.\d+$') {
  throw 'release_tag must be latest or an official stable tag, such as v21.0.0.'
}
$head = @{ 'User-Agent' = 'ShareX-Portable-Builder'; 'Accept'='application/vnd.github+json' }
if ($env:GH_TOKEN) { $head['Authorization'] = 'Bearer ' + $env:GH_TOKEN }
$endpoint = 'https://api.github.com/repos/ShareX/ShareX/releases'
if ($ReleaseTag -eq 'latest') {
  $rel = Invoke-RestMethod -Uri ($endpoint + '/latest') -Headers $head
} else {
  $tag = if ($ReleaseTag.StartsWith('v')) { $ReleaseTag } else { 'v' + $ReleaseTag }
  $rel = Invoke-RestMethod -Uri ($endpoint + '/tags/' + $tag) -Headers $head
}
if ($rel.prerelease -or $rel.draft) { throw 'Requested release is prerelease or draft; stable only.' }
$version = ([string]$rel.tag_name).TrimStart('v')
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Unexpected stable release version: ' + $version }
$assetName = 'ShareX-' + $version + '-portable-x64.zip'
$assets = @($rel.assets | Where-Object { $_.name -eq $assetName })
if ($assets.Count -ne 1) { throw "Expected exact official asset $assetName, found $($assets.Count)." }
$asset = $assets[0]

# Require an upstream-published checksum, not a checksum computed from our download.
$expected = $null
if ($asset.PSObject.Properties.Name -contains 'digest' -and [string]$asset.digest -match '^sha256:([A-Fa-f0-9]{64})$') {
  $expected = $Matches[1]
}
$linePattern = [regex]::Escape($assetName) + '\s*\|\s*`?([A-Fa-f0-9]{64})`?'
$bodyMatch = [regex]::Match([string]$rel.body, $linePattern)
if ($bodyMatch.Success) {
  $fromNotes = $bodyMatch.Groups[1].Value
  if ($expected -and $expected -ine $fromNotes) { throw 'Official API digest and release-note hash disagree.' }
  $expected = $fromNotes
}
if (-not $expected) { throw "No official SHA-256 for $assetName. Fail closed rather than trusting an unverified download." }

$work = Join-Path $repoRoot 'build-work'
$stage = Join-Path $work 'ShareXPortable'
$app = Join-Path $stage 'App/ShareX'
$data = Join-Path $stage 'Data/ShareX'
$appInfo = Join-Path $stage 'App/AppInfo'
$out = Join-Path $repoRoot 'dist'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work,$stage,$app,$data,$appInfo,(Join-Path $stage 'Other/Source'),$out | Out-Null
$zipPath = Join-Path $work $assetName
Write-Host "Downloading official ShareX $version portable x64..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $head
$actual = (Get-FileHash $zipPath -Algorithm SHA256).Hash
if ($actual -ine $expected) { throw "SHA-256 MISMATCH for official archive! Expected: $expected; Got: $actual" }
Write-Host "PASS: official SHA-256 $actual"
$extracted = Join-Path $work 'extracted'
Expand-Archive -LiteralPath $zipPath -DestinationPath $extracted -Force
$entry = @(Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter 'ShareX.exe')
if ($entry.Count -ne 1) { throw "Expected exactly one ShareX.exe in official ZIP, found $($entry.Count)." }
# Don't flatten subfolders of the application. Only strip the archive's optional outer wrapper.
Get-ChildItem -LiteralPath $entry[0].DirectoryName -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $app -Recurse -Force
}
if (!(Test-Path (Join-Path $app 'ShareX.exe'))) { throw 'Official ShareX.exe was not staged.' }
# The official portable archive enables the app-adjacent data directory by this sentinel.
# The launcher instead directs normal launches to Data/ShareX with PersonalPath.cfg.
$upstreamPortable = Join-Path $app 'Portable'
if (Test-Path $upstreamPortable) { Remove-Item -LiteralPath $upstreamPortable -Force }
$packagedUserData = Join-Path $app 'ShareX'
if (Test-Path $packagedUserData) {
  Get-ChildItem -LiteralPath $packagedUserData -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $data -Recurse -Force
  }
  Remove-Item -LiteralPath $packagedUserData -Recurse -Force
}
# The launcher creates PersonalPath.cfg on first launch using the current device path.
$preExistingCfg = Join-Path $app 'PersonalPath.cfg'
if (Test-Path $preExistingCfg) { Remove-Item -LiteralPath $preExistingCfg -Force }

# Use the full-resolution ORIGINAL upstream ShareX ICO (not a generic icon).
$icon = Join-Path $appInfo 'appicon.ico'
Invoke-WebRequest -Uri 'https://getsharex.com/img/ShareX_Icon_Full.ico' -OutFile $icon
$b = [IO.File]::ReadAllBytes($icon)
if ($b.Length -lt 1000 -or $b[0] -ne 0 -or $b[1] -ne 0 -or $b[2] -ne 1 -or $b[3] -ne 0) {
  throw 'Official full-resolution ShareX ICO has an invalid file signature.'
}
$icoCount = [BitConverter]::ToUInt16($b,4)
if ($icoCount -lt 2) { throw "Original ICO unexpectedly has fewer than two icon sizes ($icoCount)." }

# Native Windows OS dependency only: .NET Framework 4.x compiler installed on Windows 10/11.
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!(Test-Path $csc)) { throw 'Windows .NET Framework C# compiler was not found.' }
$launcherExe = Join-Path $stage 'ShareXPortable.exe'
$launcherSrc = Join-Path $repoRoot 'launcher/ShareXPortable.cs'
& $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$launcherExe" "/win32icon:$icon" /r:System.Windows.Forms.dll /r:System.Security.dll $launcherSrc
if ($LASTEXITCODE -ne 0) { throw "Portable launcher compilation failed with exit code $LASTEXITCODE" }

# Create PortableApps Menu PNGs derived only from the original developer ICO.
Add-Type -AssemblyName System.Drawing
foreach ($size in @(16,32,75,128,256)) {
  $ico = [Drawing.Icon]::new($icon, $size, $size)
  try {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    try {
      $graphics = [Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawIcon($ico, (New-Object Drawing.Rectangle(0,0,$size,$size)))
      } finally { $graphics.Dispose() }
      $png = Join-Path $appInfo "appicon_$size.png"
      $bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $bitmap.Dispose() }
  } finally { $ico.Dispose() }
}
$pkgVersion = "$version.0"
@"
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=ShareX Portable
AppID=ShareXPortableCommunity
Publisher=ShareX Team (original application)
Homepage=https://github.com/ShareX/ShareX
Category=Graphics & Pictures
Description=Community packaged version of the official ShareX portable release
Language=Multilingual

[License]
Shareable=true
OpenSource=true
Freeware=true
CommercialUse=true

[Version]
PackageVersion=$pkgVersion
DisplayVersion=$version

[Control]
Icons=1
Start=ShareXPortable.exe
"@ | Set-Content -LiteralPath (Join-Path $appInfo 'appinfo.ini') -Encoding ASCII
@"
ShareX official release: $($rel.tag_name)
Official portable archive: $($asset.browser_download_url)
Archive SHA256: $actual
Official original icon: https://getsharex.com/img/ShareX_Icon_Full.ico
Launcher and metadata: community builder (not official ShareX or PortableApps.com distribution)
Portability: ShareX personal path directed to Data/ShareX; host-settings fallback supported
Builder version: v1.0
"@ | Set-Content -LiteralPath (Join-Path $stage 'Other/build-manifest.txt') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/TESTING.md') -Destination (Join-Path $stage 'Other/TESTING.txt')
Copy-Item -LiteralPath $launcherSrc -Destination (Join-Path $stage 'Other/Source/ShareXPortable.cs')
@'
SHAREX PORTABLE - START HERE

Place the ShareXPortable folder immediately inside your PortableApps folder.
Run ShareXPortable.exe in the ROOT, not App\ShareX\ShareX.exe.
The ShareX tray icon may remain running after you close the main window.
Fully exit ShareX using its tray icon before upgrading.

IMPORTANT: Data\ShareX holds settings, hotkeys, screenshots, videos, history,
logs, upload destinations and possibly private authentication tokens.
Back it up securely and do not upload it to public GitHub repositories.

UPGRADES: Replace ShareXPortable.exe, App\ and Other\; KEEP Data\ intact.
Do not enable in-app installer updates or create fixed-path startup entries
or Explorer context-menu registrations if you need strict portability.
Screenshots and recordings can be large; ensure adequate free disk space.

Full Windows host-remnant testing has NOT been performed by this builder.
See Other\TESTING.txt for suggested checks.
'@ | Set-Content -LiteralPath (Join-Path $stage 'START-HERE.txt') -Encoding UTF8
# Safe static smoke test: no ShareX GUI, screenshots or uploads are started.
& $launcherExe --self-test
if ($LASTEXITCODE -ne 0) { throw "Portable launcher self-test failed: $LASTEXITCODE" }
if (!(Test-Path (Join-Path $appInfo 'appinfo.ini'))) { throw 'PortableApps metadata missing.' }
$zipOut = Join-Path $out "ShareXPortable-$version-x64.zip"
# Compress the PARENT folder so users extract it directly into X:\PortableApps.
Compress-Archive -LiteralPath $stage -DestinationPath $zipOut -CompressionLevel Optimal
if ((Get-Item $zipOut).Length -lt 1000000) { throw 'Portable archive seems too small.' }
Write-Host "PASS: Created $zipOut"
