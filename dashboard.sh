#!/bin/bash

# Include config file
[ -r "$HOME/.yastq.conf" ] && source "$HOME/.yastq.conf" || { 
	[ -r "/etc/yastq.conf" ] && source "/etc/yastq.conf" || { echo "Error: loading config file failed" 1>&2; exit 1; }
}

# Include common file
[ -r "$COMMON_SCRIPT_FILE" ] && source "$COMMON_SCRIPT_FILE" || { echo "Error: loading common file failed" 1>&2; exit 1; }

##
## Returns error code 0 and sets RESULT or returns error code
##
## Returns:
##  0 - on getting pid success
##  1 - on getting pid failure
## 
## Exports:
##	RESULT - Tasksqueue pid
##
workers_pids() 
{
	unset -v RESULT

	log_debug "dashboard" "Getting workers pids ..."
	if ! [ -e "$WORKERS_PID_FILE" ]
	then 
		log_debug "dashboard" "Getting workers pids failed (Pid file is not exists)"
		return 1
	fi

	local WORKERS_PIDS
	read -r WORKERS_PIDS 0<"$WORKERS_PID_FILE"
	if "$PS" -p $WORKERS_PIDS 2>/dev/null 1>/dev/null
	then
		RESULT=$WORKERS_PIDS
		log_debug "dashboard" "Getting workers pids ok [$WORKERS_PIDS]"
		return 0
	else
		log_debug "dashboard" "Getting workers pids failed (Processes are not exists)"
		return 1
	fi	
}

##
## Starts workers
##
## Returns:
##  0 - on start success
##  1 - on tasksqueue is running
##
workers_start() 
{
	local WORKERS_COUNT=$1

	log_debug "dashboard" "Starting [$WORKERS_COUNT] workers ..."
	if ! workers_pids
	then
		local WORKERS_PIDS
		for ((i=1; i<=$WORKERS_COUNT; i++))
		do
			"$NOHUP" "$WORKER_SCRIPT_FILE" 2>/dev/null 1>/dev/null &
			WORKERS_PIDS="$WORKERS_PIDS $!"
		done

		# Store workers pids into pidfile
		echo $WORKERS_PIDS 1>"$WORKERS_PID_FILE"
		log_debug "dashboard" "Starting workers [$WORKERS_PIDS] ok"
		return 0
	else
		log_debug "dashboard" "Starting workers failed (Workers are already running)"
		return 1
	fi
}

##
## Stops workers
##
## Returns:
##  0 - on stop success
##  1 - on getting pid failure
##
workers_stop() 
{
	log_debug "dashboard" "Stopping workers ..."
	if workers_pids
	then
		"$KILL" -s SIGTERM $RESULT 1>/dev/null
		while "$PS" -p $RESULT 1>/dev/null
		do
		    "$SLEEP" 1s
		done
		"$RM" -f "$WORKERS_PID_FILE"
		log_debug "dashboard" "Stopping workers [$RESULT] ok"
		return 0
	else
		log_debug "dashboard" "Stopping workers failed (Workers are not running)"
		return 1
	fi
}

##
## Returns error code 0 and sets RESULT or returns error code
##
## Returns:
##  0 - on getting pid success
##  1 - on getting pid failure
## 
## Exports:
##	RESULT - Tasksqueue pid
##
tasksqueue_pid()
{
	unset -v RESULT

	log_debug "dashboard" "Getting tasksqueue pids ..."
	if ! [ -e "$TASKSQUEUE_PID_FILE" ]
	then 
		log_debug "dashboard" "Getting tasksqueue pids failed (Pid file is not exists)"
		return 1
	fi

	local TASKSQUEUE_PID
	read -r TASKSQUEUE_PID 0<"$TASKSQUEUE_PID_FILE"
	if "$PS" -p $TASKSQUEUE_PID 2>/dev/null 1>/dev/null
	then
		RESULT=$TASKSQUEUE_PID
		log_debug "dashboard" "Getting tasksqueue pids ok [$TASKSQUEUE_PID]"
		return 0
	else
		log_debug "dashboard" "Getting tasksqueue pids failed (Process is not exists)"
		return 1
	fi
}

