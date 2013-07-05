#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]; then source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Include common code
source $SCRIPT_DIR/common.sh

function log_queue() {
	echo "$($DATE) (queue) $1" >> $LOG_QUEUE
}

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

# On USR1 selecting mode sending empty lines
trap 'set_mode_empty_lines' USR1

# On USR2 selecting mode sending tasks
trap 'set_mode_tasks' USR2

# ON TERM exiting
trap 'stop_queue' TERM

# Whet it sets to 1 script sends empty lines to pipe
SEND_EMPTY_LINES=0

# Log about start
log_queue "Starting task queue"

# Infinitie loop
while [[ 0 ]]; do
	if ! [[ $SEND_EMPTY_LINES -eq 1 ]]
	then
		# Read new task
		TASK=$($HEAD -n 1 $TASKS_QUEUE_FILE)

		# If task is not empty
		if [[ -n $TASK ]]
		then
			# Log action 
			log_queue "Sending task '$TASK' to pipe"

			# Send new task to pipe
			echo $TASK > $TASKS_QUEUE_PIPE

			# Remove task from tasks file
			$SED -i 1d $TASKS_QUEUE_FILE
		fi
	else
		# Send empty lines to pipe
		echo > $QUEUE_TASKS_PIPE
	fi
done