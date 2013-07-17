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
if ! source "$COMMON_SCRIPT_FILE"
then 
	echo "Error including common file"
	exit 1
fi

##
## Sends message to log
##
worker_log() 
{
	echo "$($DATE +'%F %T') (worker $$) $1" >> "$WORKER_LOG_FILE"
}

##
## Runs task
##
worker_run_task()
{
	local TASK=$1

	"$BASH" -c "$TASK" &
	wait $!
	return $?
}

##
## Gracefully stops the worker after current task
##
worker_graceful_stop()
{
	GRACEFUL_STOP=1
	return 0
}

# Handle TERM signal for permit next iteration
trap 'worker_graceful_stop && worker_log "Stopping gracefully" || worker_log "Stopping gracefully failed"' TERM

# Log about starting
worker_log "Starting"

# Tasks loop
while [ -z "$GRACEFUL_STOP" ]
do
	# Clear previous task
	unset -v TASK_INFO

	# Obtain exclusive lock
	{
		"$FLOCK" -x 200
		read -t 0.1 -a TASK_INFO <> "$TASKSQUEUE_TASKS_PIPE"
	} 200<"$TASKSQUEUE_TASKS_PIPE_LOCK"

	# If read was not success
	if ! [ $? ]
	then
		continue
	fi

	# If read was empty
	if ! [ "${#TASK_INFO[@]}" -gt 0 ] 
	then
		continue
	fi

	# Save task info into variables
	TASK=$(echo ${TASK_INFO[0]}| $BASE64 --decode)
	SUCC=$(echo ${TASK_INFO[1]}| $BASE64 --decode)
	FAIL=$(echo ${TASK_INFO[2]}| $BASE64 --decode)

	# Run task
	worker_log "Running task: $TASK"
	if worker_run_task "$TASK"
	then
		worker_log "Running task finished with code $?: $TASK"
		worker_log "Executing SUCC command: $SUCC"
		worker_run_task "$SUCC"
	else 
		worker_log "Running task finished with code $?: $TASK"
		worker_log "Executing FAIL command: $FAIL"
		worker_run_task "$FAIL"
	fi
done

# Log about exiting
worker_log "Exiting"
