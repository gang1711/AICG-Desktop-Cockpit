#Requires -Version 5.1
<#
.SYNOPSIS
  漫剧创作桌面驾驶舱 AICG Desktop Cockpit —— 一键整合部署脚本
.DESCRIPTION
  为漫剧创作者一键部署 Windows 桌面工作流套件：
  DeskBox(格子驾驶舱) + QuickLook(空格预览) + Everything(全盘秒搜) +
  Listen1(聚合音乐搜索) + Lively(动态壁纸/音频可视化) + TagStudio(素材标签) +
  TranslucentTB(沉浸任务栏) + 壁纸自动轮换 + 素材中心目录结构 + DeskBox 13 格配置注入
  脚本会自动关闭相关进程后再修改配置；所有数据本地化，无账号依赖。
.PARAMETER WorkRoot
  漫剧工作台根目录（默认自动：D:\漫剧工作台 → %USERPROFILE%\漫剧工作台）
.PARAMETER AppRoot
  软件安装根目录（默认自动选择 F:\软件 → D:\软件 → %LOCALAPPDATA%\Programs）
.PARAMETER AicgRoot
  AICG 漫剧创作系统根目录（存在则自动映射生产管线/剧组/知识库格子；默认自动探测磁盘上的 *AICG* 目录）
.PARAMETER NoDownload
  跳过下载（已装好组件，只做目录/配置/自启部分）
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\deploy-cockpit.ps1
.NOTES
  作者：叶浩 · 微信 g1711356511 · QQ 1711356511 · GPL-3.0 组件版权归各自作者
#>
param(
  [string]$WorkRoot = "",
  [string]$AppRoot = "",
  [string]$AicgRoot = "",
  [switch]$NoDownload
)
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$dl = "F:"; if (-not (Test-Path "F:\")) { $dl = $env:TEMP }

function Write-Step($msg)  { Write-Host "`n======== $msg ========" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "  [跳过] $msg" -ForegroundColor Yellow }

function Stop-AppProc {
  param([string[]]$Names)
  foreach ($n in $Names) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
      try { $_.CloseMainWindow() | Out-Null } catch {}
    }
  }
  Start-Sleep -Seconds 2
  foreach ($n in $Names) { Stop-Process -Name $n -Force -ErrorAction SilentlyContinue }
}

function Get-FileWithFallback {
  param([string]$Url, [string]$OutFile, [int]$MinSizeKB = 500)
  if (Test-Path $OutFile) { if ((Get-Item $OutFile).Length -gt ($MinSizeKB * 1KB)) { Write-Ok "已存在 $([IO.Path]::GetFileName($OutFile))"; return $true } }
  $mirrors = @($Url, "https://ghfast.top/$Url", "https://gh-proxy.com/$Url")
  foreach ($m in $mirrors) {
    try {
      Invoke-WebRequest -Uri $m -OutFile $OutFile -UseBasicParsing -TimeoutSec 900
      if ((Get-Item $OutFile).Length -gt ($MinSizeKB * 1KB)) { Write-Ok "下载 $([IO.Path]::GetFileName($OutFile))"; return $true }
    } catch { Write-Host "    镜像失败: $($m.Substring(0,[Math]::Min(60,$m.Length)))..." -ForegroundColor DarkGray }
  }
  return $false
}

# ============================================================
Write-Step "0/9 关闭相关进程（避免文件占用）"
Stop-AppProc @("DeskBox","QuickLook","everything","Listen1","Lively","Lively.UI.WinUI","Lively.Watchdog","Lively.Player.WebView2")
Write-Ok "相关进程已全部关闭"

