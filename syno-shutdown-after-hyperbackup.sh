#!/bin/bash

# check if run as root
if [ $(id -u "$(whoami)") -ne 0 ]; then
	echo "SynoShutdownAfterHyperBackup needs to run as root!"
	exit 1
fi

# check if git is available
if ! which git > /dev/null; then
	echo "Git not found. Please install the package \"Git Server\"."
	exit 1
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
	echo "No number of tasks passed to SynoShutdownAfterHyperBackup!"
	exit 1
else
	echo "This number of tasks was passed: ${1}."
	nrTasks=$1
fi

# self update run once daily
if [ ! -f /tmp/.synoShutdownAfterHyperBackupUpdate ] || [ "${today}" != "$(date -r /tmp/.synoShutdownAfterHyperBackupUpdate +'%Y/%m/%d')" ]; then
	echo "Checking for updates..."
	# touch file to indicate update has run once
	touch /tmp/.synoShutdownAfterHyperBackupUpdate
	# change dir and update via git
	cd "$(dirname "$0")" || exit 1
	git fetch
	commits=$(git rev-list HEAD...origin/master --count)
	if [ $commits -gt 0 ]; then
		echo "Found a new version, updating..."
		git pull --force
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

# check logs for success message
tasksStarted=$(grep -Eo "info\s+"${today}".+backup.+Backup started.$" /var/log/synolog/synobackup_server.log | wc -l)
tasksFinished=$(grep -Eo "info\s+"${today}".+backup.+Backup complete.$" /var/log/synolog/synobackup_server.log | wc -l)
if [ $tasksStarted -eq $tasksFinished ]; then
	if [ $nrTasks -eq $tasksFinished ]; then
		echo "All backups have finished." 
		shutdown -h +5 "System going down in 5 minutes."
	else
		echo "Number of tasks (${nrTasks}) passed does not equal number of backup jobs ${tasksFinished}!"
		exit 1
	fi
else
	# produce error message if not finished by 23H00
	if [ $(date +%H) -eq 23 ]; then
		echo "Only ${tasksFinished} of ${nrTasks} HyperBackup jobs have finished by $(date +%H:%M)."
		exit 2
	else
		echo "${tasksFinished} of ${nrTasks} HyperBackup jobs have finished."
		exit 0
	fi
fi