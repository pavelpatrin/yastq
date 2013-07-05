#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]; then source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Include common code
source $SCRIPT_DIR/common.sh

function log_worker() {
	echo "(worker $$) $1" | $TS >> $LOG_WORKER
}

# Handle TERM signal for permit next iteration
trap 'CONTINUE=0' 15

# Log about starting
log_worker "Worker starting"

# Continue next task after
CONTINUE=1

# Tasks loop
while [[ $CONTINUE -eq 1 ]]
do
	# Read next task
	read TASK < $TASKS_QUEUE_PIPE 2>/dev/null

	if [[ -n "$TASK" ]]
	then
		# Log task start
		log_worker "Running task: $TASK"

		# Run task
		eval "$TASK 2>&1 >/dev/null &"
		wait $!
		CODE=$?

		# Log task end
		log_worker "Running task finished with code $CODE: $TASK "
	else
		# Task is empty. Sleep
		sleep 1
	fi
done

log_worker "Worker exiting"
