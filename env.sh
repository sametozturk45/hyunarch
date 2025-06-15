#!/bin/bash

# This script sets up the environment variables for the project.
if [ -z "${ROOT_DIR+x}" ]; then
  ROOT_DIR="$(pwd)"
fi
