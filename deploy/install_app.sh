#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?env required: staging|prod}"
S3_BUCKET="${2:?artifact bucket name required}"
S3_KEY="${3:?artifact key path required, e.g. artifacts/staging/abcd123.zip}"

ARTIFACT="/tmp/app.zip"
APP_DIR="/opt/myapp"

echo "Downloading s3://${S3_BUCKET}/${S3_KEY}..."
aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${ARTIFACT}"

echo "Stopping service..."
sudo systemctl stop myapp || true

echo "Extracting..."
sudo rm -rf "${APP_DIR:?}/*"
sudo unzip -o "${ARTIFACT}" -d "${APP_DIR}"

echo "Installing deps..."
sudo pip3 install -r "${APP_DIR}/requirements.txt"

echo "Setting env..."
sudo bash -c "echo 'PROJECT_NAME=saas-demo' >/etc/myapp.env"
sudo bash -c "echo 'APP_ENV=${ENVIRONMENT}' >>/etc/myapp.env"

echo "Restarting service..."
sudo systemctl start myapp

echo "Done."
