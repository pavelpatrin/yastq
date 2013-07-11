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
worker_log() 
{
	echo "$($DATE +'%F %T') (worker $$) $1" >> $LOG_WORKER
}

##
## Runs task
##
worker_run_task()
{
	local TASK=$1

	$BASH -c "$TASK" &
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

	# Read next task with 1 sec timeout
	read -t 1 -a TASK_INFO <> $TASKSQUEUE_TRANSMIT_PIPE

	# If task info array has > 0 size
	if [ "${#TASK_INFO[@]}" -gt 0 ]
	then
		# Save aplitted into variables
		TASK=$(echo ${TASK_INFO[0]}| $BASE64 --decode)
		SUCC=$(echo ${TASK_INFO[1]}| $BASE64 --decode)
		FAIL=$(echo ${TASK_INFO[2]}| $BASE64 --decode)

		# Log task start
		worker_log "Running task: $TASK"

		# Run task
		worker_run_task "$TASK"
		CODE=$?

		if [ 0 = "$CODE" ]
		then
			worker_log "Running task finished with code $CODE: $TASK. Executing SUCC command: $SUCC"
			worker_run_task $SUCC
		else 
			worker_log "Running task finished with code $CODE: $TASK. Executing FAIL command: $FAIL"
			worker_run_task $FAIL
		fi
	fi
done

# Log about exiting
worker_log "Exiting"
