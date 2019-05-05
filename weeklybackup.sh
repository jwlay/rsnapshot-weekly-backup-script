#!/bin/bash

LOGFILE="~/rsnap_out"
FILESYSTEM="/dev/sda1"
DRIVE="/dev/sda"
FOLDER="/mnt/backup"

BACKUPSERVERNAME=""
SERVERNAME=""

# MAIL Setup
FROM=""
TO=""
MAILFILE="~/weeklybackupMAIL"

SECONDS=0
STARTDATE=`date +%Y-%m-%d`

echo `date` - "Backup is starting" > $LOGFILE

if grep -qs '$FILESYSTEM' /proc/mounts; then
	echo `date` - "Backup drive $FILESYSTEM already mounted, do nothing" >> $LOGFILE
else
	echo `date` - "Mounting Backup drive $FILESYSTEM " >> $LOGFILE
	sudo mount "$FILESYSTEM" /mnt/backup
	if [ $? -eq -0 ]; then
		echo `date` - "Backup drive $FILESYTEM successfully mounted" >> $LOGFILE
	else
		echo `date` - "Could not mount filesystem $FILESYSTEM " >> $LOGFILE
		echo `date` - "Can not start backups" >> $LOGFILE
		echo `date` - "FATAL ERROR" >> $LOGFILE
		echo "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
		<html>
		<header>
		<title>FATAL ERROR: Backup on $BACKUPSERVERNAME failed</title>
		</header>
		<body>
		<h1>Backup on $BACKUPSERVERNAME failed</h1>
		<p>Weekly Backup of $SERVERNAME on $BACKUPSERVERNAME has failed at `date`</p>
		<h3>Here is the log:</h3>" > $MAILFILE
		echo " `sed 's|^|<br />|' $LOGFILE ` " >> $MAILFILE
 mail \
 -a "FROM: $FROM" \
 -a "MIME-Version: 1.0" \
 -a "Content-Type: text/html" \
 -s "FATAL ERROR: Weekly backup on $BACKUPSERVERNAME could not complete" \
 $TO < $MAILFILE
		exit
	fi
fi

DISKUSE1="`du -sh $FOLDER `"

echo `date` - " Starting Weekly Snapshot" >> $LOGFILE
# Run Weekly Snapshot
rsnapshot -c /etc/rsnapshot.conf weekly >> $LOGFILE

echo `date` - "Weekly Snapshot completed" >> $LOGFILE

# Check for Monthly Snapshot
if [ `date +%d` -lt 7 ] ; then
	echo `date` - "First sunday of the month, starting monthly snapshot" >> $LOGFILE
	rsnapshot -c /etc/rsnapshot.conf monthly >> $LOGFILE
	echo `date` - "Monthly Snapshot completed" >> $LOGFILE
else echo `date` - "Monthly Snapshot is not necessary today, skipping ..." >> $LOGFILE
fi

DISKUSE="`df | sed 's|^|<br />|'` "
DISKUSE2="`du -sh $FOLDER `"

# Unmount and put drive to sleep
sync
sudo umount "$FILESYSTEM"
echo `date` - "Filesystem $FILESYSTEM unmounted" >> $LOGFILE
sudo hdparm -Y "$DRIVE"
echo `date` - "Drive $DRIVE has been put to sleep" >> $LOGFILE

RSNAPLOG="`cat /var/log/rsnapshot/rsnapshot.log  | sed -ne "/\[$STARTDATE/p"`"
duration=$SECONDS

echo "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
<html>
<header>
<title>Backup on $BACKUPSERVERNAME completed at `date` </title>
</header>
<body>
<h1>Backup on $BACKUPSERVERNAME completed</h1>
<p>Weekly Backup of $SERVERNAME on $BACKUPSERVERNAME has been completed at `date` </p>
<p>It took $(($duration / 3600)) hours, $(($duration % 3600 / 60)) minutes and $(($duration % 60)) seconds to complete the backup</h2><br>
<h3>Disk usage on $FILESYSTEM was:</h3>
<p> $DISKUSE1 </p>
<h3>Disk usage is now:</h3>
<p> $DISKUSE2 </p>
<h3>Here is the log:</h3> " > $MAILFILE
echo " `sed 's|^|<br />|' $LOGFILE ` " >> $MAILFILE
echo "<h3> Rsnapshot Log: </h3> " >> $MAILFILE
echo " `sed 's|^|<br />|' $RSNAPLOG `" >> $MAILFILE
echo "<h3>Disk Usage:</h3> $DISKUSE " >> $MAILFILE
echo "
</body>
</html>" >> $MAILFILE 

 mail \
 -a "FROM: $FROM" \
 -a "MIME-Version: 1.0" \
 -a "Content-Type: text/html" \
 -s "Weekly backup on $BACKUPSERVERNAME completed" \
 $TO < $MAILFILE
