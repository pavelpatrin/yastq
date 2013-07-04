#!/bin/bash

# Include common code
source `dirname $0`/common.sh

# Handle TERM signal for permit next iteration
trap 'CONTINUE=0' 15

log_worker "$$ Worker starting"

# Continue next task after
CONTINUE=1;

# Tasks loop
while [[ $CONTINUE -eq 1 ]]
do
	if [[ -e $TASKS_QUEUE_PIPE ]]; then
		# Read next task
		TASK=$($CAT $TASKS_QUEUE_PIPE)

		# Log task start
		log_worker "$$ Running task $TASK"

		# Run task
		eval "$TASK &"; wait; 
		CODE=$?
		
		if [[ $CODE -eq 0 ]]; then
			# Put it into completes file
			echo "$TASK" >> $QUEUE_COMPLETE_FILE
		else 
			# Put it into errors file
			echo "$TASK" >> $QUEUE_FAILED_FILE
		fi

		# Log task end
		log_worker "$$ Running task finished with code $CODE"
	else
		# Pipe is not exists. Sleep
		sleep 1
	fi
done

log_worker "$$ Worker exiting"
