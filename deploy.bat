@echo off
setlocal

set "VPS_USER=ubuntu"
set "VPS_HOST=57.128.226.48"
set "SSH_KEY=D:\publicKeys\vpsKey"
set "LOCAL_DIR=C:\Users\apoll\client_files"
set "REMOTE_DIR=/home/ubuntu/client_files"
set "WEB_DIR=/var/www/myaac/client_files"

echo [1/3] Building client...
call "%~dp0build_windows_release_copy.bat"
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

echo [2/3] Uploading files to VPS via scp...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_HOST% "rm -rf %REMOTE_DIR% && mkdir -p %REMOTE_DIR%"
scp -r -i "%SSH_KEY%" "%LOCAL_DIR%\*" %VPS_USER%@%VPS_HOST%:%REMOTE_DIR%/
if errorlevel 1 (
    echo [ERROR] Upload failed.
    exit /b 1
)

echo [3/3] Deploying to web directory...
ssh -i "%SSH_KEY%" %VPS_USER%@%VPS_HOST% "sudo rsync -a --delete %REMOTE_DIR%/ %WEB_DIR%/ && sudo chown -R www-data:www-data %WEB_DIR%/ && sudo chmod -R 755 %WEB_DIR%/"
if errorlevel 1 (
    echo [ERROR] Deploy failed.
    exit /b 1
)

echo [DONE] Client deployed successfully.
exit /b 0
