It uses a custom build pipeline
with `python` modules that call each other in the sense of incremental builds.

# Installation

Two bash scripts which set up everything that is needed to run the pipeline on our servers, as well as a requirements.txt file, can be found in ./setup/ :

- setup.sh : downloads miniconda, creates python venv, downloads jdk and maven in ./setup/pipeline_environment.
- activate.sh : activates python venv and adds both jdk and maven to PATH variable

To clean, simply delete the ./setup/pipeline_environment subdirectory.

# Run

The starting point is `run.py`, where some configuration options can be set. Right
now it is not very configurable, but should become more so in the future.


