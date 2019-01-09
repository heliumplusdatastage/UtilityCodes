#!/bin/sh
# This script is going to execute a command that looks like this
# tar xvf COPDgene_batch_12/COPDGene_Z99527_COPDGene_Z99527.tar -C /mnt/efs/copdgene/COPDgene_batch_12
# for every tar file
# It's only going to work from the /copdgene dir, but it should only be executed once so thats ok

echo Processing directory $1
# Get the list of tar files
FILELIST=COPD*$1/*.tar
for thisFile in $FILELIST 
do
   # we need the basedir for the -C part of the tar command
#  echo $thisFile
   dirName="$(dirname $thisFile)"
#  echo $dirName
   thisCommand='tar xf  '$thisFile' -C /mnt/efs-new/copdgene/'$dirName
   echo $thisCommand
   eval $thisCommand
done
