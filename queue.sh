#!/bin/bash

# Required file
INCLUDE="/home/pavelpat/Sheduler/common.sh"

# Include required file
if [[ -e $INCLUDE ]]; then 
	source $INCLUDE
else 
	echo "Please set correct $INCLUDE path"
	exit 1
fi

# On USR1 selecting mode sending empty lines
trap 'set_mode_empty_lines' 10

# On USR2 selecting mode sending tasks
trap 'set_mode_tasks' 12

# ON TERM exiting
trap 'stop_queue' 15

function set_mode_tasks() {
	log_queue "Entering mode sending tasks"
	SEND_EMPTY_LINES=0
}

function set_mode_empty_lines() {
	log_queue "Entering mode sending empty lines"
	SEND_EMPTY_LINES=1
}

function stop_queue() {
	log_queue "Stopping task queue"
	exit
}

# Whet it sets to 1 script sends empty lines to pipe
SEND_EMPTY_LINES=0

# Log about start
log_queue "Starting task queue"

# Infinitie loop
while [[ 0 ]]; do
	if ! [[ $SEND_EMPTY_LINES -eq 1 ]]; then
		# Read new task
		TASK=$($HEAD -n 1 $QUEUE_DELAYED_FILE)

		# If task is not empty
		if [[ -n $TASK ]]; then
			# Log action 
			log_queue "Sending task '$TASK' to pipe"

			# Send new task
			echo $TASK > $TASKS_QUEUE_PIPE

			# Remove task
			$TAIL -n +2 $QUEUE_DELAYED_FILE | $SPONGE $QUEUE_DELAYED_FILE
		fi
	else
		# Send empty lines to pipe
		echo "" > $TASKS_QUEUE_PIPE
	fi
done