#!/bin/bash

# Include common code
source `dirname $0`/common.sh

# Loop
while [[ 0 ]]; do
	# Read new task
	TASK=$($HEAD -n 1 $QUEUE_DELAYED_FILE)

	if [[ -n $TASK ]]; then
		# Send new task
		echo $TASK > $TASKS_QUEUE_PIPE

		# Remove task
		$TAIL -n +2 $QUEUE_DELAYED_FILE | $SPONGE $QUEUE_DELAYED_FILE
	fi
done

# Remove task from delayed file 
		