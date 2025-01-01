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

# Step 3: Download all chunks with real-time progress
Write-Host "Downloading WSL tarball chunks..."
$TotalChunks = $ChunkList.Count
$CurrentChunk = 0

Add-Type -AssemblyName System.Net.Http
$HttpClient = New-Object System.Net.Http.HttpClient

foreach ($Url in $ChunkList) {
  $CurrentChunk++
  $FileName = ($Url -split '/')[-1]

  Write-Host "Downloading $FileName ($CurrentChunk of $TotalChunks)..."

  # Open file stream for writing
  $FileStream = [System.IO.File]::OpenWrite($FileName)
  $HttpResponse = $HttpClient.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
  $ContentStream = $HttpResponse.Content.ReadAsStreamAsync().Result
  $TotalBytes = $HttpResponse.Content.Headers.ContentLength
  $Buffer = New-Object byte[] 81920
  $BytesRead = 0
  $TotalRead = 0

  while (($BytesRead = $ContentStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
    $FileStream.Write($Buffer, 0, $BytesRead)
    $TotalRead += $BytesRead
    $PercentComplete = [math]::Round(($TotalRead / $TotalBytes) * 100, 2)
    Write-Progress -Activity "Downloading $FileName" `
                   -Status "$PercentComplete% complete" `
                   -PercentComplete $PercentComplete
  }

  $FileStream.Close()
  Write-Host "$FileName downloaded successfully."
}

Write-Progress -Activity "Downloading Chunks" -Status "Download Complete" -Completed

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
Remove-Item -Force "dvp-fedora-part-*"
Remove-Item -Force $OutputFile

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