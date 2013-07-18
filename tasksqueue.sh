#!/bin/bash

# Handle SIGTERM, SIGINT signal to permit next iteration
trap tasksqueue_prevent_iterations SIGTERM SIGINT

# Include config file
[ -r "$HOME/.yastq.conf" ] && source "$HOME/.yastq.conf" || { 
	[ -r "/etc/yastq.conf" ] && source "/etc/yastq.conf" || { echo "Error: loading config file failed" 1>&2; exit 1; }
}

# Include common file
[ -r "$COMMON_SCRIPT_FILE" ] && source "$COMMON_SCRIPT_FILE" || { echo "Error: loading common file failed" 1>&2; exit 1; }

##
## Pops task from tasks file
##
## Returns:
##  0 - on success
##  1 - on locking failure
##  2 - on read failure
##  3 - on removing failure
##
## Exports:
##	RESULT
##
tasksqueue_pop_task()
{
	unset -v RESULT
	local TASK

	# Obtain exclusive lock
	{
		log_debug "tasksqueue" "Locking tasks file '$TASKS_FILE' ..."
		if "$FLOCK" -x 200
		then
			log_debug "tasksqueue" "Locking tasks file '$TASKS_FILE' ok"
			log_debug "tasksqueue" "Reading first task from tasks file '$TASKS_FILE' ..."
			if read -r TASK 0<>"$TASKS_FILE"
			then
				log_debug "tasksqueue" "Reading first task from tasks file '$TASKS_FILE' ok"
				log_debug "tasksqueue" "Removing first task from tasks file '$TASKS_FILE' ..."
				if "$SED" -i 1d "$TASKS_FILE"
				then
					log_debug "tasksqueue" "Removing first task from tasks file '$TASKS_FILE' ok"
					RESULT=$TASK
					return 0
				else
					log_debug "tasksqueue" "Removing first task from tasks file '$TASKS_FILE' failed ($?)"
					return 3
				fi
			else
				log_debug "tasksqueue" "Reading first task from tasks file '$TASKS_FILE' failed ($?)"
				return 2
			fi
		else
			log_debug "tasksqueue" "Locking tasks file '$TASKS_FILE' failed ($?)"
			return 1
		fi		
	} 200<"$TASKS_FILE"
}

##
## Sends task to workers
##
## Returns:
##  0 - on success
##  1 - on sending failure
##
tasksqueue_send_task()
{
	local TASK=$1

	log_debug "tasksqueue" "Sending task '$TASK' to '$TASKS_PIPE' ..."
	if echo "$TASK" > "$TASKS_PIPE"
	then
		log_debug "tasksqueue" "Sending task '$TASK' to '$TASKS_PIPE' ok"
		return 0
	else
		log_debug "tasksqueue" "Sending task '$TASK' to '$TASKS_PIPE' failed"
		return 1
	fi
}

##
## Prevent next iterations
##
tasksqueue_prevent_iterations()
{
	log_info "tasksqueue" "Finishing (signal handled)"
	PREVENT_ITERATIONS=1
}

log_info "tasksqueue" "Starting"
while [ -z "$PREVENT_ITERATIONS" ]
do
	if tasksqueue_pop_task && [ -n "$RESULT" ]
	then
		log_info "tasksqueue" "Sending task '$RESULT' to workers ..."
		while ! tasksqueue_send_task "$RESULT"
		do
			log_warn "tasksqueue" "Retring sending task '$RESULT' to workers ..."
		done
		log_warn "tasksqueue" "Sending task '$RESULT' to workers ok"
	else
		"$SLEEP" 1s
	fi
done
log_info "tasksqueue" "Exiting"
