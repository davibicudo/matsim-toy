## Installation

Running the proposed framework requires Java (version 1.8), Maven (version 3), R (version 3.5) and Python (version 3.6), besides a number of R libraries and a few Python libraries. 

A setup script is provided that handles the installation of all needed packages in a separate environment via Miniconda3. This script makes sure everything is in place before actually starting the modelling. To use it, simply run:

    source setup/setup.sh <target directory> <software to be installed>

Where the first argument is the folder where the needed files will be downloaded and installed and the second argument is a comma-separated list of the software required (e.g. `java,maven,conda` for all options, without spaces). R, Python and all required libraries are installed with help of Miniconda3 in a separate environment (the target directory) which can later be deleted for a clean uninstall. 

Alternatively, a manual installation is also possible. If the required software are available, it is only needed to install a few Python libraries (tqdm, pyyaml, pandas and requests) and pacman, a package manager for R which will handle later the installation of the remaining R libraries on-the-run.

## Quick start

1. Download (or clone) the GitHub repository.
2. Run source setup/setup.sh env_dir java,maven,conda 
3. Run source setup/activate.sh env_dir (tests and activates the conda environment).
4. Edit the config.yml file (optional, otherwise will build and run a small example)
5. Run python run.py

If none of the required software or libraries were available, installing can take several minutes, depending on the speed of the internet connection. 

Running the framework takes also some time, depending on the size of the scenario. The example provided is a 10% scenario for Luzern (Switzerland), a relatively small city with ~90’000 inhabitants, which takes about 11 minutes to build and 23 minutes to run 100 iterations in MATSim in a 16GB macOS i7.

## Configuration

The configuration for running the different steps is stored in a yml file. The example config.yml contains the configuration for the initial example and contains minimal configuration and only the final step, which means all other steps are run with default arguments. The config_full.yml on the other hand shows all steps available with their respective arguments. The argument values are the default so running the framework with config.yml and config_full.yml produces the same results, although running a second time would only trigger the last step in the former while re-running the entire pipeline in the latter.

## Alternative uses

The proposed framework’s intended use is mainly to create and run a toy MATSim scenario for any given city, but the steps implemented may be used in different ways and adapted to other needs. Most importantly, the scripts may be edited or replaced entirely in order to accommodate additional input data, still taking advantage of the other steps implemented and the pipeline’s chaining and caching capabilities.

