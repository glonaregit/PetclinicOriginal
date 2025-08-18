#!/bin/bash

# Fail fast if required env vars are missing
if [ -z "$VM_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_PASS" ] || [ -z "$CONTAINER_PORT" ]; then
    echo "❌ Missing required environment variables (VM_HOST, SSH_USER, SSH_PASS, CONTAINER_PORT)"
    exit 1
fi

echo "🔍 Checking for existing container on port ${CONTAINER_PORT} on host ${VM_HOST}..."

# Use sshpass with env var
SSHPASS=$SSH_PASS sshpass -e ssh -o StrictHostKeyChecking=no "$SSH_USER@$VM_HOST" <<EOF
    EXISTING_CONTAINER_ID=\$(sudo docker ps -q --filter "publish=${CONTAINER_PORT}")
    if [ -n "\$EXISTING_CONTAINER_ID" ]; then
        echo "🛑 Stopping and removing container with ID: \$EXISTING_CONTAINER_ID on port ${CONTAINER_PORT}"
        sudo docker stop \$EXISTING_CONTAINER_ID
        sudo docker rm \$EXISTING_CONTAINER_ID
    else
        echo "✅ No existing container found on port ${CONTAINER_PORT}."
    fi
EOF
