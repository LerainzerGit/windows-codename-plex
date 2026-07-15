$dismPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"
$wimPath = "C:\iso_src\sources\install.wim"
$mountDir = "C:\wim_mount"

New-Item -ItemType Directory -Path $mountDir -Force

Write-Output "Available editions in this WIM:"
& $dismPath /Get-WimInfo /WimFile:$wimPath

& $dismPath /Mount-Wim /WimFile:$wimPath /Index:1 /MountDir:$mountDir

function Set-WritableAndCopy {
    param($Source, $Dest)
    if (Test-Path $Dest) {
        & takeown /f "$Dest" | Out-Null
        & icacls "$Dest" /grant "*S-1-5-32-544:F" | Out-Null
        attrib -r -s -h "$Dest"
    }
    Copy-Item $Source $Dest -Force
}

if (Test-Path .\customizations\wallpaper.jpg) {
    Set-WritableAndCopy ".\customizations\wallpaper.jpg" "$mountDir\Windows\Web\Wallpaper\Windows\img0.jpg"
}
if (Test-Path .\customizations\lockscreen.jpg) {
    New-Item -ItemType Directory -Path "$mountDir\Windows\Web\Screen" -Force -ErrorAction SilentlyContinue
    $lockDest = "$mountDir\Windows\Web\Screen\img100.jpg"
    if (Test-Path $lockDest) {
        Set-WritableAndCopy ".\customizations\lockscreen.jpg" $lockDest
    } else {
        Copy-Item .\customizations\lockscreen.jpg $lockDest -Force
    }
}

reg load HKLM\OFFLINE_SOFTWARE "$mountDir\Windows\System32\config\SOFTWARE"
reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "ProductName" /t REG_SZ /d "Windows Codename Plex" /f
reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "EditionID" /t REG_SZ /d "PlexInsiderPreview" /f
reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "BuildLabEx" /t REG_SZ /d "22000.plex_rel.240101-1500" /f
reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "Chart Studios Ltd" /f
reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOwner" /t REG_SZ /d "Insider" /f
if (Test-Path .\customizations\registry\branding.reg) {
    reg import .\customizations\registry\branding.reg
}
reg unload HKLM\OFFLINE_SOFTWARE

reg load HKLM\OFFLINE_SYSTEM "$mountDir\Windows\System32\config\SYSTEM"
reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Desktop" /v "PaintDesktopVersion" /t REG_DWORD /d 1 /f
reg unload HKLM\OFFLINE_SYSTEM

$appsToRemove = @("Microsoft.BingWeather", "Microsoft.ZuneMusic", "Microsoft.XboxApp", "Microsoft.GetHelp")
foreach ($app in $appsToRemove) {
    $pkg = Get-AppxProvisionedPackage -Path $mountDir | Where-Object { $_.DisplayName -eq $app }
    if ($pkg) {
        & $dismPath /Image:$mountDir /Remove-ProvisionedAppxPackage /PackageName:$($pkg.PackageName)
    }
}

& $dismPath /Unmount-Wim /MountDir:$mountDir /Commit
