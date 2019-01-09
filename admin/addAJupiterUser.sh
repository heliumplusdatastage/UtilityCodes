#! /bin/bash
# $1 is the user to add; $2 and $3 are the user and group ids
#debug=echo
debug=
$debug /sbin/adduser $1
$debug usermod -u $2 $1
$debug groupmod -g $3 $1
exit
$debug usermod -s /sbin/nologin $1
spaceDirectory="/mnt/efs/userSpaces"
userDirectory="${spaceDirectory}/${1}_space"
$debug mkdir $userDirectory
$debug chmod 700 $userDirectory
$debug chown $1:$1 $userDirectory

