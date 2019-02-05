#! /bin/bash -x
# $1 is the user to check, $2 is the max idle time in seconds, $3 is the minimum amount of CPU
# utilization to be considered active
#debug=echo
debug=
spaceDirectory="/home/efs/userSpaces"
lastActiveFile="${spaceDirectory}/.lastActive-${1}"
userHome="${spaceDirectory}/${1}_space"
theUser=$1
maxIdle=$2
minActiveCPU=$3

# Set the field seperator
IFS=$'\n'

# get the date in seconds since the epoch
testDate=`date +%s`

# Is there a lastActiveFile?
if [ ! -f $lastActiveFile ]; then
   # No file, we will create it and exit on the theory that this is either the
   # the first check since the last restart or the first check overall.  In neither
   # of those cases do we want to stop the instance. So we can exit here.  
   echo $testDate > $lastActiveFile
   exit 0
fi

# We are going to check both file and CPU activity as measures of idleness.  Anytime we detect the user
# not being idle, we want to be sure that the timestamp in the lastActiveFile is updated.

# Check for the date of the last file modification
lastFileTime=( $(find $userHome -type f -printf '%T@ %p\n' | sort -n | tail -1 | awk {'print $1}'))
lastIntFileTime=${lastFileTime%.*}
echo $lastIntFileTime
echo $testDate
lastActiveDate=`cat $lastActiveFile`
timeSinceLastFile=$(echo "$testDate - $lastIntFileTime"|/usr/bin/bc)
echo $timeSinceLastFile

# Is the time since the last file update less than the maxIdle time.  If so the user is active
userActive=$(echo "$timeSinceLastFile > $maxIdle"|/usr/bin/bc)
if [ $userActive !=  0 ]; then
   # The user is active. We can just reset the last active date to the lastIntFileTime and exit
   echo $lastIntFileTime > $lastActiveFile
   exit
fi

# They were't active from the file system point of view, but they may yet be active from the CPU
# point of view.  We check that next.

# get an array of all process for the specified user. The first two grep -v commands eliminate pam 
# processes and the last one eliminates the jupterhub process.
processList=( $(/usr/bin/pgrep -a -u ${theUser} | /bin/grep -v pam | /bin/grep -v systemd | /bin/grep -v jupyterhub-singleuser) )
numActiveProcs="${#processList[@]}"

if (( $numActiveProcs < 1 )); then
   # The user has no active processes, have they exceeded max idle
   lastActiveDate=`cat $lastActiveFile`
   idleTime=$(($testDate-$lastActiveDate))
   echo $idleTime
  
   if (( $idleTime > $maxIdle )); then
     echo "resource is idle"
     /bin/rm $lastActiveFile
   fi
   # Stop the instance
   exit 0
fi

# Next step: how much CPU is being used. Find the CPU utilization of each user process
# and sum it up.  If the sum is less than the minActiveCPU, the user is idle. Otherwise
# we update the lastActiveFile
totalCPU=0.0

# For each process, get it's pid, then find how much cpu it's using
for i in "${processList[@]}";
do 
   thisPid=`/bin/echo "$i" | /usr/bin/awk '{print $1}'`
   thisCPUUsage=`/usr/bin/top -b -n 1 -p $thisPid | /bin/grep $thisPid | /usr/bin/awk '{print $9}'`
   if [ -z "$thisCPUUsage" ]; then
      thisCPUUsage=0.0
   fi
   totalCPU=$(echo "$totalCPU + $thisCPUUsage"|/usr/bin/bc)
done

userActive=$(echo "$totalCPU > $minActiveCPU"|/usr/bin/bc)
if [ $userActive !=  0 ]; then
   # The user is active. 
   echo $testDate > $lastActiveFile
else
   # The user is not active have they exceeded max idle?
   lastActiveDate=`cat $lastActiveFile`
   idleTime=$(($testDate-$lastActiveDate))
   echo $idleTime

   if (( $idleTime > $maxIdle )); then
     echo "resource is idle"

     # the resource is going to be shut down.  We remove the lastActiveFile so
     # the resource doesn't get immediately shut down the next time we run the script.
     /bin/rm $lastActiveFile

     # Here's where we issue the call to stop the resource.
   fi
fi

