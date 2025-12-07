#!/bin/bash

# List of extensions to install
extensions=(
  "ms-python.python"
  "ms-toolsai.jupyter"
  "CS50.ddb50"
  # add more extensions here
)

# Install each extension
for extension in "${extensions[@]}"; do
  code --install-extension "$extension" &
done

# Wait for all background jobs (extension installations) to complete
wait

echo "All extensions have been installed."
