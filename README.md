# SynoShutdownAfterHyperBackup

This scripts automatically shuts down a Synology NAS after a list of HyperBackup jobs have successfully completed.

#### 1. Notes

- All HyperBackup jobs need to start after midnight on the same day.
- It only works with jobs that run daily.
- There is no easy way on the backup NAS to determine the frequency of backups jobs nor their exact configuration (some details in `/usr/syno/etc/synobackup_server.conf`)
- Script simply checks if all started jobs per user finished on the same day, so you need to pass the username HyperBackup uses plus the number of jobs configured (e. g. "myserver:1").
- So it makes kind of sense to configure a separate user for each job.
- The script will send warning messages if the jobs are not completed by 23:00.
- If the NAS is booted manually after 06:00 the script will ***not*** shut it down to allow for maintenance/administration/other tasks.
- The script is able to automatically update itself using `git`.

#### 2. Installation

##### 2.1 Install Git (optional)

- install the package `Git Server` on your Synology NAS, make sure it is running (requires sometimes extra action in `Package Center` and `SSH` running)
- alternatively add SynoCommunity to `Package Center` and install the `Git` package ([https://synocommunity.com/](https://synocommunity.com/#easy-install))
- you can also use `entware` (<https://github.com/Entware/Entware>)

##### 2.2 Install this script (using git)

- create a shared folder e. g. `sysadmin` (you want to restrict access to administrators and hide it in the network)
- connect via `ssh` to the NAS and execute the following commands

```bash
# navigate to the shared folder
cd /volume1/sysadmin
# clone the following repo
git clone https://github.com/alexanderharm/syno-shutdown-after-hyper-backup
# to enable autoupdate
touch syno-shutdown-after-hyper-backup/autoupdate
```

##### 2.3 Install this script (manually)

- create a shared folder e. g. `sysadmin` (you want to restrict access to administrators and hide it in the network)
- copy your `synoShutdownAfterHyperBackup.sh` to `sysadmin` using e. g. `File Station` or `scp`
- make the script executable by connecting via `ssh` to the NAS and executing the following command

```bash
chmod 755 /volume1/sysadmin/synoShutdownAfterHyperBackup.sh
```

#### 3. Usage:

- create a new task in the `Task Scheduler`

```
# Type
Scheduled task > User-defined script

# General
Task:    synoShutdownAfterHyperBackup
User:    root
Enabled: yes

# Schedule
Run on the following days: Daily
First run time:            (01:00 or the full hour after the backup jobs start)
Frequency:                 Every 30 minute(s)
Last run time:				23:30

# Task Settings
Send run details by email:      yes
Email:                          (enter the appropriate address)
Send run details only when
  script terminates abnormally: yes
  
User-defined script: /volume1/sysadmin/syno-shutdown-after-hyper-backup/synoShutdownAfterHyperBackup.sh "<username1>:<numberOfJobs1>" "<username2>:<numberOfJobs2>"
```
