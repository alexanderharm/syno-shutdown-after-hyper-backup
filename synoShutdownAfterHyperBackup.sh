#!/bin/bash

# check if run as root
if [ $(id -u "$(whoami)") -ne 0 ]; then
	echo "SynoShutdownAfterHyperBackup needs to run as root!"
	exit 1
fi

# check if git is available
if command -v /usr/bin/git > /dev/null; then
	git="/usr/bin/git"
elif command -v /usr/local/git/bin/git > /dev/null; then
	git="/usr/local/git/bin/git"
elif command -v /opt/bin/git > /dev/null; then
	git="/opt/bin/git"
else
	echo "Git not found therefore no autoupdate. Please install the official package \"Git Server\", SynoCommunity's \"git\" or Entware's."
	git=""
fi

# save today's date
today=$(date +'%Y/%m/%d')
todayBoot=$(date +'%Y-%m-%d')

# check if there was a boot since 06H00
# this prevents that the machine shuts down if it is booted manually
if grep -q "^${todayBoot}T\\(\\(0[6-9]\\)\\|\\([1-2][0-9]\\)\\).*\\[synoboot\\].*$" /var/log/kern.log; then
	echo "Terminating script because Synology was manually booted." 
	exit 0
fi

# check for arguments
if [ -z $1 ]; then
	echo "No user and jobs passed to SynoShutdownAfterHyperBackup!"
	exit 1
else
	echo "This was passed: $*."
	backupJobs=( "$@" )
fi

# self update run once daily
if [ ! -z "${git}" ] && [ -d "$(dirname "$0")/.git" ] && [ -f "$(dirname "$0")/autoupdate" ]; then
	if [ ! -f /tmp/.synoShutdownAfterHyperBackupUpdate ] || [ "${today}" != "$(date -r /tmp/.synoShutdownAfterHyperBackupUpdate +'%Y-%m-%d')" ]; then
		echo "Checking for updates..."
		# touch file to indicate update has run once
		touch /tmp/.synoShutdownAfterHyperBackupUpdate
		# change dir and update via git
		cd "$(dirname "$0")" || exit 1
		$git fetch
		commits=$($git rev-list HEAD...origin/master --count)
		if [ $commits -gt 0 ]; then
			echo "Found a new version, updating..."
			$git pull --force
			echo "Executing new version..."
			exec "$(pwd -P)/synoShutdownAfterHyperBackup.sh" "$@"
			# In case executing new fails
			echo "Executing new version failed."
			exit 1
		fi
		echo "No updates available."
	else
		echo "Already checked for updates today."
	fi
fi

# define some vars
finishedJobs=0
numberOfJobs=${#backupJobs[@]}

# check logs for success message (apparently twice)
for (( i=0; i<numberOfJobs; i++ )); do
	username="$(echo ${backupJobs[$i]} | cut -d ':' -f 1)"
	jobNumber="$(echo ${backupJobs[$i]} | cut -d ':' -f 2)"
	matches=$(grep -Eo "info\s${today}\s[0-9:]{8}\s${username}:.+Backup complete.$" /var/log/synolog/synobackup_server.log | wc -l)
	if [ $matches -eq $jobNumber ]; then
		((finishedJobs++))
	fi
done

# check logs for success message
if [ $numberOfJobs -eq $finishedJobs ]; then
	echo "All backups have finished." 
	shutdown -h +5 "System going down in 5 minutes."
	exit 0
else
	# produce error message if not finished by 23H00
	if [ $(date +%H) -eq 23 ]; then
		echo "Only ${finishedJobs} of ${numberOfJobs} HyperBackup jobs have finished by $(date +%H:%M)."
		exit 2
	else
		echo "${finishedJobs} of ${numberOfJobs} HyperBackup jobs have finished."
		exit 0
	fi
fi