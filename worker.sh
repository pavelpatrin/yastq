#!/bin/bash

# Handle SIGTERM, SIGINT signal for forbid next iteration
trap worker_prevent_iterations SIGTERM SIGINT

# Include config file
[ -r "$HOME/.yastq.conf" ] && source "$HOME/.yastq.conf" || { 
	[ -r "/etc/yastq.conf" ] && source "/etc/yastq.conf" || { echo "Error: loading config file failed" 1>&2; exit 1; }
}

# Include common file
[ -r "$COMMON_SCRIPT_FILE" ] && source "$COMMON_SCRIPT_FILE" || { echo "Error: loading common file failed" 1>&2; exit 1; }

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
worker_read_task()
{
	local TASK
	unset -v RESULT

	# Obtain exclusive lock
	{
		log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] ..."
		if "$FLOCK" -x 200
		then 
			if read -t 1 -a TASK 0<>"$TASKS_PIPE"
			then
				log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] ok"
				RESULT=("${TASK[@]}")
				return 0
			else
				log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] failed (Reading failed)"
				return 2
			fi
		else
			log_debug "worker" "Reading task from tasks pipe [$TASKS_PIPE] failed (Locking failed)"
			return 1
		fi
	} 200<"$TASKS_PIPE"
}

##
## Executes specified task with handlers
##
## Params:
##	$1 - TASK command
##	$2 - SUCC handler command
##	$3 - FAIL handler command
##
## Returns:
##  0 - on success
##
worker_execute_task()
{
	local TASK_GOAL=$1
	local TASK_SUCC=$2
	local TASK_FAIL=$3

	log_debug "worker" "Executing task goal [$TASK_GOAL] ..."
	if worker_execute_command "$TASK_GOAL"
	then
		log_debug "worker" "Executing task goal [$TASK_GOAL] ok"
		log_debug "worker" "Executing task success handler [$TASK_SUCC] ..."
		if worker_execute_command "$TASK_SUCC"
		then
			log_debug "worker" "Executing success handler [$TASK_SUCC] ok"
		else
			log_debug "worker" "Executing success handler [$TASK_SUCC] failed (Exit code [$?])"
		fi
	else 
		log_debug "worker" "Executing task goal [$TASK_GOAL] failed (Exit code [$?])"
		log_debug "worker" "Executing failure handler [$TASK_FAIL] ..."
		if worker_execute_command "$TASK_FAIL"
		then
			log_debug "worker" "Executing failure handler [$TASK_FAIL] ok"
		else
			log_debug "worker" "Executing failure handler [$TASK_FAIL] failed (Exit code [$?])"
		fi
	fi

	return 0
}

##
## Execute command in new terminal and return its exit code
##
worker_execute_command()
{
	local COMMAND=$1

	log_debug "worker" "Executing command [$COMMAND] ..."
	"$BASH" -c "$COMMAND" &
	wait $!
	EXIT_CODE=$?
	if [ 0 = "$EXIT_CODE" ]
	then
		log_debug "worker" "Executing command [$COMMAND] ok'"
		return 0
	else
		log_debug "worker" "Executing command [$COMMAND] failed (Exit code [$EXIT_CODE])'"
		return $EXIT_CODE
	fi
}

##
## Prevent next iterations
##
worker_prevent_iterations()
{
	log_info "worker" "Finishing (signal handled)"
	PREVENT_ITERATIONS=1
}

log_info "worker" "Starting"
while [ -z "$PREVENT_ITERATIONS" ]
do
	if worker_read_task && [ -n "$RESULT" ]
	then
		TASK_ID=${RESULT[0]}
		TASK_GOAL=$(echo ${RESULT[1]}| $BASE64 --decode) 
		TASK_SUCC=$(echo ${RESULT[2]}| $BASE64 --decode)
		TASK_FAIL=$(echo ${RESULT[3]}| $BASE64 --decode)

		log_info "worker" "Executing task [$TASK_ID] ..."
		if worker_execute_task "$TASK_GOAL" "$TASK_SUCC" "$TASK_FAIL"
		then
			log_info "worker" "Executing task [$TASK_ID] ok"
		else
			log_info "worker" "Executing task [$TASK_ID] failed"
		fi
	else
		"$SLEEP" 1s
	fi
done
log_info "worker" "Exiting"
