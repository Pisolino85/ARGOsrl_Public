#!/bin/bash
cd ${0%/*} || exit 1    # Run from this directory

# Source tutorial run functions
source /opt/openfoam9/etc/bashrc
. $WM_PROJECT_DIR/bin/tools/RunFunctions

#check if it is new run or a restart
DIR="0/"
if [ -d "$DIR" ]; then
  ### Take action if $DIR exists ###
  echo "Restart case..."
  runApplication reconstructPar 

  # Cleaning
  rm -r processor*

  # remove log files
  rm log.*
  
else
  ###  Control will jump here if $DIR does NOT exists ###
  echo "New case, copying 0.org"
  cp -r 0.org 0
fi


#MESH IMPORT

meshFolder=$( xmllint  --xpath "string(//INPUTDATA/meshFolder)" CFD_input.xml )

#se esiste copio la cartella polyMesh in questa cartella constant
if [ -z "$meshFolder" ]
then
  echo "Utilizzo la mesh presente nella cartella"
else
  meshFolder="$meshFolder/constant/polyMesh"
  
  #elimino la mesh presente
  rm -r constant/polyMesh
  
  #copio la mesh desiderata
  cp -R $meshFolder constant/
  echo "$meshFolder copiato nella cartella constant"
fi


#AUTOMATIC NCPU FINDER
nvCPU="$(grep -c ^processor /proc/cpuinfo)"   #count cpu number
nThrd="$(lscpu | grep Thread | sed 's/Thread(s) per core://g' | sed 's/ //g')"  #grep the number of threads per cpu
nProc=$(( $nvCPU / $nThrd ))  #use only phisical cores

echo "Detected $nvCPU vCPU with $nThrd threads each. Using $nProc physical CPU only."

#set number of proc for meshing
sed -i "/numberOfSubdomains/c\numberOfSubdomains $nProc;" system/decomposeParDict

#SET SIMULATION PARAMETERS

Niter=$( xmllint  --xpath "string(//INPUTDATA/Niter)" CFD_input.xml )

foamDictionary system/controlDict -entry endTime  -set $Niter



runApplication decomposePar

runParallel $(getApplication)


runApplication reconstructPar 

# elimina le cartelle processori una volta ricostruito
rm -r processor*

# CALCULATE YPLUS 
mv log.rhoSimpleFoam log.rhoSimpleFoam_solving
cp -r 0 .0
runApplication $(getApplication) -postProcess -func yPlus
mv log.rhoSimpleFoam log.rhoSimpleFoam_yPlus


# POSTPROCESSING OF OUTPUT FLOWS
# cerco tutte le boundary che hanno 'out' nel nome (es. outlet_1) e estrapolo le portate per ognuna
grep out constant/polyMesh/boundary | while read -r line ; do

    echo "postProcessing $line"    
    postString="postProcess -func 'patchIntegrate(name= $line , U , patch = $line)' > log.postProcess_$line "
    eval $postString
    
done

# POSTPROCESSING OF INPUT PRESSURE
grep inlet constant/polyMesh/boundary | while read -r line ; do

    echo "postProcessing $line"    
    postString="postProcess -func 'patchIntegrate(name= $line , p , patch = $line)' > log.postProcess_$line "
    eval $postString
    
done

# SALVA CONTENUTO NELLA CARTELLA RISULTATI SE SIAMO IN LOCALE

if [ $(xmllint  --xpath "string(//INPUTDATA/online)" CFD_input.xml) -eq 0 ]
then
  caseName=$(xmllint  --xpath "string(//INPUTDATA/caseName)" CFD_input.xml)
  
  #esco dalla cartella attuale
  saveName=$(dirname $PWD)
  saveName="$saveName/RISULTATI"
  # controllo se esiste la directory RISULTATI, se non esiste la creo
  [ -d $saveName ] || mkdir $saveName
  
  #nome specifico del risultato generato
  saveName="$saveName/$caseName"
  
  #copio la cartella con il tag del risultato
  cp -R $PWD $saveName
  
  echo "Saved in $saveName"
  
  rm -r 0
  cp -r .0 0
  rm -r .0
fi




#------------------------------------------------------------------------------