##
## Starts tasks queue
##
## Returns:
##  0 - on start success
##  1 - on tasksqueue is running
##
tasksqueue_start()
{
	log_debug "dashboard" "Starting tasksqueue  ..."
	if ! tasksqueue_pid
	then
		"$NOHUP" "$TASKSQUEUE_SCRIPT_FILE" 2>/dev/null 1>/dev/null &
		local TASKSQUEUE_PID=$!
		echo $TASKSQUEUE_PID 1>"$TASKSQUEUE_PID_FILE"
		log_debug "dashboard" "Starting tasksqueue [$TASKSQUEUE_PID] ok"
		return 0
	else
		log_debug "dashboard" "Starting tasksqueue failed (Taskqueue is already running)"
		return 1
	fi
}

##
## Stops tasks queue
##
## Returns:
##  0 - on stop success
##  1 - on getting pid failure
##
tasksqueue_stop()
{
	log_debug "dashboard" "Stopping tasksqueue  ..."
	if tasksqueue_pid
	then
		local TASKSQUEUE_PID=$RESULT
		"$KILL" -s SIGTERM $TASKSQUEUE_PID 1>/dev/null
		while "$PS" -p $TASKSQUEUE_PID 1>/dev/null;	do "$SLEEP" 1s; done
		"$RM" -f "$TASKSQUEUE_PID_FILE"
		log_debug "dashboard" "Stopping tasksqueue [$TASKSQUEUE_PID] ok"
		return 0
	else
		log_debug "dashboard" "Stopping tasksqueue failed (Tasksqueue is not running)"
		return 1
	fi
}

## 
## Appends tasks file with new task
##
## Params:
##	$1 - Task code
##	$2 - Task success handler
##	$3 - Task failure handler
##
## Returns:
##  0 - on adding success
##  1 - on empty args
##  2 - on adding fail
## 
## Exports:
##	RESULT - Task id
##
dashboard_push_task() 
{	
	local TASK_GOAL=$1
	local TASK_SUCC=$2
	local TASK_FAIL=$3
	unset -v RESULT

	log_debug "dashboard" "Pushing task [$TASK_GOAL] succ [$TASK_SUCC] fail [$TASK_FAIL] to tasks file ..."
	if ! [ -n "$TASK_GOAL" -a -n "$TASK_SUCC" -a -n "$TASK_FAIL" ]
	then
		log_debug "dashboard" "Pushing task [$TASK_GOAL] [$TASK_SUCC] [$TASK_FAIL] to tasks file failed (Task is not correct)"
		return 1
	fi

	{
		"$FLOCK" -x 200
		local TASK_ID=$($DATE '+%s%N')

		if echo "$TASK_ID" "$(echo $TASK_GOAL | $BASE64 -w 0)" "$(echo $TASK_SUCC | $BASE64 -w 0)" "$(echo $TASK_FAIL | $BASE64 -w 0)" >> "$TASKS_FILE"
		then
			RESULT=$TASK_ID
			log_debug "dashboard" "Pushing task [$TASK_GOAL] succ [$TASK_SUCC] fail [$TASK_FAIL] to tasks file ok"
			return 0
		else
			log_debug "dashboard" "Pushing task [$TASK_GOAL] succ [$TASK_SUCC] fail [$TASK_FAIL] to tasks file failed ($?)"
			return 2	
		fi
	} 200<"$TASKS_FILE"
}

