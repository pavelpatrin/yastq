#!/bin/bash

# Include config file
if [ -r "$HOME/.yastq.conf" ]
then 
	source "$HOME/.yastq.conf"
elif [ -r "/etc/yastq.conf" ]
then 
	source "/etc/yastq.conf"
else 
	echo "Config file not found"
	exit 1
fi

# Include common code
if ! source "$SCRIPT_DIR/common.sh"
	then echo "Error including common file"
	exit 1
fi

##
## Sends message to log
##
tasksqueue_log() 
{
	echo "$($DATE +'%F %T') (tasksqueue $$) $1" >> $TASKSQUEUE_LOG_FILE
}

##
## Gracefully stops the tasks queue
##
tasksqueue_graceful_stop()
{
	GRACEFUL_STOP=1
	return 0
}

# Handle TERM signal to permit next iteration
trap 'tasksqueue_graceful_stop && tasksqueue_log "Stopping gracefully" || tasksqueue_log "Stopping gracefully failed"' SIGTERM

# Log about starting
tasksqueue_log "Starting"

# Tasks loop
while [ -z "$GRACEFUL_STOP" ]
do
	# Read new task from tasks file database
	if read -r TASK < $TASKSQUEUE_TASKS_FILE && [ -n "$TASK" ] 
	then
		# Send new task to pipe
		if echo $TASK > $TASKSQUEUE_TASKS_PIPE
		then
			tasksqueue_log "Sending base64 task '$TASK' to pipe ok"
		
			# Obtain write lock
			{
				# Read new task from tasks file database
				if $FLOCK -x 200 && $SED -i 1d $TASKSQUEUE_TASKS_FILE
				then
					tasksqueue_log "Removing base64 task '$TASK' from tasks database ok"
				else
					tasksqueue_log "Removing base64 task '$TASK' from tasks database failed" 
				fi
			} 200<"$TASKSQUEUE_TASKS_LOCK"
		else
			tasksqueue_log "Sending base64 task '$TASK' to pipe failed"
		fi
	else
		$SLEEP 1s
	fi
done

# Log about exiting
tasksqueue_log "Exiting"
