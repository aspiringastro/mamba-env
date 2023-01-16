curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-$(uname)-$(uname -m).sh"
bash Mambaforge-$(uname)-$(uname -m).sh

# Don't auto activate the base environment
conda config --set auto_activate_base false

# Remove the downloaded file
rm Mambaforge-Darwin-x86_64.sh

