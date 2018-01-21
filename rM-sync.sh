#!/bin/bash

# Sync script for the reMarkable reader
# Version: 0.1
# Author: Simon Schilling
# Licence: MIT

# Additional information:
# This script should be executed on your local machine NOT the reMarkable tablet. The
# script will remoteconnect to the remarkable and copy files over to your local computer.
# The whole backup will take quite a while even via USB-connection.
# 

# Remote configuration (to connect to reMarkable tablet)
RMDIR="/home/root/.local/share/remarkable/xochitl/"
RMUSER="root"
RMIP="10.11.99.1"
SSHPORT="22"

# Local configuration (your paths on your local machine)
# z.B. /Users/jollyjinx/Desktop/remarkable/rM
MAINDIR="/home/simon/rM"
LOG="sync.log"                          # Log file name in $MAINDIR

# Behaviour
NOTIFICATION="/usr/bin/say"     # Notification script (uses Speech output of the Mac)


read -p "Pfad zum Backupverzeichnis (DEFAULT: ${MAINDIR}): " TARGETDIR

if [ ! -d "${TARGETDIR}" ]; then
  echo "FEHLER, Zielverzeichnis für Backup ist fehlerhaft oder existiert nicht!"
  exit
else
  unset MAINDIR
  MAINDIR="${TARGETDIR}"
  echo "OKAY, Zielverzeichnis für Backup ist: ${MAINDIR}"
fi

# Configure target directories
BACKUPDIR="$MAINDIR/backup"             # rotating backups of all rM contents
UPLOADDIR="$MAINDIR/upload"             # all files here will be sent to rM
OUTPUTDIR="$MAINDIR/files"              # PDFs of everything on the rM


LOG="$MAINDIR/$(date +%y%m%d)-$LOG"

echo $'\n' >> $LOG
date >> $LOG


if [ "$RMUSER" ] && [ "$SSHPORT" ]; then
  S="ssh -p ${SSHPORT} -l ${RMUSER}";
fi

# check for rM
$S $RMIP -q exit

if [ $? == "0" ]; then

  TODAY=$(date +%y%m%d)

  # Backup files
  if [ -n "$NOTIFICATION" ]; then
    $NOTIFICATION "Das Backup beginnt."
  fi

  echo "BEGIN BACKUP..."
  echo "BEGIN BACKUP" >> $LOG
  mkdir -p "${BACKUPDIR}/${TODAY}"
  echo "scp \"${RMUSER}@${RMIP}:${RMDIR}\" ${BACKUPDIR}/${TODAY}"  >> $LOG
  scp -r "${RMUSER}@${RMIP}:\"${RMDIR}\"*" "${BACKUPDIR}/${TODAY}" >> $LOG 2>&1
  if [ $? -ne 0 ]; then
    ERRORREASON=$ERRORREASON$'\n scp command failed'
    ERROR=1
    echo $ERRORREASON
  fi
  echo "BACKUP ENDED."
  echo "BACKUP END" >> $LOG



  # Download files
  echo "BEGIN DOWNLOAD..."
  echo "BEGIN DOWNLOAD" >> $LOG
  mkdir -p "${OUTPUTDIR}"
  ls -1 "${BACKUPDIR}/${TODAY}" | sed -e 's/\..*//g' | awk '!a[$0]++' > "${OUTPUTDIR}/index"
  LINECOUNT=`wc -l < "${OUTPUTDIR}/index" | tr -d ' '`
  echo "Downloading ${LINECOUNT} files."
  echo "Downloading ${LINECOUNT} files." >> $LOG
  # http://$RMIP/download/$FILEUID/placeholder
  while read -r line
  do
      FILEUID="$line"
      DOWNLOADURL="http://${RMIP}/download/${FILEUID}/placeholder"
      echo "DOWNLOADING ${DOWNLOADURL} ..."
      curl -s -O -J -L $DOWNLOADURL
      if [ $? -ne 0 ]; then
        ERRORREASON=$ERRORREASON$'\n Download failed'
        ERROR=1
        echo $ERRORREASON
      else
        echo "DOWNLOADED ${FILEUID}."
      fi
  done < "${OUTPUTDIR}/index"
  echo "DOWNLOAD ENDED."
  echo "DOWNLOAD END" >> $LOG


  # Upload files
  echo "BEGIN UPLOAD..."
  echo "BEGIN UPLOAD" >> $LOG
  # TODO
  if [ $? -ne 0 ]; then
    ERRORREASON=$ERRORREASON$'\n Upload failed'
    ERROR=1
  fi
  echo "UPLOAD ENDED."
  echo "UPLOAD END" >> $LOG


else
  echo "reMarkable not connected."
  echo "reMarkable not connected." >> $LOG
  ERRORREASON=$ERRORREASON$'\n reMarkable not connected.'
  ERROR=1
fi
$DATE >> $LOG
if [ -n "$NOTIFICATION" ]; then
  if [ $ERROR ]; then
    echo "ERROR in rM Sync!" "$ERRORREASON"
    $NOTIFICATION "FEHLER bei Backup vom rM Sync!"
  else
    echo "SUCCESS, rM Sync Successful."
    $NOTIFICATION "Backup vom rM Sync erfolgreich abgeschlossen!"
  fi
fi
