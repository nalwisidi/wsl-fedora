# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$DistroName = "Fedora"
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

# Step 3: Download all chunks in parallel
Write-Host "Downloading WSL tarball chunks..."
$DownloadJobs = @()
foreach ($Url in $ChunkList) {
  $FileName = ($Url -split '/')[-1]
  $DownloadJobs += Start-Job -ScriptBlock {
    Invoke-WebRequest -Uri $using:Url -OutFile $using:FileName
  }
}
$DownloadJobs | Wait-Job | ForEach-Object { Receive-Job -Job $_ }

# Step 4: Reassemble the chunks
Write-Host "Reassembling chunks into $OutputFile..."
Get-Content (Get-ChildItem -Filter "dvp-fedora-part-*" | Sort-Object Name) | Set-Content $OutputFile

# Step 5: Create a folder for the WSL distro
Write-Host "Creating installation directory..."
New-Item -ItemType Directory -Force -Path $InstallPath

# Step 6: Register the WSL distro
Write-Host "Registering WSL distro..."
wsl --import $DistroName $InstallPath $OutputFile --version 2

# Step 7: Clean up the downloaded chunks and tarball
Write-Host "Cleaning up temporary files..."
try {
  Remove-Item -Force "dvp-fedora-part-*"
  Remove-Item -Force $OutputFile
} catch {
  Write-Host "Failed to clean up some temporary files."
}

# Step 8: Add profile to Windows Terminal
Write-Host "Adding Windows Terminal profile..."
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
    Write-Host "Profile for $DistroName added to Windows Terminal."
  } else {
    Write-Host "Profile for $DistroName already exists in Windows Terminal."
  }
} else {
  Write-Host "Windows Terminal settings file not found. Please ensure Windows Terminal is installed."
}

Write-Host "Installation complete! Run 'wsl -d $DistroName' to start."