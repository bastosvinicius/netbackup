#!/bin/sh
# Author: Vinicius Bastos
# Date: 09/02/2017
# Desc.: Automate netbackup sync
# Script: netbackup.sh
# Version: 0.0.1
# List of return codes:
# RC = 1 - You are not running the script with root user
# RC = 2 - Logs directory cannot be created
# RC = 3 - Cannot create execution log directory
# RC = 4 - File tape_list does not exist
# RC = 5 - File tape_list has no content
# RC = 6
# RC = 7
# Obs.: Create RC for all process

# DECLARE VARIABLES

HM="/home/<HOME>/scripts/netbackup"
DT=$(date +%d%m%y"_"%H%M%S)
LD="$HM/logs/NB_$(date +%d%m%y)"
LDINDEX="$LD/INDEX"
LDIMPORT="$LD/IMPORT"
AUXINDEXOK="$LDINDEX/AUXINDEXOK_$(date +%d%m%y)"
AUXINDEXNOK="$LDINDEX/AUXINDEXNOK_$(date +%d%m%y)"
AUXIMPORTOK="$LDIMPORT/AUXIMPORTOK_$(date +%d%m%y)"
AUXIMPORTNOK="$LDIMPORT/AUXIMPORTNOK_$(date +%d%m%y)"
HOTPROCESS="$LDINDEX/HOTPROCESS_$(date +%d%m%y"_"%H%M%S)"
SUCCTAPE="$LDIMPORT/SUCCTAPE_$(date +%d%m%y"_"%H%M%S)"
ERRORTAPE="$LDIMPORT/ERRORTAPE_$(date +%d%m%y"_"%H%M%S)"
LL=$(ls $HM/logs)
RC=0

# START SCRIPT

# CHECK IF RUNNING WITH ROOT USER

if [ "$(id -u)" -eq "0" ]
then
	echo "Running script with root user"
else
	echo "Please run this script with root user, exiting..."
	RC=1
	exit "$RC"
fi

# CLEAN LOG DIRECTORY FROM YESTERDAY'S PROCESSING IF IT EXISTS

