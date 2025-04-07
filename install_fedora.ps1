Set-Location -Path $PSScriptRoot

# ─── Configs ───────────────────────────────────────────────────
$RepoOwner = "nalwisidi"
$RepoName = "wsl-fedora"
$InstallPath = "$env:USERPROFILE\AppData\Local\WSL\$DistroName"
$OutputFile = "wsl-fedora.tar.xz"
$ChunkPattern = "wsl-fedora.tar.xz.part-*"
$HashFile = "wsl-fedora.sha256"

# ─── Pick DistroName ───────────────────────────────────────────
$UserInput = Read-Host "Enter a name for your WSL distro (default: Fedora)"
if ([string]::IsNullOrWhiteSpace($UserInput)) {
    $DistroName = "Fedora"
    Write-Host "[*] Using default distro name: Fedora" -ForegroundColor Yellow
} else {
    $DistroName = $UserInput
    Write-Host "[+] Distro name set to: $DistroName" -ForegroundColor Green
}

# ─── Fetch Latest Release ──────────────────────────────────────
Write-Host "`n[?] Fetching the latest release..." -ForegroundColor Cyan
try {
  $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
  $ReleaseTag = $LatestRelease.tag_name
  $ReleaseAssets = $LatestRelease.assets
  Write-Host "[+] Latest release: $ReleaseTag" -ForegroundColor Green
} catch {
  Write-Host "[x] Failed to fetch the latest release." -ForegroundColor Red
  exit 1
}

# ─── Download Hash File ────────────────────────────────────────
$HashUrl = $ReleaseAssets | Where-Object { $_.name -eq $HashFile } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue
if (-not $HashUrl) {
  Write-Host "[x] Hash file not found in the release." -ForegroundColor Red
  exit 1
}
Write-Host "`n[?] Downloading hash file..." -ForegroundColor Cyan
Start-BitsTransfer -Source $HashUrl -Destination $HashFile

# ─── Download RootFS ───────────────────────────────────────────
$SingleTarball = $ReleaseAssets | Where-Object { $_.name -eq $OutputFile } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue
$ChunkList = $ReleaseAssets | Where-Object { $_.name -like $ChunkPattern } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue

if ($SingleTarball) {
  Write-Host "`n[?] Downloading single tarball..." -ForegroundColor Cyan
  Start-BitsTransfer -Source $SingleTarball -Destination $OutputFile
} elseif ($ChunkList) {
  Write-Host "`n[?] Downloading chunks and reassembling..." -ForegroundColor Cyan
  $TotalChunks = $ChunkList.Count
  $CurrentChunk = 0
  foreach ($Url in $ChunkList) {
    $CurrentChunk++
    $FileName = ($Url -split '/')[-1]
    Write-Host "[$CurrentChunk/$TotalChunks] Downloading $FileName..." -ForegroundColor Yellow
    Start-BitsTransfer -Source $Url -Destination $FileName
  }

  Write-Host "`n[?] Reassembling chunks..." -ForegroundColor Cyan
  try {
    $ChunkFiles = Get-ChildItem -Filter $ChunkPattern | Sort-Object Name
    $FileStream = [System.IO.File]::Create($OutputFile)
    $Buffer = New-Object Byte[] 81920
    foreach ($Chunk in $ChunkFiles) {
      $ChunkStream = [System.IO.File]::OpenRead($Chunk.FullName)
      while (($BytesRead = $ChunkStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
        $FileStream.Write($Buffer, 0, $BytesRead)
      }
      $ChunkStream.Close()
    }
    $FileStream.Close()
    Write-Host "[+] Chunks successfully reassembled." -ForegroundColor Green
  } catch {
    Write-Host "[x] Failed to reassemble chunks." -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host "[x] No release assets found." -ForegroundColor Red
  exit 1
}

# ─── Verify Hash ───────────────────────────────────────────────
Write-Host "`n[?] Verifying file integrity..." -ForegroundColor Cyan
try {
  $ExpectedHash = (Get-Content $HashFile | Where-Object { $_ -match $OutputFile }).Split(" ")[0]
  $ActualHash = (Get-FileHash $OutputFile -Algorithm SHA256).Hash
  if ($ExpectedHash -ne $ActualHash) {
    Write-Host "[x] Hash mismatch! Expected: $ExpectedHash, Got: $ActualHash" -ForegroundColor Red
    Remove-Item -Force $ChunkPattern, $OutputFile, $HashFile -ErrorAction SilentlyContinue
    exit 1
  }
  Write-Host "[+] Hash verified successfully." -ForegroundColor Green
} catch {
  Write-Host "[x] Failed to verify hash." -ForegroundColor Red
  Remove-Item -Force $ChunkPattern, $OutputFile, $HashFile -ErrorAction SilentlyContinue
  exit 1
}

# ─── Import WSL Distro ─────────────────────────────────────────
Write-Host "`n[?] Importing Fedora WSL..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
wsl --import $DistroName $InstallPath $OutputFile --version 2

# ─── Prompt User Creation ──────────────────────────────────────
Start-Process "wsl.exe" -ArgumentList "-d", $DistroName, "-u", "root", "--", "bash", "/usr/local/bin/create_user" -Wait -NoNewWindow

# ─── Read Clean Username ───────────────────────────────────────
$username = (wsl -d $DistroName -u root -- cat /username_created) `
  | Where-Object { $_ -and $_.Trim() -ne "" } `
  | Select-Object -First 1 `
  | ForEach-Object { $_.Trim() }

if (-not $username -or $username -match '[^\w.-]') {
  Write-Host "`n[x] Invalid username: '$username'" -ForegroundColor Red
  wsl -d $DistroName -u root -- rm -f /username_created
  exit 1
}

# ─── Finalize and Cleanup ──────────────────────────────────────
wsl -d $DistroName -u root -- rm -f /username_created
wsl --manage $DistroName --set-default-user $username

Remove-Item -Force $ChunkPattern -ErrorAction SilentlyContinue
Remove-Item -Force $OutputFile, $HashFile -ErrorAction SilentlyContinue

# ─── Add to Windows Terminal ───────────────────────────────────
$WTSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $WTSettingsPath) {
  $WTSettings = Get-Content $WTSettingsPath | ConvertFrom-Json
  $ProfileExists = $WTSettings.profiles.list | Where-Object { $_.name -eq $DistroName }
  if (-not $ProfileExists) {
    $NewProfile = @{
      name              = $DistroName
      commandline       = "wsl.exe -d $DistroName"
      icon              = "https://fedoraproject.org/favicon.ico"
      startingDirectory = "~"
      hidden            = $false
    }
    $WTSettings.profiles.list += $NewProfile
    $WTSettings | ConvertTo-Json -Depth 10 | Set-Content $WTSettingsPath -Force
    Write-Host "[+] Profile added to Windows Terminal." -ForegroundColor Green
  } else {
    Write-Host "[-] Profile already exists in Windows Terminal." -ForegroundColor Yellow
  }
} else {
  Write-Host "[!] Windows Terminal settings.json not found. Skipping profile addition." -ForegroundColor Yellow
}

# ─── Complete ──────────────────────────────────────────────────
Write-Host "`n[+] Fedora WSL installed with user '$username'. Launch with:" -ForegroundColor Green
Write-Host "wsl -d $DistroName" -ForegroundColor Green
