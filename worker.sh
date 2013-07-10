#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

log_worker() {
	echo "$($DATE +'%F %T') (worker $$) $1" >> $LOG_WORKER
}

prevent_next_iteration() {
	CONTINUE=0
}

# Handle TERM signal for permit next iteration
trap 'prevent_next_iteration' TERM

# Log about starting
log_worker "Starting worker"

# Continue next task after
CONTINUE=1

# Tasks loop
while [ 1 = "$CONTINUE" ]
do
	# Clear previous task
	unser -v TASK_INFO

	# Read next task
	read -a TASK_INFO < $MANAGER_TASKS_PIPE 2>/dev/null

	# If it is array that contains elements
	if [ -n "$TASK_INFO" ]
	then
		# Save aplitted into variables
		TASK=$(echo ${TASK_INFO[0]}| $BASE64 --decode)
		SUCCESS=$(echo ${TASK_INFO[1]}| $BASE64 --decode)
		FAIL=$(echo ${TASK_INFO[2]}| $BASE64 --decode)

		# Log task start
		log_worker "Running task: $TASK"

		# Run task
		eval "$TASK &"
		wait $!
		CODE=$?

		if [ 0 = "$CODE" ]
		then 
			log_worker "Running task finished with code $CODE: $TASK. Executing SUCCESS command: $SUCCESS"
			eval "$SUCCESS"
		else 
			log_worker "Running task finished with code $CODE: $TASK. Executing FAIL command: $FAIL"
			eval "$FAIL"
		fi
	else
		# Task is empty. Sleep
		$SLEEP 1s
	fi
done

log_worker "Worker exiting"