## 
## Removes tasks from tasks file
##
## Params:
##	$1 - Task id
##
## Returns:
##  0 - on success
##  1 - on empty task id
##  2 - on task is not found
##  3 - on task is found but not removed
##
dashboard_remove_task()
{
	local TASK_ID=$1

	log_debug "dashboard" "Removing task [$TASK_ID] from tasks file ..."
	if ! [ -n "$TASK_ID" ]
	then
		log_debug "dashboard" "Removing task [$TASK_ID] from tasks file failed (TASK_ID is empty)"
		return 1
	fi

	{
		"$FLOCK" -x 200
		if "$GREP" -e "^$TASK_ID\\s" "$TASKS_FILE" 1>/dev/null
		then
			if "$SED" -i "/^$TASK_ID\\s/d" "$TASKS_FILE"
			then
				log_debug "dashboard" "Removing task [$TASK_ID] from tasks file ok"
				return 0
			else
				log_debug "dashboard" "Removing task [$TASK_ID] from tasks file failed (Task is not removed)"
				return 3
			fi
		else
			log_debug "dashboard" "Removing task [$TASK_ID] from tasks file failed (Task is not found)"
			return 2
		fi
	} 200<"$TASKS_FILE" 
}

## 
## Get task info from tasks file
##
## Params:
##	$1 - Task id
##
## Returns:
##  0 - on success
##  1 - on empty task id
##  2 - on task is not found
## 
## Exports:
##	RESULT - Array with task info
##
dashboard_get_task()
{
	local TASK_ID=$1
	unset -v RESULT

	log_debug "dashboard" "Getting task [$TASK_ID] from tasks file ..."
	if ! [ -n "$TASK_ID" ]
	then
		log_debug "dashboard" "Getting task [$TASK_ID] from tasks file failed (TASK_ID is empty)"
		return 1
	fi

	{
		"$FLOCK" -x 200
		while read -a TASK 
		do
			if [ "$TASK_ID" = "${TASK[0]}" ]
			then
				local TASK_GOAL=$(echo ${TASK[1]}| $BASE64 --decode)
				local TASK_SUCC=$(echo ${TASK[2]}| $BASE64 --decode)
				local TASK_FAIL=$(echo ${TASK[3]}| $BASE64 --decode)
				RESULT=("${TASK[0]}" "$TASK_GOAL" "$TASK_SUCC" "$TASK_FAIL")
				log_debug "dashboard" "Getting task [$TASK_ID] from tasks file ok"
				return 0
			fi
		done 0<"$TASKS_FILE"
		log_debug "dashboard" "Getting task [$TASK_ID] from tasks file failed (Task is not found)"
		return 2
	} 200<"$TASKS_FILE" 
}

## 
## Get all tasks info from tasks file
##
## Returns:
##  0 - on success
##
## Exports:
##	RESULT - Ids of tasks
##
dashboard_get_tasks_ids()
{
	unset -v RESULT

	log_debug "dashboard" "Getting all tasks ids from tasks file ..."
	{
		"$FLOCK" -x 200
		while read -a TASK 
		do
			RESULT=("${RESULT[@]}" "${TASK[0]}")
		done 0<"$TASKS_FILE"
	} 200<"$TASKS_FILE" 
	log_debug "dashboard" "Getting all tasks ids [${#RESULT[@]}] from tasks file ok"
	return 0
}

