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
	# If is what to do
	if [[ $($WC -l $QUEUE_DELAYED_FILE | $CUT -f 1 -d " ") -gt 0 ]]; then
		# Read next task
		TASK=$($HEAD -n 1 $QUEUE_DELAYED_FILE)

		# Log task start
		log_worker "$$ Running task $TASK"

		# Remove task from delayed file 
		$TAIL -n +2 $QUEUE_DELAYED_FILE | $SPONGE $QUEUE_DELAYED_FILE

		# Add task to a active file
		echo "$TASK" >> $QUEUE_ACTIVE_FILE
		
		# Run task
		eval "$TASK &"; wait; 
		CODE=$?

		# Remove task from a active file
		$GREP -v $$ $QUEUE_ACTIVE_FILE | $SPONGE $QUEUE_ACTIVE_FILE
		
		if [ $CODE ]; then
			# Put it into completes file
			echo "$TASK" >> $QUEUE_COMPLETE_FILE
		else 
			# Put it into errors file
			echo "$TASK" >> $QUEUE_FAILED_FILE
		fi

		# Log task end
		log_worker "$$ Running task finished with code $CODE"
	else
		# Sleep for one second before next check
		sleep 1
	fi
done

log_worker "$$ Worker exiting"
