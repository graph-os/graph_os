#!/bin/bash

# Extract and initialize app repositories
extract_app() {
  app_name=$1
  echo "Extracting $app_name..."
  
  # Create a temporary directory
  temp_dir=$(mktemp -d)
  echo "Created temp directory: $temp_dir"
  
  # Copy app files
  cp -r apps/$app_name/* $temp_dir/
  
  # Initialize git and push to GitHub
  cd $temp_dir
  git init
  git add .
  git commit -m "Initial commit of $app_name"
  git branch -M main
  git remote add origin git@github.com:graph-os/$app_name.git
  git push -u origin main
  
  # Clean up
  cd -
  echo "Completed extraction of $app_name"
  echo "------------------------------------------------"
}

# Extract each app
extract_app "graph_os_graph"
extract_app "graph_os_core"
extract_app "graph_os_mcp"
extract_app "graph_os_distributed"

echo "All apps have been extracted and pushed to their repositories." 