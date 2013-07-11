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
tasksqueue_log() 
{
	echo "$($DATE +'%F %T') (tasksqueue $$) $1" >> $LOG_TASKSQUEUE
}

##
## Receives task from pipe and adds it to queue
##
tasksqueue_receive_task()
{
	local RECEIVE_TASK_TIMEOUT=$1

	read -t $RECEIVE_TASK_TIMEOUT -r TASK <> $TASKSQUEUE_RECEIVE_PIPE
	if [ -n "$TASK" ]
	then
		echo $TASK >> $TASKSQUEUE_TASKS_FILE
		return 0
	fi

	return 1
}

##
## Gracefully stops the tasks queue
##
tasksqueue_graceful_stop()
{
	GRACEFUL_STOP=1
	return 0
}

# Handle USR1 signal to receive new task
trap 'tasksqueue_receive_task 10 && tasksqueue_log "Receiving task ok" || tasksqueue_log "Receiving task failed ($?)"' SIGUSR1

# Handle TERM signal to permit next iteration
trap 'tasksqueue_graceful_stop && tasksqueue_log "Stopping gracefully" || tasksqueue_log "Stopping gracefully failed"' SIGTERM

# If $1 is specified string, read task from pipe and exit
if [ "$1" = "receive-task" ]
then
	tasksqueue_receive_task 2
	RECEIVE_STATUS=$?
	if [ $RECEIVE_STATUS ]
	then
		tasksqueue_log "Receiving task ok" 
	else
		tasksqueue_log "Receiving task failed ($RECEIVE_STATUS)"
	fi

	exit 0
fi

# Log about starting
tasksqueue_log "Starting"

# Tasks loop
while [ -z "$GRACEFUL_STOP" ]
do
	# Unset previous task
	unset -v TASK

	# Read new task from tasks file descriptor
	read -r TASK < $TASKSQUEUE_TASKS_FILE

	# If task is not empty
	if [ -n "$TASK" ]
	then
		# Log action 
		tasksqueue_log "Sending base64 task '$TASK' to pipe"

		# Send new task to pipe
		echo $TASK > $TASKSQUEUE_TRANSMIT_PIPE

		# Remove task from tasks file
		$SED -i 1d $TASKSQUEUE_TASKS_FILE
	else
		# Sleep if no task received
		$SLEEP 1s
	fi
done

# Log about exiting
tasksqueue_log "Exiting"
