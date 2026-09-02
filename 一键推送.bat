@echo off
chcp 65001 >nul
title AICG-Desktop-Cockpit 一键推送
echo ============================================
echo   AICG-Desktop-Cockpit 一键推送到 GitHub
echo ============================================
echo.
echo 前置步骤（只需一次）：
echo   1. 打开 https://github.com/new 新建仓库
echo      仓库名: AICG-Desktop-Cockpit  (Public, 不要勾选任何初始化文件)
echo   2. 把你的仓库地址粘贴到下面（形如 https://github.com/你的用户名/AICG-Desktop-Cockpit.git）
echo.
set /p REPO_URL=请粘贴仓库地址: 
if "%REPO_URL%"=="" echo 未输入地址，退出 & pause & exit /b

cd /d "%~dp0"
git init -b main 2>nul
git add -A
git commit -m "feat: 漫剧创作桌面驾驶舱 v1.1 一键部署套件（DeskBox+Listen1+Lively+TagStudio+QuickLook+Everything+TranslucentTB）" 2>nul
git remote remove origin 2>nul
git remote add origin "%REPO_URL%"
git push -u origin main --force
echo.
echo ============================================
echo   完成！访问 %REPO_URL% 查看仓库
echo   别忘了在仓库 About 里填一句话简介：
echo   一键把 Windows 桌面变成漫剧生产驾驶舱
echo ============================================
pause
