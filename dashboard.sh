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

	if ! [ -e "$WORKERS_PID_FILE" ]
	then 
		return 1
	fi

	local WORKERS_PIDS
	read -r WORKERS_PIDS 0<"$WORKERS_PID_FILE"
	if ! "$PS" -p $WORKERS_PIDS 2>/dev/null 1>/dev/null
	then
		return 1
	fi

	RESULT=$WORKERS_PIDS
	return 0
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

	if workers_pids
	then
		return 1
	fi

	local WORKERS_PIDS
	for ((i=1; i<=$WORKERS_COUNT; i++))
	do
		# Start worker with nohup
		"$NOHUP" "$WORKER_SCRIPT_FILE" 2>/dev/null 1>/dev/null &

		# Save worker pid
		WORKERS_PIDS="$WORKERS_PIDS $!"
	done

	# Store workers pids into pidfile
	echo $WORKERS_PIDS 1>"$WORKERS_PID_FILE"
	return 0
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
	if workers_pids
	then
		# Sending term signal to workers
		"$KILL" -s SIGTERM $RESULT 1>/dev/null

		# Waiting for workers exiting
		while "$PS" -p $RESULT 1>/dev/null
		do
		    "$SLEEP" 1s
		done
		
		# Removing pids file
		"$RM" -f "$WORKERS_PID_FILE"
		return 0
	fi
	
	return 1
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

	if ! [ -e "$TASKSQUEUE_PID_FILE" ]
	then 
		return 1
	fi

	local TASKSQUEUE_PID
	read -r TASKSQUEUE_PID 0<"$TASKSQUEUE_PID_FILE"

	if ! "$PS" -p $TASKSQUEUE_PID 2>/dev/null 1>/dev/null
	then
		return 1
	fi

	RESULT=$TASKSQUEUE_PID
	return 0
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
	if tasksqueue_pid
	then
		return 1
	fi

	"$NOHUP" "$TASKSQUEUE_SCRIPT_FILE" 2>/dev/null 1>/dev/null &
	echo $! 1>"$TASKSQUEUE_PID_FILE"
	return 0
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
	if tasksqueue_pid
	then
		# Sending term signal to workers
		"$KILL" -s SIGTERM $RESULT 1>/dev/null

		# Waiting tasksqueue exiting
		while "$PS" -p $RESULT 1>/dev/null
		do
		    "$SLEEP" 1s
		done

		# Remove pids file
		"$RM" -f "$TASKSQUEUE_PID_FILE"
		return 0
	fi

	return 1
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
	local TASK_MAIN=$1
	local TASK_SUCC=$2
	local TASK_FAIL=$3
	unset -v RESULT

	if ! [ -n "$TASK_MAIN" -a -n "$TASK_SUCC" -a -n "$TASK_FAIL" ]
	then
		return 1
	fi

	# Obtain exclusive lock
	{
		"$FLOCK" -x 200
		local TASK_ID=$($DATE '+%s%N')
		if echo "$TASK_ID" "$(echo $TASK_MAIN | $BASE64 -w 0)" "$(echo $TASK_SUCC | $BASE64 -w 0)" "$(echo $TASK_FAIL | $BASE64 -w 0)" >> "$TASKS_FILE"
		then
			RESULT=$TASK_ID
			return 0
		else
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

	if ! [ -n "$TASK_ID" ]
	then
		return 1
	fi

	# Obtain exclusive lock
	{
		"$FLOCK" -x 200
		if "$GREP" -e "^$TASK_ID\\s" "$TASKS_FILE" 1>/dev/null
		then
			if "$SED" -i "/^$TASK_ID\\s/d" "$TASKS_FILE"
			then
				return 0
			else
				return 3
			fi
		else
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
## 
## Exports:
##	RESULT - Array with task info
##
dashboard_get_task()
{
	local TASK_ID=$1
	unset -v RESULT

	if ! [ -n "$TASK_ID" ]
	then
		return 1
	fi

	# Obtain exclusive lock
	{
		"$FLOCK" -x 200
		while read -a TASK 
		do
			if [ "$TASK_ID" = "${TASK[0]}" ]
			then
				local TASK_MAIN=$(echo ${TASK[1]}| $BASE64 --decode)
				local TASK_SUCC=$(echo ${TASK[2]}| $BASE64 --decode)
				local TASK_FAIL=$(echo ${TASK[3]}| $BASE64 --decode)
				RESULT=("${TASK[0]}" "$TASK_MAIN" "$TASK_SUCC" "$TASK_FAIL")
				return 0
			fi
		done 0<"$TASKS_FILE"
	} 200<"$TASKS_FILE" 
	return 0
}

## 
## Get all tasks info from tasks file
##
## Returns:
##  0 - on success
##	1 - on empty task id
##
## Exports:
##	RESULT - Ids of tasks
##
dashboard_get_tasks_ids()
{
	unset -v RESULT

	# Obtain exclusive lock
	{
		"$FLOCK" -x 200
		while read -a TASK 
		do
			RESULT=("${RESULT[@]}" "${TASK[0]}")
		done 0<"$TASKS_FILE"
	} 200<"$TASKS_FILE" 
	return 0
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		echo "Staring tasks queue..."
		if tasksqueue_start 
		then
			echo "Staring tasks queue ok" 
		else 
			echo "Staring tasks queue failed ($?)"
		fi

		echo "Staring $PARALLEL_TASKS workers..."
		if workers_start "$PARALLEL_TASKS"
		then
			echo "Staring $PARALLEL_TASKS workers ok" 
		else 
			echo "Staring $PARALLEL_TASKS workers failed ($?)"
		fi
		;;
	"stop")
		echo "Stopping tasks queue..."
		if tasksqueue_stop 
		then 
			echo "Stopping tasks queue ok" 
		else
			echo "Stopping tasks queue failed ($?)"
		fi
	
		echo "Stopping workers..."
		if workers_stop 
		then
			echo "Stopping workers ok" 
		else
			echo "Stopping workers failed ($?)"
		fi
		;;
	"status")
		if workers_pids 
		then 
			echo "Workers are running" 
		else 
			echo "Workers are not running"
		fi

		if tasksqueue_pid
		then 
			echo "Tasks queue is running" 
		else
			echo "Tasks queue is not running"
		fi
		;;
	"add-task")
		TASK_SUCC=$FALSE
		TASK_SUCC=$FALSE

		# Fill options
		while [ -n "$1" ]
		do
			case $1 in 
				"task")
					TASK_MAIN=$2
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
					echo "Skipping invalid option $1"; 
					shift
					;;
			esac
		done

		# Append task or show usage
		if ! [ -n "$TASK_MAIN" ]
		then
			echo "Adding task failed (task is empty)"
			exit 1
		fi
		
		# 	
		echo "Adding task [$TASK_MAIN] with SUCC [$TASK_SUCC] and FAIL [$TASK_FAIL]" 
		if dashboard_push_task "$TASK_MAIN" "$TASK_SUCC" "$TASK_FAIL" 
		then
			echo "Adding task ok"
			exit 0
		else
			echo "Adding task failed ($?)"
			exit 2
		fi
		;;
	"remove-task")
		TASK_ID=$1
		shift

		if ! [ -n "$TASK_ID" ]
		then
			echo "Removing task failed (TASK_ID is empty)"
			exit 1
		fi

		if dashboard_remove_task "$TASK_ID"
		then
			echo "Task '$TASK_ID': removing task ok"
			exit 0
		else
			echo "Task '$TASK_ID': removing task failed ($?)"
			exit 2
		fi
		;;
	"show-task")
		TASK_ID=$1
		shift

		if ! [ -n "$TASK_ID" ]
		then
			echo "Showing task failed (TASK_ID is empty)"
			exit 1
		fi

		if dashboard_get_task "$TASK_ID"
		then
			TASK_MAIN=${RESULT[1]}
			TASK_SUCC=${RESULT[2]}
			TASK_FAIL=${RESULT[3]}
			echo "Task '$TASK_ID': task is [$TASK_MAIN] success [$TASK_SUCC] fail [$TASK_FAIL]"
			exit 0
		else
			echo "Task '$TASK_ID': task is not found"
			exit 2
		fi
		;;
	"list-tasks")
		if dashboard_get_tasks_ids
		then
			for TASK_ID in "${RESULT[@]}"
			do
				if dashboard_get_task "$TASK_ID"
				then
					TASK_MAIN=${RESULT[1]}
					TASK_SUCC=${RESULT[2]}
					TASK_FAIL=${RESULT[3]}
					echo "Task '$TASK_ID': task is [$TASK_MAIN] success [$TASK_SUCC] fail [$TASK_FAIL]"
				else 
					echo "Task '$TASK_ID': showing task failed ($?)"
				fi
			done
			exit 0
		else
			echo "Getting list of tasks ids failed"
			exit 1
		fi
		;;
	*)
		echo "Usage: $0 start|stop|status|add-task|show-task|remove-task|list-tasks"
		echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL]"
		echo "       $0 remove-task TASK_ID"
		echo "       $0 show-task TASK_ID"
		;;
esac
