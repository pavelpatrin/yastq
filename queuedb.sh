#!/bin/bash

##
## This script must be sourced with:
##	$1 - Path to db file
##	$2 - Path to database file lock
##	$3 - Database file lock timeout
##

# Arguments
QUEUEDB_DB_FILE=$1
QUEUEDB_DB_LOCK=$2
QUEUEDB_DB_LOCK_TIMEOUT=$3

# Check arguments
[ -n "$QUEUEDB_DB_FILE" -a -r "$QUEUEDB_DB_FILE" -a -w "$QUEUEDB_DB_FILE" ] || return 2
[ -n "$QUEUEDB_DB_LOCK_TIMEOUT" ] || return 2

## 
## Pops data from DB file and sets up RESULT variable with row data
##
## Return:
##	0 - When all ok
##	1 - When lock failed or timed out
##  2 - When read failed [f.e. db is empty]
##	3 - When write failed
## 
queuedb_pop()
{
	unset -v RESULT

	log_debug "queuedb" "Popping row from [$QUEUEDB_DB_FILE] ..."
	{
		if ! flock -x -w "$QUEUEDB_DB_LOCK_TIMEOUT" 200
		then
			log_debug "queuedb" "Popping row from [$QUEUEDB_DB_FILE] failed (Lock with timeout [$QUEUEDB_DB_LOCK_TIMEOUT] failed with code [$?])"
			return 1
		fi
		
		local ROW_DATA
		if ! read -a ROW_DATA 0<"$QUEUEDB_DB_FILE"
		then
			log_debug "queuedb" "Popping row from [$QUEUEDB_DB_FILE] failed (Read failed with code [$?])"
			return 2
		fi

		if ! sed -i "1d" "$QUEUEDB_DB_FILE"
		then
			log_debug "queuedb" "Popping row from [$QUEUEDB_DB_FILE] failed (Sed failed with code [$?])"
			return 3
		fi
			
		log_debug "queuedb" "Popping row from [$QUEUEDB_DB_FILE] ok"
		RESULT=("${ROW_DATA[@]}")
		return 0
	} 200<"$QUEUEDB_DB_LOCK" 
}

## 
## Pushes data to DB file and sets up RESULT variable with row is
##
## Return:
##	0 - When all ok
##	1 - When lock failed or timed out
##  2 - When write failed
## 
queuedb_push()
{	
	unset -v RESULT
	local ROW_ID=$(date '+%s%N')
	local ROW_DATA=("$@")

	log_debug "queuedb" "Pushing row [$ROW_ID] to [$QUEUEDB_DB_FILE] ..."
	{
		if ! flock -x -w "$QUEUEDB_DB_LOCK_TIMEOUT" 200
		then
			log_debug "queuedb" "Pushing row [$ROW_ID] to [$QUEUEDB_DB_FILE] failed (Lock with timeout [$QUEUEDB_DB_LOCK_TIMEOUT] failed with code [$?])"
			return 1
		fi

		if ! echo $(printf "%q " "$ROW_ID" "${ROW_DATA[@]}") 1>>"$QUEUEDB_DB_FILE"
		then
			log_debug "queuedb" "Pushing row [$ROW_ID] to [$QUEUEDB_DB_FILE] failed (Write failed with code [$?])"
			return 2
		fi

		log_debug "queuedb" "Pushing row [$ROW_ID] to [$QUEUEDB_DB_FILE] ok"
		RESULT=$ROW_ID
		return 0
	} 200<"$QUEUEDB_DB_LOCK" 
}

## 
## Selects data in DB file and sets up RESULT variable with found row data
##
## Return:
##	0 - When all ok
##	1 - When lock failed or timed out
##  2 - When grep failed (f.e. not found)
##	3 - When read failed
## 
queuedb_find()
{
	unset -v RESULT
	local ROW_ID=$1

	log_debug "queuedb" "Selecting row [$ROW_ID] from [$QUEUEDB_DB_FILE] ..."
	{
		if ! flock -x -w "$QUEUEDB_DB_LOCK_TIMEOUT" 200
		then
			log_debug "queuedb" "Selecting row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Lock with timeout [$QUEUEDB_DB_LOCK_TIMEOUT] failed with code [$?])"
			return 1
		fi

		local ROW_LINE=$(grep "^$ROW_ID\s" "$QUEUEDB_DB_FILE")
		if ! [ -n "$ROW_LINE" ]
		then
			log_debug "queuedb" "Selecting row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Grep failed with code [$?])"
			return 2
		fi

		local ROW_DATA
		if ! read -a ROW_DATA 0<<<$ROW_LINE
		then
			log_debug "queuedb" "Selecting row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Read failed with code [$?])"
			return 3
		fi
			
		log_debug "queuedb" "Selecting row [$ROW_ID] from [$QUEUEDB_DB_FILE] ok"
		RESULT=("${ROW_DATA[@]}")
		return 0
	} 200<"$QUEUEDB_DB_LOCK" 
}

## 
## Removes data from DB file with specified row id
##
## Params:
##	$1 - Row id
##
## Return:
##	0 - When all ok
##	1 - When lock failed or timed out
##  2 - When row not found
##  3 - When write failed
## 
queuedb_remove()
{
	unset -v RESULT
	local ROW_ID=$1

	log_debug "queuedb" "Removing row [$ROW_ID] from [$QUEUEDB_DB_FILE] ..."
	{
		if ! flock -x -w "$QUEUEDB_DB_LOCK_TIMEOUT" 200
		then
			log_debug "queuedb" "Removing row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Lock with timeout [$QUEUEDB_DB_LOCK_TIMEOUT] failed with code [$?])"
			return 1
		fi
		
		if ! grep -q "^$TASK_ID\s" "$QUEUEDB_DB_FILE"
		then
			log_debug "queuedb" "Removing row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Grep failed with code [$?])"
			return 2	
		fi

		if ! sed -i "/^$TASK_ID\s/d" "$QUEUEDB_DB_FILE" 
		then
			log_debug "queuedb" "Removing row [$ROW_ID] from [$QUEUEDB_DB_FILE] failed (Sed failed with code [$?])"
			return 3
		fi

		log_debug "queuedb" "Removing row [$ROW_ID] from [$QUEUEDB_DB_FILE] ok"
		return 0
	} 200<"$QUEUEDB_DB_LOCK"
}
