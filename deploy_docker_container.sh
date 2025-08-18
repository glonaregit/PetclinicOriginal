#!/bin/bash

# Fail fast if required env vars are missing
#if [ -z "$VM_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_PASS" ] || \
 #  [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PASS" ] || \
  # [ -z "$DOCKER_IMAGE_NAME" ] || [ -z "$DOCKER_IMAGE_TAG" ] || \
   #[ -z "$CONTAINER_PORT" ] || [ -z "$INTERNAL_APP_PORT" ]; then
   # echo "❌ Missing required environment variables"
    #exit 1
#fi

NEW_CONTAINER_NAME="petclinic-${DOCKER_IMAGE_TAG}"
IMAGE_NAME_WITH_TAG="${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

echo "Deploying container ${NEW_CONTAINER_NAME} on host ${VM_HOST}..."

# Run deployment commands remotely
SSHPASS=$SSH_PASS sshpass -e ssh -o StrictHostKeyChecking=no "$SSH_USER@$VM_HOST" <<EOF
    echo "Logging in to Docker Hub..."
    echo "$DOCKER_PASS" | sudo docker login -u "$DOCKER_USER" --password-stdin

    echo "Pulling latest Docker image: ${IMAGE_NAME_WITH_TAG}"
    sudo docker pull ${IMAGE_NAME_WITH_TAG}

    echo "Removing any existing container with name ${NEW_CONTAINER_NAME}..."
    sudo docker rm -f ${NEW_CONTAINER_NAME} || true

    echo "Running new container: ${NEW_CONTAINER_NAME} on port ${CONTAINER_PORT} -> ${INTERNAL_APP_PORT}"
    sudo docker run -d --name ${NEW_CONTAINER_NAME} -p ${CONTAINER_PORT}:${INTERNAL_APP_PORT} ${IMAGE_NAME_WITH_TAG}
EOF
