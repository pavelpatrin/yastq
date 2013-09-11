#!/bin/bash

# Handle SIGTERM and SIGINT signals
trap worker_graceful_stop SIGTERM SIGINT

# Include config file
[ -r "$HOME/.yastq.conf" ] && source "$HOME/.yastq.conf" || { 
       [ -r "/etc/yastq.conf" ] && source "/etc/yastq.conf" || { echo "Error: loading config file failed" 1>&2; exit 1; }
}

# Include common file
[ -r "$COMMON_SCRIPT_FILE" ] && source "$COMMON_SCRIPT_FILE" || { echo "Error: loading common file failed" 1>&2; exit 1; }

##
## Prevent next iterations
##
worker_graceful_stop()
{
	log_info "worker" "Finishing (signal handled)"
	PREVENT_ITERATIONS=1
}

##
## Execute command in new terminal and return its exit code
##
## Params:
##	$1 - command
##
## Returns:
##	command exit code
##
worker_eval()
{
	local COMMAND=$1

	log_trace "worker" "Executing command [$COMMAND] ..."
	bash -c "$COMMAND" &
	wait $!
	EXIT_CODE=$?
	if [ 0 = "$EXIT_CODE" ]
	then
		log_trace "worker" "Executing command [$COMMAND] ok'"
		return 0
	else
		log_trace "worker" "Executing command [$COMMAND] failed (Exit code [$EXIT_CODE])'"
		return $EXIT_CODE
	fi
}

##
## Reads task from tasks pipe
##
## Returns:
##  0 - on success
##  1 - on locking failure
##  2 - on read failure
##
## Exports:
##	RESULT
##
worker_task_read()
{
	local TASK_DATA
	unset -v RESULT
	
	log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] ..."
	{	
		# asyncronous execute flock and wait its exit
		# it needed because flock does not stops when script handling signal
		if flock -x 200 & wait $! 
		then 
			if read -a TASK_DATA 0<"$TASKS_PIPE"
			then
				log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] ok"
				RESULT=("${TASK_DATA[@]}")
				return 0
			else
				log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] failed (Reading failed with code [$?])"
				return 2
			fi
		else
			log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] failed (Locking failed with code [$?])"
			return 1
		fi
	} 200<>"$TASKS_PIPE_LOCK"
}

##
## Executes specified task with handlers
##
## Params:
##	$1 - TASK id
##	$2 - TASK command
##	$3 - SUCC handler command
##	$4 - FAIL handler command
##	$5 - TASK options
##
## Returns:
##  0 - on success
##
worker_task_execute()
{
	local TASK_ID=$1
	local TASK_GOAL=$2
	local TASK_SUCC=$3
	local TASK_FAIL=$4
	local TASK_OPTIONS=$5

	if [[ "$TASK_OPTIONS" == *APPEND_ID_TASK* ]]
	then
		TASK_GOAL="$TASK_GOAL $TASK_ID"
	fi

	if [[ "$TASK_OPTIONS" == *APPEND_ID_SUCC* ]]
	then
		TASK_SUCC="$TASK_SUCC $TASK_ID"
	fi

	if [[ "$TASK_OPTIONS" == *APPEND_ID_FAIL* ]]
	then
		TASK_FAIL="$TASK_FAIL $TASK_ID"
	fi

	log_debug "worker" "Executing task goal [$TASK_GOAL] ..."
	if worker_eval "$TASK_GOAL"
	then
		log_debug "worker" "Executing task goal [$TASK_GOAL] ok"
		log_debug "worker" "Executing task success handler [$TASK_SUCC] ..."
		if worker_eval "$TASK_SUCC"
		then
			log_debug "worker" "Executing task success handler [$TASK_SUCC] ok"
		else
			log_debug "worker" "Executing task success handler [$TASK_SUCC] failed (Exit code [$?])"
		fi
	else 
		log_debug "worker" "Executing task goal [$TASK_GOAL] failed (Exit code [$?])"
		log_debug "worker" "Executing task failure handler [$TASK_FAIL] ..."
		if worker_eval "$TASK_FAIL"
		then
			log_debug "worker" "Executing task failure handler [$TASK_FAIL] ok"
		else
			log_debug "worker" "Executing task failure handler [$TASK_FAIL] failed (Exit code [$?])"
		fi
	fi

	return 0
}

log_info "worker" "Starting"
while [ -z "$PREVENT_ITERATIONS" ]
do
	log_info "worker" "Reading task ..."
	if worker_task_read && [ -n "$RESULT" ]
	then
		log_info "worker" "Reading task ok"

		TASK_INFO=("${RESULT[@]}")
		log_info "worker" "Executing task [${TASK_INFO[0]}] ..."
		if worker_task_execute "${TASK_INFO[@]:0:5}"
		then
			log_info "worker" "Executing task [${TASK_INFO[0]}] ok"
		else
			log_info "worker" "Executing task [${TASK_INFO[0]}] failed (Task execute failed with code [$?])"
		fi
	else
		log_info "worker" "Reading task failed (Task read failed with code [$?])"
		sleep 1s
	fi
done
log_info "worker" "Exiting"
