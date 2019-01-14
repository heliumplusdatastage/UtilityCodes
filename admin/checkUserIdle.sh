#! /bin/bash -x
# $1 is the user to check, $2 is the max idle time in seconds, $3 is the minimum amount of CPU
# utilization to be considered active
#debug=echo
debug=
spaceDirectory="/home/efs/userSpaces"
lastActiveFile="${spaceDirectory}/.lastActive-${1}"
theUser=$1
maxIdle=$2
minActiveCPU=$3

# Set the field seperator
IFS=$'\n'

# get the date in seconds since the epoch
testDate=`date +%s`

# get an array of all process for the specified user. The first two grep -v commands eliminate pam 
# processes and the last one eliminates the jupterhub process.
processList=( $(/usr/bin/pgrep -a -u ${theUser} | /bin/grep -v pam | /bin/grep -v systemd | /bin/grep -v jupyterhub-singleuser) )
numActiveProcs="${#processList[@]}"

if (( $numActiveProcs < 1 )); then
   # The user has no active processes
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
   totalCPU=$(echo "$totalCPU + $thisCPUUsage"|/usr/bin/bc)
done

userActive=$(echo "$totalCPU > $minActiveCPU"|/usr/bin/bc)
if [ $userActive !=  0 ]; then
   # The user is active. 
   echo $testDate > $lastActiveFile
else
   # The user is not active  
   # Is there a lastActiveFile?
   if [ ! -f $lastActiveFile ]; then
      # No file, we will create it.  Since the file was not there, we are assuming
      # this is the first time we have run this script since the last time the user
      # was determined to be inactive. So we aren't going to turn off the machine
      echo $testDate > $lastActiveFile
   else
      # the file is there, have they exceeded max idle
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
fi
