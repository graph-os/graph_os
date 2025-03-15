#!/bin/bash

# Script to import environment variables from .env file
if [ -f /home/coder/.env ]; then
    echo "Loading environment variables from .env file"
    set -a
    . /home/coder/.env
    set +a
fi

# Ensure npm global bin is in PATH
export PATH=$PATH:$(npm bin -g)

# Set the prompt to show we're in GraphOS
export PS1="\[\e[32m\][GraphOS]\[\e[m\] \[\e[34m\]\w\[\e[m\] $ "