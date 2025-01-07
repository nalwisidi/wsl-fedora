# Define variables
$RepoOwner = "nalwisidi"
$RepoName = "dvp-fedora"
$DistroName = "Fedora"
$InstallPath = "C:\WSL\$DistroName"
$OutputFile = "dvp-fedora.tar.xz"
$ChunkPattern = "dvp-fedora.tar.xz.part-*"

# Step 1: Fetch the latest release
Write-Host "Fetching the latest release..." -ForegroundColor Cyan
try {
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
    $ReleaseTag = $LatestRelease.tag_name
    Write-Host "Latest release tag: $ReleaseTag" -ForegroundColor Green
} catch {
    Write-Host "Failed to fetch the latest release. Exiting..." -ForegroundColor Red
    exit 1
}

# Step 2: Fetch chunk filenames dynamically
Write-Host "Fetching chunk filenames dynamically..." -ForegroundColor Cyan
try {
    $ChunkList = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/tags/$ReleaseTag" `
        | Select-Object -ExpandProperty assets `
        | Where-Object { $_.name -like $ChunkPattern } `
        | Select-Object -ExpandProperty browser_download_url
    if (-not $ChunkList) {
        Write-Host "No chunks found. Exiting..." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Failed to fetch chunk filenames. Exiting..." -ForegroundColor Red
    exit 1
}

# Step 3: Download all chunks with progress bar
Write-Host "Downloading WSL tarball chunks..." -ForegroundColor Cyan
$TotalChunks = $ChunkList.Count
$ProgressIndex = 0

foreach ($Url in $ChunkList) {
    $ProgressIndex++
    $FileName = ($Url -split '/')[-1]
    Write-Host "Downloading $FileName ($ProgressIndex of $TotalChunks)..."

    # Using Start-BitsTransfer for faster and reliable downloads
    try {
        Start-BitsTransfer -Source $Url -Destination $FileName -Description "Downloading $FileName" -ErrorAction Stop
        Write-Progress -Activity "Downloading Chunks" -Status "$ProgressIndex of $TotalChunks completed" `
                        -PercentComplete (($ProgressIndex / $TotalChunks) * 100)
    } catch {
        Write-Host "Failed to download $FileName. Exiting..." -ForegroundColor Red
        exit 1
    }
}

Write-Progress -Activity "Downloading Chunks" -Status "All downloads complete" -Completed

# Step 4: Reassemble the chunks
Write-Host "Reassembling chunks into $OutputFile..." -ForegroundColor Cyan
try {
    $TotalSize = 0
    $ChunkFiles = Get-ChildItem -Filter $ChunkPattern | Sort-Object Name
    $FileStream = [System.IO.File]::Create($OutputFile)
    $BufferSize = 81920
    $ProgressIndex = 0

    foreach ($Chunk in $ChunkFiles) {
        $ChunkSize = (Get-Item $Chunk.FullName).Length
        $TotalSize += $ChunkSize
    }

    foreach ($Chunk in $ChunkFiles) {
        $ProgressIndex++
        $ChunkStream = [System.IO.File]::OpenRead($Chunk.FullName)
        $BytesRead = 0
        $Buffer = New-Object Byte[] $BufferSize

        while (($BytesRead = $ChunkStream.Read($Buffer, 0, $BufferSize)) -gt 0) {
            $FileStream.Write($Buffer, 0, $BytesRead)
            $PercentComplete = [math]::Round(($FileStream.Length / $TotalSize) * 100, 2)
            Write-Progress -Activity "Reassembling Chunks" `
                            -Status "Combining chunk $ProgressIndex of $($ChunkFiles.Count)" `
                            -PercentComplete $PercentComplete
        }

        $ChunkStream.Close()
    }

    $FileStream.Close()
    Write-Host "Chunks successfully reassembled into $OutputFile." -ForegroundColor Green
} catch {
    Write-Host "Failed to reassemble chunks. Exiting..." -ForegroundColor Red
    exit 1
}

Write-Progress -Activity "Reassembling Chunks" -Status "Reassembly Complete" -Completed

# Step 5: Verify the hash of the assembled file
Write-Host "Verifying hash of $OutputFile..." -ForegroundColor Cyan
try {
    $HashUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$ReleaseTag/$OutputFile.sha256"
    Start-BitsTransfer -Source $HashUrl -Destination "$OutputFile.sha256" -Description "Downloading hash file"
    $ExpectedHash = (Get-Content "$OutputFile.sha256").Split(" ")[0]
    $ActualHash = (Get-FileHash $OutputFile -Algorithm SHA256).Hash
    if ($ExpectedHash -eq $ActualHash) {
        Write-Host "Hash verification successful!" -ForegroundColor Green
    } else {
        Write-Host "Hash verification failed. Expected: $ExpectedHash, Got: $ActualHash. Exiting..." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Failed to verify hash. Exiting..." -ForegroundColor Red
    exit 1
}

# Step 6: Create a folder for the WSL distro
Write-Host "Creating installation directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallPath

# Step 7: Register the WSL distro
Write-Host "Registering WSL distro..." -ForegroundColor Cyan
wsl --import $DistroName $InstallPath $OutputFile --version 2

# Step 8: Clean up downloaded chunks and tarball
Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
Remove-Item -Force $ChunkPattern
Remove-Item -Force $OutputFile
Remove-Item -Force "$OutputFile.sha256"

# Step 9: Add profile to Windows Terminal
Write-Host "Adding Windows Terminal profile..." -ForegroundColor Cyan
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
        Write-Host "Profile for $DistroName added to Windows Terminal." -ForegroundColor Green
    } else {
        Write-Host "Profile for $DistroName already exists in Windows Terminal." -ForegroundColor Yellow
    }
} else {
    Write-Host "Windows Terminal settings file not found. Skipping profile addition." -ForegroundColor Yellow
}

Write-Host "Installation complete! Run 'wsl -d $DistroName' to start." -ForegroundColor Green
