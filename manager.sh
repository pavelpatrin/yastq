#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

##
## Sends message to log
##
manager_log() 
{
	echo "$($DATE +'%F %T') (manager) $1" >> $LOG_MANAGER
}

##
## Sends status to pipe
##
manager_send_status() 
{
	echo "STATUSS!!!\nStaa!!!" > $MANAGER_STATUS_PIPE
}

##
## Graceful stop the manager
##
manager_graceful_stop()
{
	log_tasksqueue "Stopping gracefully"
	GRACEFUL_STOP=1
}

##
## Echoes pids of workers or returns error code
##
workers_pids() 
{
	if ! [ -e "$WORKERS_PIDS_FILE" ]
	then 
		return 1
	fi

	local WORKERS_PIDS
	read -r WORKERS_PIDS < $WORKERS_PIDS_FILE

	if ! $PS -p $WORKERS_PIDS 2>/dev/null >/dev/null
	then
		return 2
	fi

	echo $WORKERS_PIDS
	return 0
}

##
## Starts workers
##
workers_start() 
{
	local WORKERS_COUNT
	local WORKERS_PID
	local WORKERS_RUNING
	WORKERS_COUNT=$1
	WORKERS_PIDS=$(workers_pids)
	WORKERS_RUNING=$?

	if $WORKERS_RUNING
	then
		manager_log "Workers are already running"
		return 1
	fi

	unset -v WORKERS_PIDS
	for ((i=1; i<=$WORKERS_COUNT; i++))
	do
		$SCRIPT_WORKER > 2>/dev/null >/dev/null &
		WORKERS_PIDS="$WORKERS_PIDS $!"
	done

	echo $WORKERS_PIDS > $WORKERS_PIDS_FILE
	return 0
}

##
## Stops workers
##
workers_stop() 
{
	local WORKERS_PID
	local WORKERS_RUNING
	WORKERS_PID=$(workers_pids)
	WORKERS_RUNING=$?

	if ! $WORKERS_RUNING
	then
		manager_log "Workers are not running"
		return 1
	fi

	# Sending term signal to workers
	$KILL -s SIGTERM $WORKERS_PID >/dev/null

	# Waiting for workers exiting
	while $PS -p $WORKERS_PID >/dev/null
	do
	    $SLEEP 1s
	done
	
	# Remove pids file
	$RM -f $WORKERS_PIDS_FILE
	return 0
}

##
## Echoes pid of tasksqueue or returns error code
##
tasksqueue_pids() 
{

}

##
## Starts tasksqueue
##
tasksqueue_start()
{

}

##
## Stops tasksqueue
##
tasksqueue_stop()
{

}

# On TERM exiting
trap 'manager_graceful_stop' TERM

# On USR1 send status info
trap 'manager_send_status' USR1

# Start tasks queue
log_tasksqueue "Starting tasks queue"
tasksqueue_start

# Start workers
log_tasksqueue "Starting $MAX_PARALLEL_SHEDULES workers"
workers_start $MAX_PARALLEL_SHEDULES

# Loop
while [ -z "$GRACEFUL_STOP" ]
do
	sleep 1s
done

# Stop workers
log_tasksqueue "Stopping workers"
workers_stop

# Stop tasksqueue
log_tasksqueue "Stopping tasksqueue"
tasksqueue_stop
