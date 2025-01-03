# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$DistroName = "FedoraWSL"
$InstallPath = "C:\WSL\$DistroName"
$OutputFile = "dvp-fedora.tar"
$ChunkPattern = "dvp-fedora-part-*"

# Step 1: Fetch the latest release
Write-Host "Fetching the latest release..."
try {
  $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
  $ReleaseTag = $LatestRelease.tag_name
  Write-Host "Latest release tag: $ReleaseTag"
} catch {
  Write-Host "Failed to fetch the latest release. Exiting..."
  exit 1
}

# Step 2: Fetch chunk filenames dynamically
Write-Host "Fetching chunk filenames dynamically..."
try {
  $ChunkList = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$ReleaseTag" `
    | Select-Object -ExpandProperty assets `
    | Where-Object { $_.name -like $ChunkPattern } `
    | Select-Object -ExpandProperty browser_download_url
  if (-not $ChunkList) {
    Write-Host "No chunks found. Exiting..."
    exit 1
  }
} catch {
  Write-Host "Failed to fetch chunk filenames. Exiting..."
  exit 1
}

# Step 3: Download all chunks using curl
Write-Host "Downloading WSL tarball chunks using curl..."
$TotalChunks = $ChunkList.Count
$CurrentChunk = 0

foreach ($Url in $ChunkList) {
  $CurrentChunk++
  $FileName = ($Url -split '/')[-1]

  Write-Host "Downloading $FileName ($CurrentChunk of $TotalChunks)..."

  # Download using curl
  $CurlCommand = "curl -L --progress-bar -o $FileName $Url"
  Write-Host "Executing: $CurlCommand"
  Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $CurlCommand -Wait
  if (!(Test-Path $FileName)) {
    Write-Host "Download failed for $FileName. Exiting..."
    exit 1
  }
  Write-Host "$FileName downloaded successfully."
}

# Step 4: Reassemble the chunks
Write-Host "Reassembling chunks into $OutputFile..."
try {
  Get-Content (Get-ChildItem -Filter "dvp-fedora-part-*" | Sort-Object Name) | Set-Content $OutputFile
  Write-Host "Chunks reassembled successfully."
} catch {
  Write-Host "Error reassembling chunks. Cleaning up..."
  Remove-Item -Force "dvp-fedora-part-*" -ErrorAction SilentlyContinue
  exit 1
}

# Step 5: Create a folder for the WSL distro
Write-Host "Creating installation directory..."
New-Item -ItemType Directory -Force -Path $InstallPath

# Step 6: Register the WSL distro
Write-Host "Registering the WSL distro..."
try {
  wsl --import $DistroName $InstallPath $OutputFile --version 2
  Write-Host "WSL distro registered successfully."
} catch {
  Write-Host "Failed to register the WSL distro. Cleaning up..."
  Remove-Item -Force $OutputFile -ErrorAction SilentlyContinue
  Remove-Item -Force "dvp-fedora-part-*" -ErrorAction SilentlyContinue
  exit 1
}

# Step 7: Clean up the downloaded chunks and tarball
Write-Host "Cleaning up temporary files..."
Remove-Item -Force "dvp-fedora-part-*" -ErrorAction SilentlyContinue
Remove-Item -Force $OutputFile -ErrorAction SilentlyContinue

# Step 8: Add profile to Windows Terminal
Write-Host "Adding Windows Terminal profile..."

# Locate the Windows Terminal settings.json file dynamically
$WTBasePath = Join-Path $env:LOCALAPPDATA "Packages"
$WTPath = Get-ChildItem -Path $WTBasePath -Directory -Filter "Microsoft.WindowsTerminal*" | Select-Object -First 1

if ($WTPath) {
  $WTSettingsPath = Join-Path $WTPath.FullName "LocalState\settings.json"
  Write-Host "Windows Terminal settings.json located at: $WTSettingsPath"
} else {
  Write-Host "Windows Terminal installation not found. Please ensure Windows Terminal is installed."
  exit 1
}

# Ensure the settings.json file exists
if (!(Test-Path $WTSettingsPath)) {
  Write-Host "Windows Terminal settings.json not found. Please ensure the application has been run at least once."
  exit 1
}

# Update the Windows Terminal settings
try {
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
    Write-Host "Profile for $DistroName added to Windows Terminal."
} else {
    Write-Host "Profile for $DistroName already exists in Windows Terminal."
  }
} catch {
  Write-Host "Failed to update Windows Terminal settings."
}

Write-Host "Installation complete! Run 'wsl -d $DistroName' to start."
