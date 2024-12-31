# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$ReleaseTag = "latest"
$DistroName = "Fedora"
$InstallPath = "C:\WSL\$DistroName"
$OutputFile = "dvp-fedora.tar"
$ChunkPattern = "dvp-fedora-part-*"

# Step 1: Fetch chunk filenames dynamically
Write-Host "Fetching chunk filenames dynamically..."
$ChunkList = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$ReleaseTag" `
    | Select-Object -ExpandProperty assets `
    | Where-Object { $_.name -like $ChunkPattern } `
    | Select-Object -ExpandProperty browser_download_url

if (-not $ChunkList) {
    Write-Host "No chunks found. Exiting..."
    exit 1
}

# Step 2: Download all chunks
Write-Host "Downloading WSL tarball chunks..."
foreach ($Url in $ChunkList) {
    $FileName = ($Url -split '/')[-1]
    Write-Host "Downloading $FileName..."
    Invoke-WebRequest -Uri $Url -OutFile $FileName
}

# Step 3: Reassemble the chunks
Write-Host "Reassembling chunks into $OutputFile..."
Get-Content ($ChunkList | ForEach-Object { ($_.Split('/')[-1]) }) | Set-Content $OutputFile

# Step 4: Create a folder for the WSL distro
Write-Host "Creating installation directory..."
New-Item -ItemType Directory -Force -Path $InstallPath

# Step 5: Register the WSL distro
Write-Host "Registering WSL distro..."
wsl --import $DistroName $InstallPath $OutputFile --version 2

# Step 6: Clean up the downloaded chunks and tarball
Write-Host "Cleaning up temporary files..."
Remove-Item -Force ($ChunkList | ForEach-Object { ($_.Split('/')[-1]) })
Remove-Item -Force $OutputFile

# Step 7: Add profile to Windows Terminal
Write-Host "Adding Windows Terminal profile..."
$WTSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# Check if the settings file exists
if (Test-Path $WTSettingsPath) {
  # Read the settings JSON
  $WTSettings = Get-Content $WTSettingsPath | ConvertFrom-Json
  # Check if the profile already exists
  $ProfileExists = $WTSettings.profiles.list | Where-Object { $_.name -eq $DistroName }
  if (-not $ProfileExists) {
    # Create the new profile without a GUID
    $NewProfile = @{
      name              = $DistroName
      commandline       = "wsl.exe -d $DistroName"
      icon              = "https://fedoraproject.org/favicon.ico"
      startingDirectory = "~"
      hidden            = $false
    }
    # Add the new profile to the profiles list
    $WTSettings.profiles.list += $NewProfile
    # Save the updated settings back to the file
    $WTSettings | ConvertTo-Json -Depth 10 | Set-Content $WTSettingsPath -Force
    Write-Host "Profile for $DistroName added to Windows Terminal."
  } else {
    Write-Host "Profile for $DistroName already exists in Windows Terminal."
  }
} else {
  Write-Host "Windows Terminal settings file not found. Please ensure Windows Terminal is installed."
}

Write-Host "Installation complete! Run 'wsl -d $DistroName' to start."