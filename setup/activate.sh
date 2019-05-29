#!/bin/bash

environment_directory=$(realpath "$1")

if [ ! -f ${environment_directory}/miniconda_installed ] && [ ! -f ${environment_directory}/miniconda_local ]; then
    echo "Miniconda is not installed properly."
    exit 1
elif [ -f ${environment_directory}/miniconda_installed ]; then
    PATH=${environment_directory}/miniconda3/bin:$PATH
fi

echo "Testing Miniconda ..."
conda -V

if [ ! -f ${environment_directory}/python_installed ]; then
    echo "Python environment is not installed properly."
    exit 1
else
    source activate ${environment_directory}/venv

    echo "Testing Python ..."
    which python3
    python3 --version
    conda info -e
fi

if [ ! -f ${environment_directory}/jdk_installed ] && [ ! -f ${environment_directory}/jdk_local ]; then
    echo "OpenJDK is not installed properly."
    exit 1
elif [ -f ${environment_directory}/jdk_installed ]; then
    PATH=${environment_directory}/jdk/bin:$PATH
    JAVA_HOME=${environment_directory}/jdk
fi

echo "Testing OpenJDK ..."
javac -version
java_version=$(java -version 2>&1)
echo ${java_version}
if [[ ! $(echo "$java_version" | grep "1.8" ) ]]; then
	echo "Java 1.8 is required, please run setup.sh again requesting java or install manually."
	exit 1
fi

if [ ! -f ${environment_directory}/maven_installed ] && [ ! -f ${environment_directory}/maven_local ]; then
    echo "Maven is not installed properly."
    exit 1
elif [ -f ${environment_directory}/maven_installed ]; then
    PATH=${environment_directory}/maven/bin:$PATH
fi

echo "Testing Maven ..."
mvn -version

if [ ! -f ${environment_directory}/r_installed ]; then
    echo "R additional dependencies are not installed properly."
    exit 1
else
    echo "Testing R and non-conda dependencies..."
    Rscript --version
    r_requirements_pacman="'pacman', 'dodgr', 'osmdata'"
    Rscript -e "all(pacman::p_isinstalled(c(${r_requirements_pacman})))"
fi

echo "Environment is set up."