# ============================================================
Write-Step "1/9 选择软件安装根目录"
if (-not $WorkRoot) {
  $found = Get-ChildItem "D:\","D:\灵蟹创作","$env:USERPROFILE" -Directory -Filter "漫剧工作台" -ErrorAction SilentlyContinue | Select-Object -First 1
  $WorkRoot = if ($found) { $found.FullName } elseif (Test-Path "D:\") { "D:\漫剧工作台" } else { "$env:USERPROFILE\漫剧工作台" }
}
if (-not $AicgRoot) {
  $cand = Get-ChildItem "D:\","$env:USERPROFILE" -Directory -Filter "*AICG*" -ErrorAction SilentlyContinue | Select-Object -First 1
  $AicgRoot = if ($cand) { $cand.FullName } else { "" }
}
if (-not $AppRoot) {
  foreach ($c in @("F:\软件","D:\软件","E:\软件","$env:LOCALAPPDATA\Programs")) {
    if ($c -like "*LOCALAPPDATA*" -or (Test-Path (Split-Path $c))) { $AppRoot = $c; break }
  }
}
New-Item -ItemType Directory -Force -Path $AppRoot | Out-Null
Write-Ok "软件根目录: $AppRoot"

# ============================================================
Write-Step "2/9 下载组件（GitHub 镜像加速，失败自动切换）"
$files = [ordered]@{
  "DeskBox_Setup_1.4.8_x64.exe" = "https://github.com/Tianyu199509/DeskBox/releases/download/v1.4.8/DeskBox_Setup_1.4.8_x64.exe"
  "listen1_2.33.0_win_x64.exe"  = "https://github.com/listen1/listen1_desktop/releases/download/v2.33.0/listen1_2.33.0_win_x64.exe"
  "lively_setup_x86_full_v2210.exe" = "https://github.com/rocksdanister/lively/releases/download/v2.2.1.0/lively_setup_x86_full_v2210.exe"
  "QuickLook-4.5.0.zip"         = "https://github.com/QL-Win/QuickLook/releases/download/v4.5.0/QuickLook-4.5.0.zip"
  "Everything-1.4.1.1028.x64.zip" = "https://www.voidtools.com/Everything-1.4.1.1028.x64.zip"
  "tagstudio_v9.6.3_windows_x86_64_portable.zip" = "https://github.com/TagStudioDev/TagStudio/releases/download/v9.6.3/tagstudio_v9.6.3_windows_x86_64_portable.zip"
  "TranslucentTB-2026.1-bundle.msixbundle" = "https://github.com/TranslucentTB/TranslucentTB/releases/download/2026.1/bundle.msixbundle"
}
$ok = @{}
foreach ($k in $files.Keys) {
  $out = Join-Path $dl $k
  if ($NoDownload) { if (Test-Path $out) { $ok[$k] = $true; continue } else { Write-Warn2 "未找到 $k（-NoDownload 模式）"; continue } }
  $ok[$k] = Get-FileWithFallback -Url $files[$k] -OutFile $out
}

# ============================================================
Write-Step "3/9 安装 DeskBox（格子驾驶舱）"
$deskboxExe = "$env:LOCALAPPDATA\Programs\DeskBox\DeskBox.exe"
if (-not (Test-Path $deskboxExe)) { $deskboxExe = "$AppRoot\DeskBox\DeskBox.exe" }
if (-not (Test-Path $deskboxExe) -and $ok["DeskBox_Setup_1.4.8_x64.exe"]) {
  Start-Process -FilePath (Join-Path $dl "DeskBox_Setup_1.4.8_x64.exe") -ArgumentList "/VERYSILENT","/NORESTART","/SUPPRESSMSGBOXES" -Wait
  Start-Sleep 3
  foreach ($c in @("$env:LOCALAPPDATA\Programs\DeskBox\DeskBox.exe","$AppRoot\DeskBox\DeskBox.exe")) { if (Test-Path $c) { $deskboxExe = $c; break } }
}
if (Test-Path $deskboxExe) { Write-Ok "DeskBox: $deskboxExe" } else { Write-Warn2 "DeskBox 未检测到，格子配置将跳过" }

Write-Step "4/9 安装 QuickLook / Everything / Listen1 / Lively / TagStudio / TranslucentTB"
# QuickLook（便携）
$qlExe = "$AppRoot\QuickLook\QuickLook.exe"
if (-not (Test-Path $qlExe) -and $ok["QuickLook-4.5.0.zip"]) {
  New-Item -ItemType Directory -Force -Path "$AppRoot\QuickLook" | Out-Null
  Expand-Archive -Path (Join-Path $dl "QuickLook-4.5.0.zip") -DestinationPath "$AppRoot\QuickLook" -Force
}
if (Test-Path $qlExe) { Write-Ok "QuickLook: $qlExe" } else { Write-Warn2 "QuickLook" }
# Everything（便携）
$evExe = "$AppRoot\Everything\everything.exe"
if (-not (Test-Path $evExe) -and $ok["Everything-1.4.1.1028.x64.zip"]) {
  New-Item -ItemType Directory -Force -Path "$AppRoot\Everything" | Out-Null
  Expand-Archive -Path (Join-Path $dl "Everything-1.4.1.1028.x64.zip") -DestinationPath "$AppRoot\Everything" -Force
}
if (Test-Path $evExe) { Write-Ok "Everything: $evExe" } else { Write-Warn2 "Everything" }
# Listen1（安装版，可能弹一次 UAC 确认）
$listen1Exe = "C:\Program Files\Listen1\Listen1.exe"
if (-not (Test-Path $listen1Exe) -and $ok["listen1_2.33.0_win_x64.exe"]) {
  Start-Process -FilePath (Join-Path $dl "listen1_2.33.0_win_x64.exe") -ArgumentList "/S" -Wait
  Start-Sleep 3
}
if (Test-Path $listen1Exe) { Write-Ok "Listen1: $listen1Exe" } else { Write-Warn2 "Listen1（若 UAC 弹窗请点允许后重跑）" }
# Lively（Inno 静默，用户级）
$livelyExe = "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
if (-not (Test-Path $livelyExe) -and $ok["lively_setup_x86_full_v2210.exe"]) {
  Start-Process -FilePath (Join-Path $dl "lively_setup_x86_full_v2210.exe") -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART" -Wait
  Start-Sleep 3
}
if (Test-Path $livelyExe) { Write-Ok "Lively: $livelyExe" } else { Write-Warn2 "Lively" }
# TagStudio（便携）
$tsExe = "$AppRoot\TagStudio\TagStudio.exe"
if (-not (Test-Path $tsExe) -and $ok["tagstudio_v9.6.3_windows_x86_64_portable.zip"]) {
  New-Item -ItemType Directory -Force -Path "$AppRoot\TagStudio" | Out-Null
  Expand-Archive -Path (Join-Path $dl "tagstudio_v9.6.3_windows_x86_64_portable.zip") -DestinationPath "$AppRoot\TagStudio" -Force
}
if (Test-Path $tsExe) { Write-Ok "TagStudio: $tsExe" } else { Write-Warn2 "TagStudio" }
# TranslucentTB（msix 应用包）
$tbPkg = Get-AppxPackage -Name "*TranslucentTB*" -ErrorAction SilentlyContinue
if (-not $tbPkg -and $ok["TranslucentTB-2026.1-bundle.msixbundle"]) {
  try { Add-AppxPackage -Path (Join-Path $dl "TranslucentTB-2026.1-bundle.msixbundle") -ErrorAction Stop } catch { Write-Warn2 "TranslucentTB 安装失败: $($_.Exception.Message)" }
}
$tbPkg = Get-AppxPackage -Name "*TranslucentTB*" -ErrorAction SilentlyContinue
if ($tbPkg) { Write-Ok "TranslucentTB: $($tbPkg.Version)（任务栏默认已全透明）" } else { Write-Warn2 "TranslucentTB" }

# ============================================================
Write-Step "5/9 搭建漫剧工作台目录结构"
$dirs = @(
  "$WorkRoot", "$WorkRoot\AI创作应用", "$WorkRoot\常用工具",
  "$WorkRoot\归档库\项目压缩包", "$WorkRoot\归档库\照片素材", "$WorkRoot\归档库\文档便签", "$WorkRoot\归档库\网络与下载",
  "$WorkRoot\收纳箱\待处理", "$WorkRoot\氛围板",
  "$WorkRoot\素材中心\音乐库", "$WorkRoot\素材中心\视频素材",
  "$WorkRoot\素材中心\壁纸库\静态", "$WorkRoot\素材中心\壁纸库\动态", "$WorkRoot\素材中心\壁纸库\可视化"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
Write-Ok "工作台目录: $WorkRoot（含素材中心/壁纸库/归档库/收纳箱）"

# ============================================================
Write-Step "6/9 注入 DeskBox 16 格驾驶舱配置"
if ((Test-Path $deskboxExe) -and -not $SkipDeskBoxConfig) {
  Stop-AppProc @("DeskBox"); Start-Sleep 1
  $cfgDir = "$env:LOCALAPPDATA\DeskBox\data"
  $cfgPath = "$cfgDir\settings.json"
  if (Test-Path $cfgPath) {
    $s = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $monKey = "0:0:1920:1040"; $monDev = "\\.\DISPLAY1"
    function New-W {
      param($name,$kind,$x,$y,$wd,$ht,$anchor,$map)
      $left = ($anchor -eq "L")
      $o = [ordered]@{
        id = [guid]::NewGuid().ToString(); name = $name; isDefaultTitle = $false
        x = $x; y = $y; needsInitialPlacement = $false
        positionAnchor = $(if ($left) {"LeftTop"} else {"RightTop"})
        positionMarginX = $(if ($left) {$x} else {1920 - $wd - $x})
        positionMarginY = $y
        positionMonitorKey = $monKey; positionMonitorDeviceName = $monDev
        positionMonitorWasPrimary = $true; boundsCoordinateVersion = 1
        width = $wd; height = $ht; widgetKind = $kind; viewMode = "Icon"
        isVisible = $true; isDisabled = $false; isPositionLocked = $false
        isSizeLocked = $false; isCollapsed = $false; metadata = @{}
        mappedFolderPath = $map; followsDefaultStoragePath = $false
        managedFolderName = $null; sortMode = "Name"; sortDescending = $false
        items = @(); fileAddedAtByPath = @{}; fileAddedAtTrackingInitialized = $true
      }
      return [PSCustomObject]$o
    }
    $prodMap = "$AicgRoot\production"; $crewMap = "$AicgRoot\projects\剧组"; $inboxMap = "$AicgRoot\knowledge\00_Inbox"
    if (-not (Test-Path $AicgRoot)) { $prodMap = $WorkRoot; $crewMap = $WorkRoot; $inboxMap = $WorkRoot }
    $promptMap = "$WorkRoot\知识中枢\01_提示词库"
    if (Test-Path "$AicgRoot\knowledge\04_Prompts") { $promptMap = "$AicgRoot\knowledge\04_Prompts" }
    $hubMap = "$WorkRoot\知识中枢"
    $skillLibMap = "$hubMap\02_技能库"
    $W = @(
      (New-W "时光"        "Glance" 24   72  280 220 "L" $null)
      (New-W "漫剧生产管线" "File"   24   312 280 420 "L" $prodMap)
      (New-W "剧组项目"     "File"   24   752 280 260 "L" $crewMap)
      (New-W "待处理"       "File"   324  72  280 340 "L" "$WorkRoot\收纳箱\待处理")
      (New-W "工作台归档"   "File"   324  432 280 260 "L" "$WorkRoot\归档库")
      (New-W "素材中心"     "File"   624  72  300 340 "L" "$WorkRoot\素材中心")
      (New-W "知识中枢"     "File"   624  432 300 340 "L" $hubMap)
      (New-W "知识收件箱"   "File"   324  712 280 300 "L" $inboxMap)
      (New-W "提示词库"     "File"   944  72  300 300 "L" $promptMap)
      (New-W "技能库"       "File"   944  392 300 300 "L" $skillLibMap)
      (New-W "AI创作应用"   "File"   1596 72  300 430 "R" "$WorkRoot\AI创作应用")
      (New-W "常用工具"     "File"   1596 522 300 330 "R" "$WorkRoot\常用工具")
      (New-W "待办"         "Todo"   1276 72  300 360 "R" $null)
      (New-W "随记"         "QuickCapture" 1276 452 300 360 "R" $null)
      (New-W "天气"         "Weather" 1276 832 300 220 "R" $null)
      (New-W "音乐"         "Music"  1056 832 300 220 "R" $null)
    )
    foreach ($w in $W) {
      if ($w.name -in @("天气","音乐")) {
        $w.isCollapsed = $true
        $w.metadata["CollapseBehavior"] = "Smart"
        $w | Add-Member -NotePropertyName compactPlacement -NotePropertyValue ([PSCustomObject]@{
          x = $w.x; y = 832; positionAnchor = "LeftTop"; positionMarginX = $w.x; positionMarginY = 832
          positionMonitorKey = $monKey; positionMonitorDeviceName = $monDev
          positionMonitorWasPrimary = $true; boundsCoordinateVersion = 1 }) -Force
      } else {
        $w.metadata["CollapseBehavior"] = "Click"
        if ($w.name -in @("AI创作应用","常用工具","素材中心")) { $w.metadata["FileStacksEnabled"] = "false" }
      }
    }
    $inbox = $W | Where-Object { $_.name -eq "待处理" }
    $inbox | Add-Member -NotePropertyName followsDefaultStoragePath -NotePropertyValue $true -Force
    $inbox | Add-Member -NotePropertyName managedFolderName -NotePropertyValue "待处理" -Force
    $s.widgets = $W
    $s.widgetGroups = @()
    $s.featureWidgetEnabledStates = [PSCustomObject]@{ QuickCapture = $true; Todo = $true; Music = $true; Weather = $true; Search = $true; Glance = $true }
    $s.quickCaptureEnabled = $true; $s.todoEnabled = $true
    $s.globalHotkeyEnabled = $true; $s.globalHotkeyModifiers = 3; $s.globalHotkeyKey = 68
    $s.fileStacksEnabled = $true; $s.fileStackAutoStacking = $true; $s.fileStackGroupBy = "Kind"; $s.fileStackThreshold = 3
    $s.defaultManagedStorageRootPath = "$WorkRoot\收纳箱"
    $s.desktopAutoOrganizationEnabled = $true
    $s.desktopOrganizationRules = @([PSCustomObject]@{
      id = [guid]::NewGuid().ToString("N"); targetWidgetId = $inbox.id; isEnabled = $true
      categoryIds = @(); subtypeIds = @()
      extensions = @("jpg","jpeg","png","webp","gif","bmp","mp4","mov","mkv","avi","webm","zip","rar","7z","txt","md","docx","doc","xlsx","pptx","pdf","wav","mp3","flac","m4a","psd","srt","ass","url")
      excludedExtensions = @("lnk","tmp","crdownload","part") })
    [IO.File]::WriteAllText($cfgPath, ($s | ConvertTo-Json -Depth 10))
    Write-Ok "DeskBox 16 格配置已注入（热键 Ctrl+Alt+D / 五色待办 / 自动整理 / 收纳根=$WorkRoot\收纳箱）"
  } else { Write-Warn2 "未找到 DeskBox 配置文件（先手动启动一次 DeskBox 再重跑）" }
} else { Write-Warn2 "跳过 DeskBox 配置注入" }

# ============================================================
Write-Step "7/9 TagStudio 简体中文 + 壁纸轮换 + 自启"
$tsDir = "$env:APPDATA\TagStudio"
New-Item -ItemType Directory -Force -Path $tsDir | Out-Null
$tsToml = "$tsDir\settings.toml"
if (-not (Test-Path $tsToml)) {
  [IO.File]::WriteAllText($tsToml, "language = `"zh_Hans`"`r`nopen_last_loaded_on_startup = true`r`nautoplay = true`r`ntheme = 2`r`n")
  Write-Ok "TagStudio 语言 = 简体中文"
} else {
  $toml = [IO.File]::ReadAllText($tsToml) -replace 'language = "[^"]*"', 'language = "zh_Hans"'
  [IO.File]::WriteAllText($tsToml, $toml)
  Write-Ok "TagStudio 语言已切简体中文"
}
# 壁纸轮换循环脚本（放纯 ASCII 路径，规避启动器中文编码问题）
$ck = "$env:LOCALAPPDATA\AICGCockpit"
New-Item -ItemType Directory -Force -Path $ck | Out-Null
$rot = @'
$ErrorActionPreference = 'SilentlyContinue'
$lib = '__WORKROOT__\素材中心\壁纸库'
$lively = '__LIVELY__'
while ($true) {
    if (-not (Test-Path ($lib + '\暂停轮换.flag'))) {
        $files = @(Get-ChildItem ($lib + '\静态') -Recurse -Include *.png,*.jpg,*.jpeg,*.webp) +
                 @(Get-ChildItem ($lib + '\动态') -Recurse -Include *.mp4,*.webm,*.mov)
        if ($files.Count -gt 0) {
            $pick = Get-Random -InputObject $files
            Start-Process -FilePath $lively -ArgumentList 'setwp','--file',('"' + $pick.FullName + '"') -WindowStyle Hidden
        }
    }
    Start-Sleep -Seconds 3600
}
'@
$rot = $rot.Replace('__WORKROOT__', $WorkRoot).Replace('__LIVELY__', $livelyExe)
[IO.File]::WriteAllText("$ck\wallpaper-rotate.ps1", $rot, (New-Object System.Text.UTF8Encoding($true)))
$vbs = "CreateObject(""Wscript.Shell"").Run ""powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """"$ck\wallpaper-rotate.ps1"""""", 0, False"
[IO.File]::WriteAllText("$ck\wallpaper-rotate-launcher.vbs", $vbs)
$startup = [Environment]::GetFolderPath("Startup")
Remove-Item "$startup\壁纸轮换启动.vbs" -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*壁纸轮换循环.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Copy-Item "$ck\wallpaper-rotate-launcher.vbs" $startup -Force
Start-Process wscript.exe -ArgumentList "`"$ck\wallpaper-rotate-launcher.vbs`"" -WindowStyle Hidden
Write-Ok "壁纸轮换：每 60 分钟随机轮换（暂停 = 壁纸库建「暂停轮换.flag」文件）"
# 开机自启注册表
$run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $qlExe)  { Set-ItemProperty -Path $run -Name "QuickLook"  -Value "`"$qlExe`""  }
if (Test-Path $evExe)  { Set-ItemProperty -Path $run -Name "Everything" -Value "`"$evExe`" -startup" }
if (Test-Path $listen1Exe) { Set-ItemProperty -Path $run -Name "Listen1" -Value "`"$listen1Exe`"" }
Write-Ok "自启：QuickLook / Everything / Listen1（Lively 与 TranslucentTB 自带自启）"

# ---- 知识中枢（管理器 + 收件箱看护 + 默认配置）----
$hub = "$WorkRoot\知识中枢"
New-Item -ItemType Directory -Force -Path "$hub\_索引" | Out-Null
$mgrSrc = $null
foreach ($c in @((Join-Path $PSScriptRoot "知识中枢.py"), (Join-Path $PSScriptRoot "resources\知识中枢.py"))) {
  if (Test-Path $c) { $mgrSrc = $c; break }
}
if (-not $mgrSrc) {
  $mgrDl = Join-Path $env:TEMP "知识中枢.py"
  if (Get-FileWithFallback -Url "https://raw.githubusercontent.com/gang1711/AICG-Desktop-Cockpit/main/%E7%9F%A5%E8%AF%86%E4%B8%AD%E6%9E%A2.py" -OutFile $mgrDl -MinSizeKB 5) { $mgrSrc = $mgrDl }
}
if ($mgrSrc) {
  Copy-Item $mgrSrc "$hub\知识中枢.py" -Force
  $cfgHub = [ordered]@{
    inject_target = (Join-Path $env:USERPROFILE ".agents\skills")
    harvest_roots = @()
    size_copy_limit_mb = 20
    harvest_max_minutes = 8
  }
  foreach ($d in (Get-PSDrive -PSProvider FileSystem)) { if ($d.Name -notin @("C")) { $cfgHub.harvest_roots += ($d.Name + ":\") } }
  if (-not $cfgHub.harvest_roots) { $cfgHub.harvest_roots += "C:\" }
  [IO.File]::WriteAllText("$hub\config.json", ($cfgHub | ConvertTo-Json -Depth 5))
  $kw = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$py = "F:\python312\python.exe"
if (-not (Test-Path `$py)) { `$py = (Get-Command python -ErrorAction SilentlyContinue).Source }
if (-not `$py) { exit }
`$hub = "$hub"
while (`$true) {
  `$inbox = "`$hub\00_收件箱"
  if ((Test-Path `$inbox) -and ((Get-ChildItem `$inbox -Recurse -File | Measure-Object).Count -gt 0)) {
    Start-Process -FilePath `$py -ArgumentList "`"`$hub\知识中枢.py`"","scan","--tidy" -WindowStyle Hidden -Wait
  }
  Start-Sleep -Seconds 300
}
"@
  $ck = "$env:LOCALAPPDATA\AICGCockpit"
  New-Item -ItemType Directory -Force -Path $ck | Out-Null
  [IO.File]::WriteAllText("$ck\knowledge-watch.ps1", $kw, (New-Object System.Text.UTF8Encoding($true)))
  $vbs2 = "CreateObject(""Wscript.Shell"").Run ""powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """"$ck\knowledge-watch.ps1"""""", 0, False"
  [IO.File]::WriteAllText("$ck\knowledge-watch-launcher.vbs", $vbs2)
  $startup2 = [Environment]::GetFolderPath("Startup")
  Copy-Item "$ck\knowledge-watch-launcher.vbs" $startup2 -Force
  Start-Process wscript.exe -ArgumentList "`"$ck\knowledge-watch-launcher.vbs`"" -WindowStyle Hidden
  Write-Ok "知识中枢：管理器+收件箱看护已部署（$hub）"
} else { Write-Warn2 "未找到 知识中枢.py，跳过知识中枢部署" }

# ============================================================
Write-Step "8/9 启动全部组件"
if (Test-Path $deskboxExe)   { Start-Process $deskboxExe }
if (Test-Path $qlExe)        { Start-Process $qlExe }
if (Test-Path $evExe)        { Start-Process $evExe -ArgumentList "-startup" }
if (Test-Path $listen1Exe)   { Start-Process $listen1Exe }
if (Test-Path $livelyExe)    { Start-Process $livelyExe }
Start-Sleep 12
if ($livelyExe -and (Get-Process Lively -ErrorAction SilentlyContinue)) {
  $seed = Get-ChildItem "$WorkRoot\素材中心\壁纸库\静态" -Include *.png,*.jpg -Recurse | Select-Object -First 1
  if ($seed) { Start-Process $livelyExe -ArgumentList 'setwp','--file',"`"$($seed.FullName)`"" -WindowStyle Hidden; Write-Ok "首张漫剧壁纸已上墙: $($seed.Name)" }
}
Start-Process explorer.exe "$WorkRoot"
Write-Ok "全部组件已启动"

# ============================================================
Write-Step "9/9 完成！手动收尾清单（各 10 秒）"
Write-Host @"
  [ ] 时光格氛围板：右键时光格 → 背景设置 → 本地文件夹 → 选 $WorkRoot\素材中心\壁纸库\静态
  [ ] TagStudio 建库：$tsExe → 打开/创建库 → 选 $WorkRoot\素材中心
  [ ] 格子组（可选）：按住一个格子标题拖到另一个格子标题上，松手成组
  [ ] Lively 设置 → 勾选「全屏时暂停」（剪辑/生图时省 GPU）
  [ ] 听歌时可视化：Lively 库选 Fluids / Music Tunnel / Music TV
  [ ] 发布漫剧请用可商用 BGM；Listen1 仅限个人试听找感觉
"@ -ForegroundColor White
Write-Host "`n漫剧创作桌面驾驶舱部署完成。反馈/交流：微信 g1711356511 · QQ 1711356511 · 叶浩`n" -ForegroundColor Magenta
