Set-Location -Path $PSScriptRoot

# ─── Config ─────────────────────────────────────────────────────
$RepoOwner = "nalwisidi"
$RepoName = "wsl-fedora"
$OutputFile = "wsl-fedora.tar.xz"
$ChunkPattern = "$OutputFile.part-*"
$HashFile = "wsl-fedora.sha256"

# ─── Ask for Distro Name ───────────────────────────────────────
$DistroName = Read-Host "📝 Enter a name for your WSL distro (default: Fedora)"
if ([string]::IsNullOrWhiteSpace($DistroName)) {
    $DistroName = "Fedora"
    Write-Host "🔧 Using default distro name: Fedora" -ForegroundColor Yellow
} else {
    Write-Host "✅ Distro will be named: $DistroName" -ForegroundColor Green
}
$InstallPath = "$env:USERPROFILE\AppData\Local\WSL\$DistroName"

# ─── Fetch GitHub Release Info ─────────────────────────────────
Write-Host "`n🔍 Checking for latest Fedora WSL release..." -ForegroundColor Cyan
try {
    $release = Invoke-RestMethod "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
    $assets = $release.assets
    Write-Host "📦 Release found: $($release.tag_name)" -ForegroundColor Green
} catch {
    Write-Host "❌ Could not retrieve release info." -ForegroundColor Red
    exit 1
}

# ─── Download SHA256 Hash File ─────────────────────────────────
$hashUrl = $assets | Where-Object { $_.name -eq $HashFile } | Select-Object -ExpandProperty browser_download_url
if (-not $hashUrl) {
    Write-Host "❌ SHA256 file missing from release." -ForegroundColor Red
    exit 1
}
Write-Host "📥 Downloading integrity hash..." -ForegroundColor Cyan
Start-BitsTransfer -Source $hashUrl -Destination $HashFile

# ─── Download Tarball or Chunks ────────────────────────────────
$tarUrl = $assets | Where-Object { $_.name -eq $OutputFile } | Select-Object -ExpandProperty browser_download_url
$chunkUrls = $assets | Where-Object { $_.name -like $ChunkPattern } | Select-Object -ExpandProperty browser_download_url