if [ "$(ls $HM/logs | wc -l)" -ne 0 ]
	then
	rm -rf "$HM"/logs/*
	if [ "$?" -eq 0 ]
		then
		echo "Removing $LL file"
		echo "$LL directory removed successfuly"
	else
		echo "Fail to remove $LL directory"
	fi
else
	echo "No old directory to remove in $HM/logs"
fi

# CHECKING IF FILE OF TAPES EXISTS AND HAS CONTENT

if [ -e "$HM"/tape_list ]
then
	echo "File $HM/tape_list exists"
else
	echo "File $HM/tape_list does not exist"
	echo "Please create it"
	RC=2
	exit "$RC"
fi

if [ "$(cat $HM/tape_list | wc -l)" -gt "0" ]
then
	echo "File tape_list has $(cat "$HM"/tape_list | wc -l) tapes"
	echo "List of tapes: \n"
	echo "$(cat "$HM"/tape_list) \n"
else
	echo "File $HM/tape_list is empty, please verify..."
	RC=3
	exit "$RC"
fi

# CHECK IF DIRS EXISTS

if [ -e "$HM"/logs ]
then
	echo "Logs directory $HM/logs already exists"
else
	echo "Creating directory logs $HM"
	mkdir "$HM"/logs
	if [ "$?" -eq 0 ]
	then
		echo "Directory $HM/logs created successfuly"
	else
		echo "Cannot create $HM/logs, please verify, exiting..."
		RC=2
		exit "$RC"
	fi
fi

if [ -e "$LD" ]
then
	echo "Execution log directory $LD already exist"
else
	echo "Creating execution log directory $LD"
	mkdir "$LD"
	if [ "$?" -eq 0 ]
	then
		echo "Directory $LD created successfuly"
	else
		eccho "Cannot create $LD, please verify, exiting..."
		RC=3
		exit "$RC"
	fi
fi

if [ -e "$LDINDEX" ]
then
	echo "Execution log directory $LDINDEX already exist"
else
	echo "Creating execution log directory $LDINDEX"
	mkdir "$LDINDEX"
	if [ "$?" -eq 0 ]
	then
		echo "Directory $LDINDEX created successfuly"
	else
		eccho "Cannot create $LDINDEX, please verify, exiting..."
		RC=4
		exit "$RC"
	fi
fi

if [ -e "$LDIMPORT" ]
then
	echo "Execution log directory $LDIMPORT already exist"
else
	echo "Creating execution log directory $LDIMPORT"
	mkdir "$LDIMPORT"
	if [ "$?" -eq 0 ]
	then
		echo "Directory $LDIMPORT created successfuly"
	else
		eccho "Cannot create $LDIMPORT, please verify, exiting..."
		RC=5
		exit "$RC"
	fi
fi

# STEP 1

# CREATING LIST OF TAPE WITH SUCCESS RUN FOR BPIMPORT - CREATE INDEX

PROC_TABLE_INDEX="PROC_TABLE_INDEX_"$(date +%d%m%y)

BPIMPORTINDEX () {
	LOGT=$(date +%d%m%y"_"%H%M%S)
	echo "Starting index creation for tape $TAPE"
	#bpimport -create_db_info -id "$TAPE" -L "$LDINDEX"/"INDEX_CREATE_""$TAPE""_""$LOGT" &
	sleep $TAPE >> "$LDINDEX"/"INDEX_CREATE_""$TAPE""_""$LOGT" &
	echo $!" ""$TAPE"" ""INDEX_CREATE_""$TAPE""_""$LOGT" >> "$LDINDEX"/"$PROC_TABLE_INDEX"
	}
	PIDS=""
echo
echo "Starting netbackup index creation $(date +%d"/"%m"/"%y" "%T)"
echo
while read TAPE 
do
	BPIMPORTINDEX
	# GENERATING PID LIST
	PIDS=$PIDS" $!"
	sleep 1
done < "$HM"/tape_list

# CHECKING IF BPIMPORT COMMAND FOR INDEX CREATION IS STILL RUNNING

echo
echo "Checking if cmd still running $(date +%d"/"%m"/"%y" "%T)"
echo

CMDCHK () {
for PID in $PIDS
do
	if wait $PID; then
		echo "Process $PID are finished with SUCCESS"
		echo "Inserting PID $PID in control file $AUXINDEXOK"
		echo "$PID" >> "$AUXINDEXOK"
	else
		echo "Process $PID are finished with ERROR"
		echo "Inserting PID $PID in control file $AUXINDEXNOK"
		echo "$PID" >> "$AUXINDEXNOK"
	fi
done
}
CMDCHK

# GENERATING LIST FOR HOTPROCESS
# THIS LIST WILL SERVE OF BASE TO EXECUTION FOR HOT PROCESS IN NETBACKUP - PROTECTIER DEDUPLICATION GATEWAY - DR

echo
echo "Generating list for hotprocess $(date +%d"/"%m"/"%y" "%T)"
echo

if [ -e "$AUXINDEXOK" ]
	then
	while read PID TAPE LOGFILE
	do
		cat "$AUXINDEXOK" | grep -w $PID
		if [ $? -eq "0" ]
			then
			cat "$AUXINDEXOK" | grep -w "$PID" | head -n1 | echo "$TAPE" >> "$HOTPROCESS"
			echo "Tape $TAPE will be processed"
		fi
	done < "$LDINDEX"/"$PROC_TABLE_INDEX"
else
	echo "File AUXINDEXOK does not exists"
	if [ -e "$AUXINDEXNOK" ]
		then
		echo "Tapes with problem: \n"
		cat "$AUXINDEXNOK"
	fi
fi

# STEP 2

# BURNING LIST HOTPROCESS OF TAPE WITH SUCCESS RUN FOR BPIMPORT

PROC_TABLE_IMPORT="PROC_TABLE_IMPORT_"$(date +%d%m%y)

echo
echo "Starting hotprocess list $(date +%d"/"%m"/"%y" "%T)"
echo
echo "File HOTPROCESS has $(cat "$HOTPROCESS" | wc -l) tapes"
echo "List of tapes: \n"
echo "$(cat "$HOTPROCESS")"

BPIMPORT () {
	LOGT=$(date +%d%m%y"_"%H%M%S)
	echo "Starting import for tape $TAPE"
	#bpimport -id "$TAPE" -L "$LDIMPORT"/"IMPORT_""$TAPE""_""$LOGT" &
	sleep $TAPE >> "$LDIMPORT"/"IMPORT_""$TAPE""_""$LOGT" &
	echo $!" ""$TAPE"" ""IMPORT_""$TAPE""_""$LOGT" >> "$LDIMPORT"/"$PROC_TABLE_IMPORT"
	}
	PIDS=""
echo
echo "Starting netbackup import $(date +%d"/"%m"/"%y" "%T)"
echo
while read TAPE 
do
	BPIMPORT
	# GENERATING PID LIST
	PIDS=$PIDS" $!"
	sleep 1
done < "$HOTPROCESS"

## CHECKING IF BPIMPORT COMMAND FOR IMPORT IS STILL RUNNING

echo
echo "Checking if cmd still running $(date +%d"/"%m"/"%y" "%T)"
echo

CMDCHK () {
for PID in $PIDS
do
	if wait $PID; then
		echo "Process $PID are finished with SUCCESS"
		echo "Inserting PID $PID in control file $AUXIMPORTOK"
		echo "$PID" >> "$AUXIMPORTOK"
	else
		echo "Process $PID are finished with ERROR"
		echo "Inserting PID $PID in control file $AUXIMPORTNOK"
		echo "$PID" >> "$AUXIMPORTNOK"
	fi
done
}
CMDCHK

# GENERATING LIST WITH SUCCESSFULY TAPES

echo
echo "Generating list of successfuly tapes $(date +%d"/"%m"/"%y" "%T)"
echo

if [ -e "$AUXIMPORTOK" ]
	then
	while read PID TAPE LOGFILE
	do
		cat "$AUXIMPORTOK" | grep -w $PID
		if [ $? -eq "0" ]
			then
			cat "$AUXIMPORTOK" | grep -w "$PID" | head -n1 | echo "$TAPE" >> "$SUCCTAPE"
			echo "Tape $TAPE processed successfuly"
		fi
	done < "$LDIMPORT"/"$PROC_TABLE_IMPORT"
else
	echo "File AUXIMPORTOK does not exists"
	if [ -e "$AUXIMPORTNOK" ]
		then
		echo "Tapes with problem: \n"
		while read PID TAPE LOGFILE
		do
			cat "$AUXIMPORTNOK" | grep -w $PID
			if [ $? -eq "0" ]
				then
				cat "$AUXIMPORTNOK" | grep -w "$PID" | head -n1 | echo "$TAPE" >> "$ERRORTAPE"
				echo "Tape $TAPE processed with errors"
			fi
		done < "$LDIMPORT"/"$PROC_TABLE_IMPORT"
	fi
fi

# END OF SCRIPT

exit $RC
