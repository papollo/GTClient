#!/bin/bash
set -e

VPS_USER="ubuntu"
VPS_HOST="57.128.226.48"
SSH_KEY="/d/publicKeys/vpsKey"
LOCAL_DIR="/c/Users/apoll/client_files"
REMOTE_DIR="/home/ubuntu/client_files"
WEB_DIR="/var/www/myaac/client_files"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[1/3] Building client..."
cmd.exe //C "$(cygpath -w "$SCRIPT_DIR/build_windows_release_copy.bat")"

echo "[2/3] Uploading files to VPS via rsync..."
rsync -avz --delete -e "ssh -i $SSH_KEY" "$LOCAL_DIR/" "$VPS_USER@$VPS_HOST:$REMOTE_DIR/"

echo "[3/3] Deploying to web directory..."
ssh -i "$SSH_KEY" "$VPS_USER@$VPS_HOST" "sudo rsync -a --delete $REMOTE_DIR/ $WEB_DIR/"

echo "[DONE] Client deployed successfully."
