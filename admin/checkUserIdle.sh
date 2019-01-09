#! /bin/bash -x
# $1 is the user to check, $2 is the max idle time in seconds
#debug=echo
debug=
spaceDirectory="/mnt/efs/userSpaces"
lastActiveFile="${spaceDirectory}/.lastActive-${1}"
maxIdle=$2

# get the date in seconds since the epoch
testDate=`date +%s`
numActiveProcs=`pgrep -u $1 | wc -l`
if (( $numActiveProcs > 0 )); then
   # The user has active processes, save the date to the lastActiveFile and exit
   echo $testDate > $lastActiveFile
   exit 0
fi 

# Now the user has no active processes
# Is there a lastActiveFile?
if [ ! -f $lastActiveFile ]; then
   # No file, we will create it
   echo $testDate > $lastActiveFile
   exit 0
else
   # the file is there, have they exceeded max idle
   lastActiveDate=`cat $lastActiveFile`
   idleTime=$(($testDate-$lastActiveDate))
   echo $idleTime
 
   if (( $idleTime > $maxIdle )); then
     echo "resource is idle"
     /bin/rm $lastActiveFile
   fi
fi
