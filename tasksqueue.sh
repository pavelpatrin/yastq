#!/bin/bash

# Handle SIGTERM and SIGINT signals
trap tasksqueue_graceful_stop SIGTERM SIGINT

# Include config file
[ -r "$HOME/.yastq.conf" ] && source "$HOME/.yastq.conf" || { 
	[ -r "/etc/yastq.conf" ] && source "/etc/yastq.conf" || { echo "Error: loading config file failed" 1>&2; exit 1; }
}

# Include common file
[ -r "$COMMON_SCRIPT_FILE" ] && source "$COMMON_SCRIPT_FILE" || { echo "Error: loading common file failed" 1>&2; exit 1; }

##
## Prevent next iterations
##
tasksqueue_graceful_stop()
{
	log_info "tasksqueue" "Finishing (signal handled)"
	PREVENT_ITERATIONS=1
}

log_info "tasksqueue" "Starting"
while [ -z "$PREVENT_ITERATIONS" ]
do
	if queuedb_pop
	then
		TASK_DATA=("${RESULT[@]}")
		log_info "tasksqueue" "Sending task [${TASK_DATA[0]}] to workers ..."
		while ! echo $(printf "%q " "${TASK_DATA[@]}") > "$TASKS_PIPE" 
		do
			log_info "tasksqueue" "Retring sending task [${TASK_DATA[0]}] to workers ..."
		done
		log_info "tasksqueue" "Sending task [${TASK_DATA[0]}] to workers ok"
	else
		sleep 1s
	fi
done
log_info "tasksqueue" "Exiting"