##
## Prints scripts usage to stdout
##
dashboard_print_usage()
{
	echo "Usage: $0 start|stop|status|add-task|remove-task|list-tasks"
	echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL]"
	echo "       $0 remove-task TASK_ID"
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"status")
		log_info "dashboard" "Running [$ACTION] command ..." 

		echo "Getting workers status ..." 
		if workers_pids 
		then 
			echo "Workers are running"
		else 
			echo "Workers are not running"
		fi

		echo "Getting tasks queue status ..." 
		if tasksqueue_pid
		then 
			echo "Tasks queue is running"
		else
			echo "Tasks queue is not running"
		fi

		log_info "dashboard" "Running [$ACTION] command ok" 
		;;
	"start")
		log_info "dashboard" "Running [$ACTION] command ..." 

		echo "Staring tasks queue ..."
		if tasksqueue_start 
		then
			echo "Staring tasks queue ok"
		else 
			echo "Staring tasks queue failed"
		fi

		echo "Staring [$PARALLEL_TASKS] workers..."
		if workers_start "$PARALLEL_TASKS"
		then
			echo "Staring [$PARALLEL_TASKS] workers ok"
		else 
			echo "Staring [$PARALLEL_TASKS] workers failed"
		fi

		log_info "dashboard" "Running [$ACTION] command ok" 
		;;
	"stop")
		log_info "dashboard" "Running [$ACTION] command ..." 

		echo "Stopping tasks queue..."
		if tasksqueue_stop 
		then 
			echo "Stopping tasks queue ok"
		else
			echo "Stopping tasks queue failed"
		fi
	
		echo "Stopping workers..."
		if workers_stop 
		then
			echo "Stopping workers ok"
		else
			echo "Stopping workers failed"
		fi

		log_info "dashboard" "Running [$ACTION] command ok"
		;;
	"add-task")
		log_info "dashboard" "Running [$ACTION] command ..." 

		TASK_SUCC=$FALSE
		TASK_FAIL=$FALSE

		# Fill options
		while [ -n "$1" ]
		do
			case $1 in 
				"task")
					TASK_GOAL=$2
					shift; shift
					;;
				"success")
					TASK_SUCC=$2
					shift; shift
					;;
				"fail")
					TASK_FAIL=$2
					shift; shift
					;;
				*)		
					dashboard_print_usage
					exit 1
					;;
			esac
		done

		if ! [ -n "$TASK_GOAL" -a -n "$TASK_SUCC" -a -n "$TASK_FAIL" ]
		then
			log_info "dashboard" "Running [$ACTION] command failed (Invalid arguments)" 
			dashboard_print_usage
			exit 1
		fi
		
		if dashboard_push_task "$TASK_GOAL" "$TASK_SUCC" "$TASK_FAIL" 
		then
			TASK_ID=$RESULT
			log_info "dashboard" "Running [$ACTION] command ok" 
			echo "Task [$TASK_ID]"
			exit 0
		else
			log_info "dashboard" "Running [$ACTION] command failed (Pushing task failed)" 
			echo "Task []"
			exit 2
		fi
		;;
	"remove-task")
		log_info "dashboard" "Running [$ACTION] command ..." 

		TASK_ID=$1
		shift
		if ! [ -n "$TASK_ID" ]
		then
			dashboard_print_usage
			exit 1
		fi

		log_info "dashboard" "Removing task [$TASK_ID] from tasks file ..."
		if dashboard_remove_task "$TASK_ID"
		then
			log_info "dashboard" "Running [$ACTION] command ok" 
			echo "Removing task [$TASK_ID] from tasks file ok"
			exit 0
		else
			log_info "dashboard" "Running [$ACTION] command failed (Removing task failed)" 
			echo "Removing task [$TASK_ID] from tasks file failed"
			exit 2
		fi
		;;
	"list-tasks")
		log_info "dashboard" "Running [$ACTION] command ..." 
		if dashboard_get_tasks_ids
		then
			for TASK_ID in "${RESULT[@]}"
			do
				if dashboard_get_task "$TASK_ID"
				then
					TASK_GOAL=${RESULT[1]}
					TASK_SUCC=${RESULT[2]}
					TASK_FAIL=${RESULT[3]}
					echo "Task '$TASK_ID': [$TASK_GOAL] success [$TASK_SUCC] fail [$TASK_FAIL]"
				fi
			done
			log_info "dashboard" "Running [$ACTION] command ok" 
			exit 0
		else
			echo "Removing task [$TASK_ID] from tasks file failed (Getting task ids failed)"
			exit 1
		fi
		;;
	*)
		dashboard_print_usage
		;;
esac
