# Conda Environment Setup

Create the conda environment with cmake before running the build job.

## One-time Setup

```bash
# Load anaconda module
module load anaconda

# Create the environment with cmake
conda create -n llama-build cmake -y

# Verify
source activate llama-build
cmake --version
```

## If you need to rebuild the environment

```bash
module load anaconda
conda remove -n llama-build --all -y
conda create -n llama-build cmake -y
```
