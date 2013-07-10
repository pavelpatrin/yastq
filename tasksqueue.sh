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
## Gracefully stops the tasks queue
##
tasksqueue_graceful_stop()
{
	tasksqueue_log "Stopping gracefully"
	GRACEFUL_STOP=1
}

# Handle TERM signal for permit next iteration
trap 'tasksqueue_graceful_stop' TERM

# Log about starting
tasksqueue_log "Starting"

# Tasks loop
while [ -z "$GRACEFUL_STOP" ]
do
	# Unset previous task
	unset -v TASK

	# Read new task from tasks file descriptor
	read -r TASK < $MANAGER_TASKS_FILE

	# If task is not empty
	if [ -n "$TASK" ]
	then
		# Log action 
		log_manager "Sending base64 task '$TASK' to pipe"

		# Send new task to pipe
		echo $TASK > $MANAGER_TASKS_PIPE

		# Remove task from tasks file
		$SED -i 1d $MANAGER_TASKS_FILE
	else
		# Sleep if no task received
		$SLEEP 1s
	fi
done

# Log about exiting
tasksqueue_log "Exiting"