if ($tarUrl) {
    Write-Host "📥 Downloading Fedora rootfs..." -ForegroundColor Cyan
    Start-BitsTransfer -Source $tarUrl -Destination $OutputFile
} elseif ($chunkUrls) {
    Write-Host "📥 Downloading Fedora rootfs in parts..." -ForegroundColor Cyan
    $i = 0
    foreach ($url in $chunkUrls) {
        $i++
        $file = ($url -split '/')[-1]
        Write-Host "   • [$i/$($chunkUrls.Count)] $file" -ForegroundColor DarkYellow
        Start-BitsTransfer -Source $url -Destination $file
    }

    Write-Host "🛠️ Reassembling parts..." -ForegroundColor Cyan
    try {
        $out = [System.IO.File]::Create($OutputFile)
        $buf = New-Object byte[] 81920
        foreach ($chunk in (Get-ChildItem -Filter $ChunkPattern | Sort-Object Name)) {
            $s = [System.IO.File]::OpenRead($chunk.FullName)
            while (($r = $s.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $r) }
            $s.Close()
        }
        $out.Close()
        Write-Host "✅ All parts combined." -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to reassemble chunks." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ No valid rootfs found in the release." -ForegroundColor Red
    exit 1
}

# ─── Verify Hash ───────────────────────────────────────────────
Write-Host "🔒 Verifying download integrity..." -ForegroundColor Cyan
try {
    $expected = (Get-Content $HashFile | Where-Object { $_ -match $OutputFile }) -split ' ' | Select-Object -First 1
    $actual = (Get-FileHash $OutputFile -Algorithm SHA256).Hash
    if ($expected -ne $actual) {
        Write-Host "❌ SHA256 mismatch! Aborting..." -ForegroundColor Red
        Remove-Item -Force $ChunkPattern, $OutputFile, $HashFile -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "🔐 Verified successfully." -ForegroundColor Green
} catch {
    Write-Host "❌ Verification failed." -ForegroundColor Red
    Remove-Item -Force $ChunkPattern, $OutputFile, $HashFile -ErrorAction SilentlyContinue
    exit 1
}

# ─── Import Distro ─────────────────────────────────────────────
Write-Host "📥 Installing Fedora WSL..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
wsl --import $DistroName $InstallPath $OutputFile --version 2

# ─── Launch User Creation ──────────────────────────────────────
Write-Host "🙍 Creating your Linux user..." -ForegroundColor Cyan
Start-Process "wsl.exe" -ArgumentList "-d", $DistroName, "-u", "root", "--", "bash", "/usr/local/bin/create_user" -Wait -NoNewWindow

# ─── Read and Validate Username ────────────────────────────────
$username = (wsl -d $DistroName -u root -- cat /username_created).Trim()
if (-not $username -or $username -match '[^\w.-]') {
    Write-Host "❌ Invalid username: '$username'" -ForegroundColor Red
    wsl -d $DistroName -u root -- rm -f /username_created
    exit 1
}

# ─── Finalize and Clean ────────────────────────────────────────
wsl -d $DistroName -u root -- rm -f /username_created
wsl --manage $DistroName --set-default-user $username
Remove-Item -Force $ChunkPattern, $OutputFile, $HashFile -ErrorAction SilentlyContinue

# ─── WT Profile Setup ──────────────────────────────────────────
function Find-WTSettingsPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    Write-Host "🔍 Searching for Windows Terminal settings..." -ForegroundColor DarkGray
    return Get-ChildItem -Path $env:LOCALAPPDATA -Recurse -Filter settings.json -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'windows.?terminal' } |
        Select-Object -ExpandProperty FullName -First 1
}

$WTSettingsPath = Find-WTSettingsPath
if (-not $WTSettingsPath) {
    Write-Host "⚠️  Could not find Windows Terminal settings.json." -ForegroundColor Red
} else {
    Write-Host "🧩 Updating Windows Terminal profile..." -ForegroundColor Cyan
    $WTSettings = Get-Content $WTSettingsPath -Raw | ConvertFrom-Json
    $customExists = $WTSettings.profiles.list | Where-Object {
        $_.name -eq $DistroName -and $_.commandline -eq "wsl.exe -d $DistroName"
    }
    if (-not $customExists) {
        $WTSettings.profiles.list += @{
            name              = $DistroName
            commandline       = "wsl.exe -d $DistroName"
            icon              = "https://fedoraproject.org/favicon.ico"
            startingDirectory = "~"
            hidden            = $false
        }
        Write-Host "✅ Terminal profile added." -ForegroundColor Green
    } else {
        Write-Host "🙍 Terminal profile already exists." -ForegroundColor Yellow
    }
    $WTSettings | ConvertTo-Json -Depth 10 | Set-Content $WTSettingsPath -Force
    Start-Sleep -Seconds 1
    $WTSettings = Get-Content $WTSettingsPath -Raw | ConvertFrom-Json
    $WTSettings.profiles.list = $WTSettings.profiles.list | Where-Object {
        $_.name -ne $DistroName -or $_.commandline -eq "wsl.exe -d $DistroName"
    }
    $WTSettings | ConvertTo-Json -Depth 10 | Set-Content $WTSettingsPath -Force
    Write-Host "🏁 Windows Terminal profile ready." -ForegroundColor Green
}

# ─── Done ──────────────────────────────────────────────────────
Write-Host "`n🎉 Fedora WSL installed successfully!" -ForegroundColor Green
Write-Host "🙍 Logged in as: $username"
Write-Host "🚀 Launch with: wsl -d $DistroName`n" -ForegroundColor Green
