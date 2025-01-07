# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$DistroName = "Fedora"
$InstallPath = "C:\WSL\$DistroName"
$OutputFile = "dvp-fedora.tar.xz"
$ChunkPattern = "dvp-fedora.tar.xz.part-*"
$HashFile = "dvp-fedora.sha256"

# Fetch the latest release
Write-Host "Fetching the latest release..." -ForegroundColor Cyan
try {
  $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
  $ReleaseTag = $LatestRelease.tag_name
  $ReleaseAssets = $LatestRelease.assets
  Write-Host "Latest release tag: $ReleaseTag" -ForegroundColor Green
} catch {
  Write-Host "Error: Failed to fetch the latest release." -ForegroundColor Red
  exit 1
}

# Check for single tarball or chunks
Write-Host "Checking for release assets..." -ForegroundColor Cyan
$SingleTarball = $ReleaseAssets | Where-Object { $_.name -eq $OutputFile } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue
$ChunkList = $ReleaseAssets | Where-Object { $_.name -like $ChunkPattern } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue
$HashUrl = $ReleaseAssets | Where-Object { $_.name -eq $HashFile } | Select-Object -ExpandProperty browser_download_url -ErrorAction SilentlyContinue

if (-not $HashUrl) {
  Write-Host "Error: Hash file not found in the release." -ForegroundColor Red
  exit 1
}

# Download hash file
Write-Host "Downloading hash file: $HashFile..." -ForegroundColor Cyan
Start-BitsTransfer -Source $HashUrl -Destination $HashFile -Description "Downloading hash file"

if ($SingleTarball) {
  Write-Host "Single tarball found: $OutputFile" -ForegroundColor Green
  Write-Host "Downloading $OutputFile..." -ForegroundColor Cyan
  Start-BitsTransfer -Source $SingleTarball -Destination $OutputFile -Description "Downloading single tarball"
} elseif ($ChunkList) {
  Write-Host "Chunks found. Downloading and reassembling..." -ForegroundColor Cyan
  $TotalChunks = $ChunkList.Count
  $CurrentChunk = 0

  foreach ($Url in $ChunkList) {
    $CurrentChunk++
    $FileName = ($Url -split '/')[-1]
    Write-Host "Downloading $FileName ($CurrentChunk of $TotalChunks)..."
    Start-BitsTransfer -Source $Url -Destination $FileName -Description "Downloading $FileName"
  }

  Write-Host "Reassembling chunks into $OutputFile..." -ForegroundColor Cyan
  try {
    $ChunkFiles = Get-ChildItem -Filter $ChunkPattern | Sort-Object Name
    $FileStream = [System.IO.File]::Create($OutputFile)
    $BufferSize = 81920

    foreach ($Chunk in $ChunkFiles) {
      $ChunkStream = [System.IO.File]::OpenRead($Chunk.FullName)
      $Buffer = New-Object Byte[] $BufferSize
      while (($BytesRead = $ChunkStream.Read($Buffer, 0, $BufferSize)) -gt 0) {
        $FileStream.Write($Buffer, 0, $BytesRead)
      }
      $ChunkStream.Close()
    }
    $FileStream.Close()
    Write-Host "Chunks successfully reassembled into $OutputFile." -ForegroundColor Green
  } catch {
    Write-Host "Error: Failed to reassemble chunks." -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host "Error: No assets found in the release." -ForegroundColor Red
  exit 1
}

# Verify hash of the tarball
Write-Host "Verifying hash of $OutputFile..." -ForegroundColor Cyan
try {
  $ExpectedHash = (Get-Content $HashFile | Where-Object { $_ -match $OutputFile }).Split(" ")[0]
  $ActualHash = (Get-FileHash $OutputFile -Algorithm SHA256).Hash
  if ($ExpectedHash -eq $ActualHash) {
    Write-Host "Hash verification successful!" -ForegroundColor Green
  } else {
    Write-Host "Error: Hash verification failed. Expected: $ExpectedHash, Got: $ActualHash." -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "Error: Failed to verify hash." -ForegroundColor Red
  exit 1
}

# Create the installation directory
Write-Host "Creating installation directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallPath

# Register the WSL distro
Write-Host "Registering WSL distro..." -ForegroundColor Cyan
try {
  wsl --import $DistroName $InstallPath $OutputFile --version 2
  Write-Host "WSL distro registered successfully!" -ForegroundColor Green
} catch {
  Write-Host "Error: Failed to register the WSL distro." -ForegroundColor Red
  exit 1
}

# Clean up temporary files
Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
Remove-Item -Force $ChunkPattern -ErrorAction SilentlyContinue
Remove-Item -Force $OutputFile
Remove-Item -Force $HashFile

# Add profile to Windows Terminal
Write-Host "Adding profile to Windows Terminal..." -ForegroundColor Cyan
$WTSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
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
    Write-Host "Profile added to Windows Terminal!" -ForegroundColor Green
  } else {
    Write-Host "Profile already exists in Windows Terminal." -ForegroundColor Yellow
  }
} else {
  Write-Host "Windows Terminal settings.json not found. Skipping profile addition." -ForegroundColor Yellow
}

Write-Host "Installation complete! Run 'wsl -d $DistroName' to start." -ForegroundColor Green