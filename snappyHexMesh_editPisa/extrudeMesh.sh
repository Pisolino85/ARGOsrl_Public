#!/bin/bash

###############################################################################
#
#   Script developped in 2019 by
#   CFD FEA SERVICE SRL - via Borgo Grande 19, 37044 Cologna Veneta VR
#
#   License: GPLv3
#
###############################################################################

. /opt/openfoam9/etc/bashrc
. $WM_PROJECT_DIR/bin/tools/RunFunctions

for iext in {1..1}
do
   rm -rf 0
   cp -r system/extrudeMeshDict.$iext system/extrudeMeshDict
   patchname=$(grep exposedPatchName system/extrudeMeshDict | sed  's/exposedPatchName //g' | sed  's/;//g')
   extrudeMesh -region extrusion
   sed -i "s/$patchname/$patchname-temp/g" constant/polyMesh/boundary
   mergeMeshes . . -addRegion extrusion -overwrite
   stitchMesh $patchname $patchname-temp -partial -overwrite
   rm -rf */extrusion
done
