#!/bin/bash

# Install lexical-lsp
echo "Installing lexical-lsp..."
git clone git@github.com:lexical-lsp/lexical.git lexical-lsp

# Change to the lexical directory
cd lexical-lsp

mix deps.get
mix package
