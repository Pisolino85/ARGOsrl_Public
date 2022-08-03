#!/bin/bash
cd ${0%/*} || exit 1    # Run from this directory

# Source tutorial run functions
source /opt/openfoam9/etc/bashrc
. $WM_PROJECT_DIR/bin/tools/RunFunctions

#in case it is a restart
runApplication reconstructPar 

# Cleaning
rm -r processor*

# remove log files
rm log.*

#AUTOMATIC NCPU FINDER
nvCPU="$(grep -c ^processor /proc/cpuinfo)"   #count cpu number
nThrd="$(lscpu | grep Thread | sed 's/Thread(s) per core://g' | sed 's/ //g')"  #grep the number of threads per cpu
nProc=$(( $nvCPU / $nThrd ))  #use only phisical cores

echo "Detected $nvCPU vCPU with $nThrd threads each. Using $nProc physical CPU only."

#set number of proc for meshing
sed -i "/numberOfSubdomains/c\numberOfSubdomains $nProc;" system/decomposeParDict

runApplication decomposePar

runParallel $(getApplication)


runApplication reconstructPar 

# CALCULATE YPLUS 
mv log.SimpleFoam log.SimpleFoam_solving
runApplication $(getApplication) -postProcess -func yPlus
mv log.SimpleFoam log.SimpleFoam_yPlus

#------------------------------------------------------------------------------
