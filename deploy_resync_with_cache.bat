@echo off
setlocal

set "VPS_USER=ubuntu"
set "VPS_HOST=57.128.226.48"
set "LOCAL_DIR=/mnt/c/Users/apoll/client_files"
set "WEB_DIR=/var/www/myaac/client_files"
set "WSL_SSH_KEY=~/.ssh/vpsKey"

echo [1/2] Building client with CWM cache...
call "%~dp0build_with_cache.bat"
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

echo [2/2] Syncing files to VPS via rsync...
wsl -d Ubuntu -- bash -lc "rsync -az --delete --info=stats2,progress2 --rsync-path='sudo rsync' --chown=www-data:www-data --chmod=D755,F644 -e 'ssh -i %WSL_SSH_KEY%' %LOCAL_DIR%/ %VPS_USER%@%VPS_HOST%:%WEB_DIR%/"
if errorlevel 1 (
    echo [ERROR] Rsync deploy failed.
    exit /b 1
)

echo [DONE] Client deployed successfully.
exit /b 0
