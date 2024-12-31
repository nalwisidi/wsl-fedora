# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$ReleaseTag = "latest"
$TarballName = "dvp-fedora.tar"
$DistroName = "Fedora"
$InstallPath = "C:\WSL\$DistroName"

# Step 1: Download the .tar file from the GitHub release
Write-Host "Downloading WSL tarball..."
$Url = "https://github.com/$RepoOwner/$RepoName/releases/download/$ReleaseTag/$TarballName"
Invoke-WebRequest -Uri $Url -OutFile $TarballName

# Step 2: Create a folder for the WSL distro
Write-Host "Creating installation directory..."
New-Item -ItemType Directory -Force -Path $InstallPath

# Step 3: Register the WSL distro
Write-Host "Registering WSL distro..."
wsl --import $DistroName $InstallPath $TarballName --version 2

# Step 4: Clean up the downloaded tarball
Write-Host "Cleaning up temporary files..."
Remove-Item -Force $TarballName

# Step 5: Add profile to Windows Terminal
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