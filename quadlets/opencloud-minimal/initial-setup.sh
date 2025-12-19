#!/bin/bash
# initial-setup.sh
# Script to initialize OpenCloud rootless Podman container

# Hardcoded admin password
ADMIN_PASSWORD="admin"

# Create required volumes if they don't exist
podman volume create opencloud_config
podman volume create opencloud_data

# Run OpenCloud initialization
podman run --rm -it \
  -v opencloud_config:/etc/opencloud \
  -v opencloud_data:/var/lib/opencloud \
  -e IDM_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  docker.io/opencloudeu/opencloud-rolling:latest init
