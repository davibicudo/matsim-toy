#!/bin/bash
set -e

# get OS
if [[ "$OSTYPE" == "linux-gnu" ]]; then
        os_name=Linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_name=MacOSX
elif [[ "$OSTYPE" == "cygwin" ]]; then
		os_name=Windows
        # POSIX compatibility layer and Linux environment emulation for Windows
elif [[ "$OSTYPE" == "msys" ]]; then
		os_name=Windows
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
elif [[ "$OSTYPE" == "win32" ]]; then
		os_name=Windows
        # I'm not sure this can happen.
elif [[ "$OSTYPE" == "freebsd"* ]]; then
		os_name=Linux
else
        os_name=Linux
fi

# Define Miniconda3
miniconda_version="4.6.14"
miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-${os_name}-x86_64.sh"
miniconda_md5="718259965f234088d785cad1fbd7de03"

python_version="3.6"

jdk_version="8u212"
jdk_url="https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b03/OpenJDK8U-jdk_x64_linux_hotspot_8u212b03.tar.gz"
jdk_sha256="dd28d6d2cde2b931caf94ac2422a2ad082ea62f0beee3bf7057317c53093de93"

maven_version="3.6.1"
maven_url="http://mirror.easyname.ch/apache/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz"
maven_sha512="b4880fb7a3d81edd190a029440cdf17f308621af68475a4fe976296e71ff4a4b546dd6d8a58aaafba334d309cc11e638c52808a4b0e818fc0fd544226d952544"

r_version="3.5.1"

# Define Python requirements
python_requirements=$(cat <<EOF
tqdm==4.30.0
pyyaml==3.13
pandas==0.24.1
requests==2.21.0
EOF
)

# Define R requirements (for conda to install)
r_requirements_conda=$(cat <<EOF
r
r-httr=1.4
r-rcpp=1.0.1
r-rvest=0.3.4
r-tibble
r-digest=0.6.19
r-igraph=1.2.4
r-rcppparallel
r-rgdal
r-rgeos
r-osmar
r-fnn
r-truncnorm
r-optparse
r-wikidatar
r-wdi
r-sp
r-sf
r-jsonlite
r-isocodes
r-data.table
r-raster
r-lubridate
r-remotes
r-devtools
EOF
)

# Define additional R requirements (not available in conda)
r_requirements_cran="'pacman', 'dodgr', 'osmdata'"

# Miniconda update script to avoid too long paths in interpreter path
miniconda_update_script=$(cat <<EOF
import sys
import re

with open(sys.argv[1]) as f:
    content = f.read()
    content = re.sub(r'#!(.+)/miniconda3/bin/python', '#!/usr/bin/env python', content)

with open(sys.argv[1], "w+") as f:
    f.write(content)
EOF
)

# I) Ensure the target directory is there
environment_directory=$(realpath "$1")
# name of the tools that should be installed in the target directory
install_tools=$2
# original caller's path
origin_directory=$(echo $PWD)

if [ ! -d ${environment_directory} ]; then
    echo "Creating target directory: ${environment_directory}"
    mkdir -p ${environment_directory}
else
    echo "Target directory already exists: ${environment_directory}"
fi

cd ${environment_directory}

# II) Downloads

## II.1) Download Miniconda
if [ $(echo $install_tools | grep "conda") ]; then
	if [ -f "miniconda.sh" ]; then
	    echo "Miniconda 3 already downloaded."
	else
	    echo "Downloading Miniconda3 ..."
	    rm -rf miniconda_installed
	    rm -rf python_installed
	    rm -rf r_installed
	    curl -o miniconda.sh ${miniconda_url}
	fi
else 	
	echo "Using local Miniconda3 installation."
	touch miniconda_local
fi

