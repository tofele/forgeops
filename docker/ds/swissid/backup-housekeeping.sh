#!/bin/bash
if [ -z "$1" ] ; then
    echo backupLocation not defined, quitting...
	exit 1
fi

if [ -z "$2" ] ; then
    echo backup age not defined, quitting...
	exit 1
fi

backupLocation=$1
backupFileAge=$2

for backupType in userRoot schema tasks
do
  echo "`date`: backupType is : $backupType" >> ${backupLocation}/$backupType/backup-housekeeping.log

  #TO DO: Increase backup file age from 2 days to 14 days
  #Identify files to delete
  find ${backupLocation}/$backupType -type f -mtime +$backupFileAge > ${backupLocation}/$backupType/backup_files-to-delete

  #Prepare backup IDs to remove sections the backup.info files
  #Note: sed used with " and @ instead of ' and / . This allows for variable substitution (${backupLocation}) inside the expressions
  # Added -e "/.*\/$backupType\/backup.info.*/d" for SES-2042
  sed -e "s@${backupLocation}\/$backupType\/backup-$backupType-@@g" -e "/.*\/$backupType\/backup.info.*/d" ${backupLocation}/$backupType/backup_files-to-delete > ${backupLocation}/$backupType/backup_ids-to-delete

  #Make a backup copy of backup.info files with timestamps .. Note that the backup.info.<date> files will also be deleted automatically after N days along with the backup files
  cp ${backupLocation}/$backupType/backup.{info,info."$(date  +%Y-%m-%d-%HH-%MM-%SS)"}

  #Now remove backup Id sections (group of lines related to each backup Ids to be deleted) from backup.info file
  while IFS='' read -r line || [[ -n "$line" ]]; do
    echo "Cleaning entries for backup Id: $line" >> ${backupLocation}/$backupType/backup-housekeeping.log
    sed -i "/backup_id=$line/,/^ *$/d" ${backupLocation}/$backupType/backup.info
  done < ${backupLocation}/$backupType/backup_ids-to-delete

  #Now remove backup files
  while IFS='' read -r line || [[ -n "$line" ]]; do
    echo "Deleting backup file: $line" >> ${backupLocation}/$backupType/backup-housekeeping.log
    rm $line
  done < ${backupLocation}/$backupType/backup_files-to-delete
done