## II.2) Download JDK
if [ $(echo $install_tools | grep -E "jdk|java") ]; then
	if [ "$(shasum -a 256 jdk.tar.gz)" == "${jdk_sha256}  jdk.tar.gz" ]; then
	    echo "OpenJDK ${jdk_version} already downloaded."
	else
	    echo "Downloading OpenJDK ${jdk_version} ..."
	    rm -rf jdk_installed
	    curl -L -o jdk.tar.gz ${jdk_url}
	fi
else 
	echo "Using local Java installation."
	touch jdk_local
fi

## II.3) Download Maven
if [ $(echo $install_tools | grep -E "mvn|maven") ]; then
	if [ "$(shasum -a 512 maven.tar.gz)" == "${maven_sha512}  maven.tar.gz" ]; then
	    echo "Maven ${maven_version} already downloaded."
	else
	    echo "Maven ${maven_version} ..."
	    rm -rf maven_installed
	    curl -o maven.tar.gz ${maven_url}
	fi
else
	echo "Using local Maven installation."
	touch maven_local
fi

# III) Install everything

# III.1) Install Miniconda
if [ -f miniconda_installed ] || [ -f miniconda_local ]; then
    echo "Miniconda3 already installed."
else
    echo "Installing Miniconda3..."

    rm -rf miniconda3
    sh miniconda.sh -b -u -p miniconda3

    cat <<< "${miniconda_update_script}" > fix_conda.py

    PATH=${environment_directory}/miniconda3/bin:$PATH
    python fix_conda.py miniconda3/bin/conda
    python fix_conda.py miniconda3/bin/conda-env
    conda update -y conda

    touch miniconda_installed
fi

# III.2) Create Python environment
if [ -f python_installed ]; then
    echo "Python environment is already set up."
else
    echo "Setting up Python environment ..."

    cat <<< "${python_requirements}" > requirements.txt
    echo "${r_requirements_conda}" >> requirements.txt
    conda config --append channels conda-forge
    conda config --append channels r
    conda create -p venv python=${python_version} --no-default-packages --file requirements.txt -y
    conda config --remove channels conda-forge
    conda config --remove channels r

    touch python_installed
fi

# III.3) Install OpenJDK
if [ -f jdk_installed ] || [ -f jdk_local ]; then
    echo "JDK is already installed."
else
    echo "Installing OpenJDK ${jdk_version} ..."

    mkdir -p jdk
    tar xz -C jdk --strip=1 -f jdk.tar.gz

    touch jdk_installed
fi

# III.4) Install Maven
if [ -f maven_installed ] || [ -f maven_local ]; then
    echo "Maven is already installed."
else
    echo "Installing Maven ${maven_version} ..."

    PATH=${environment_directory}/jdk/bin:$PATH
    JAVA_HOME=${environment_directory}/jdk

    mkdir -p maven
    tar xz -C maven --strip=1 -f maven.tar.gz

    touch maven_installed
fi

# III.4) Extra R packages install
if [ -f r_installed ]; then
    echo "Extra R packages are already installed."
else
	source activate ${environment_directory}/venv
	R_LIB_PATH=$(which conda)
	if [ -f "${R_LIB_PATH%%bin/conda}/lib/R/library/" ]; then
		R_LIB_PATH="${R_LIB_PATH%%bin/conda}/lib/R/library/"
	else
		R_LIB_PATH="${environment_directory}/venv/lib/R/library"
	fi
    echo "Installing additional R dependencies (not available in conda)..."
    Rscript -e "install.packages(c('pacman', 'devtools'), lib='${R_LIB_PATH}', repos='https://cran.rstudio.org')"
    Rscript -e "devtools::install_version('osmdata', version = '0.1.1', lib='${R_LIB_PATH}', repos='https://cran.rstudio.org')"
    Rscript -e "devtools::install_version('dodgr', version = '0.1.3', lib='${R_LIB_PATH}', repos='https://cran.rstudio.org')"
    #Rscript -e "install.packages(c(${r_requirements_cran}), lib='${R_LIB_PATH}', repos='https://cran.rstudio.org')"
	
	conda deactivate
	
    touch r_installed
fi

cd ${origin_directory}