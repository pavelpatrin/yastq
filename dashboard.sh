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
	if ps -p $WORKERS_PIDS 2>/dev/null 1>/dev/null
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
			nohup "$WORKER_SCRIPT_FILE" 2>/dev/null 1>/dev/null &
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
		local WORKERS_PIDS=$RESULT
		kill -s SIGTERM $WORKERS_PIDS 1>/dev/null
		while ps -p $WORKERS_PIDS 1>/dev/null
		do
		    sleep 1s
		done
		rm -f "$WORKERS_PID_FILE"
		log_debug "dashboard" "Stopping workers [$WORKERS_PIDS] ok"
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
	if ps -p $TASKSQUEUE_PID 2>/dev/null 1>/dev/null
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
		nohup "$TASKSQUEUE_SCRIPT_FILE" 2>/dev/null 1>/dev/null &
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
		kill -s SIGTERM $TASKSQUEUE_PID 1>/dev/null
		while ps -p $TASKSQUEUE_PID 1>/dev/null
		do 
			sleep 1s; 
		done
		rm -f "$TASKSQUEUE_PID_FILE"
		log_debug "dashboard" "Stopping tasksqueue [$TASKSQUEUE_PID] ok"
		return 0
	else
		log_debug "dashboard" "Stopping tasksqueue failed (Tasksqueue is not running)"
		return 1
	fi
}

##
## Prints scripts usage to stdout
##
dashboard_print_usage()
{
	echo "Usage: $0 start|stop|status"
	echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL] [--append-id-task] [--append-id-success] [--append-id-fail]"
	echo "       $0 show-task TASK_ID"
	echo "       $0 remove-task TASK_ID"
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		log_info "dashboard" "Staring tasks queue ..." 
		echo "Staring tasks queue ..."
		if tasksqueue_start 
		then
			log_info "dashboard" "Staring tasks queue ok" 
			echo "Staring tasks queue ok"
		else 
			log_info "dashboard" "Staring tasks queue failed" 
			echo "Staring tasks queue failed"
		fi

		log_info "dashboard" "Staring [$PARALLEL_TASKS] workers..." 
		echo "Staring [$PARALLEL_TASKS] workers..." 
		if workers_start "$PARALLEL_TASKS"
		then
			log_info "dashboard" "Staring [$PARALLEL_TASKS] workers ok"
			echo "Staring [$PARALLEL_TASKS] workers ok"
		else 
			log_info "dashboard" "Staring [$PARALLEL_TASKS] workers failed" 
			echo "Staring [$PARALLEL_TASKS] workers failed"
		fi
		;;
	"stop")
		log_info "dashboard" "Stopping tasks queue ..."
		echo "Stopping tasks queue ..." 
		if tasksqueue_stop 
		then 
			log_info "dashboard" "Stopping tasks queue ok" 
			echo "Stopping tasks queue ok"
		else
			log_info "dashboard" "Stopping tasks queue failed" 
			echo "Stopping tasks queue failed"
		fi
	
		log_info "dashboard" "Stopping workers ..."
		echo "Stopping workers ..." 
		if workers_stop 
		then
			log_info "dashboard" "Stopping workers ok" 
			echo "Stopping workers ok"
		else
			log_info "dashboard" "Stopping workers failed" 
			echo "Stopping workers failed"
		fi
		;;
	"status")
		log_info "dashboard" "Getting workers status ..."
		echo "Getting workers status ..."
		if workers_pids 
		then 
			log_info "dashboard" "Workers are running" 
			echo "Workers are running"
		else 
			log_info "dashboard" "Workers are not running" 
			echo "Workers are not running"
		fi

		log_info "dashboard" "Getting tasks queue status ..."
		echo "Getting tasks queue status ..."
		if tasksqueue_pid
		then 
			log_info "dashboard" "Tasks queue is running" 
			echo "Tasks queue is running"
		else
			log_info "dashboard" "Tasks queue is not running" 
			echo "Tasks queue is not running"
		fi
		;;
	"add-task")
		TASK_SUCC=false
		TASK_FAIL=false
		unset -v TASK_OPTIONS

		while [ -n "$1" ]
		do
			case $1 in 
				"task")
					TASK_GOAL=$2; shift; shift
					;;
				"success")
					TASK_SUCC=$2; shift; shift
					;;
				"fail")
					TASK_FAIL=$2; shift; shift
					;;
				"--append-id-task")
					TASK_OPTIONS=( "${TASK_OPTIONS[@]}" "APPEND_ID_TASK" ); shift
					;;
				"--append-id-success")
					TASK_OPTIONS=( "${TASK_OPTIONS[@]}" "APPEND_ID_SUCC" ); shift
					;;
				"--append-id-fail")
					TASK_OPTIONS=( "${TASK_OPTIONS[@]}" "APPEND_ID_FAIL" ); shift
					;;
				*)		
					dashboard_print_usage
					exit 1
					;;
			esac
		done

		TASK_OPTIONS=$(IFS=:; echo "${TASK_OPTIONS[*]}")

		if ! [ -n "$TASK_GOAL" -a -n "$TASK_SUCC" -a -n "$TASK_FAIL" ]
		then
			dashboard_print_usage
			exit 1
		fi
		
		log_info "dashboard" "Adding task [$TASK_GOAL][$TASK_SUCC][$TASK_FAIL] ..." 
		if queuedb_push "$TASK_GOAL" "$TASK_SUCC" "$TASK_FAIL" "$TASK_OPTIONS"
		then
			TASK_ID=$RESULT
			log_info "dashboard" "Adding task [$TASK_GOAL][$TASK_SUCC][$TASK_FAIL] with options [$TASK_OPTIONS] ok (Task added with id [$TASK_ID])"
			echo "Adding task [$TASK_GOAL][$TASK_SUCC][$TASK_FAIL] with options [$TASK_OPTIONS] ok (Task added with id [$TASK_ID])" 
			exit 0
		else
			log_info "dashboard" "Adding task [$TASK_GOAL][$TASK_SUCC][$TASK_FAIL] with options [$TASK_OPTIONS] failed (Push failed with code [$?])"
			echo "Adding task [$TASK_GOAL][$TASK_SUCC][$TASK_FAIL] with options [$TASK_OPTIONS] failed (Push failed with code [$?])"
			exit 2
		fi
		;;
	"remove-task")
		TASK_ID=$1
		if ! [ -n "$TASK_ID" ]
		then
			dashboard_print_usage
			exit 1
		fi

		log_info "dashboard" "Removing task [$TASK_ID] ..."
		if queuedb_remove "$TASK_ID"
		then
			log_info "dashboard" "Removing task [$TASK_ID] ok" 
			echo "Removing task [$TASK_ID] ok" 
			exit 0
		else
			log_info "dashboard" "Removing task [$TASK_ID] failed (Remove failed with code [$?])" 
			echo "Removing task [$TASK_ID] failed (Remove failed with code [$?])"
			exit 2
		fi
		;;
	"show-task")
		TASK_ID=$1
		if ! [ -n "$TASK_ID" ]
		then
			dashboard_print_usage
			exit 1
		fi

		log_info "dashboard" "Showing task [$TASK_ID] ..."
		if queuedb_find "$TASK_ID"
		then
			log_info "dashboard" "Showing task [$TASK_ID] ok" 
			echo "Task '$TASK_ID': [${RESULT[1]}] success [${RESULT[2]}] fail [${RESULT[3]}]"
			exit 0
		else
			log_info "dashboard" "Showing task [$TASK_ID] failed (Find failed with code [$?])"
			echo "Task '$TASK_ID': Not found"
			exit 1
		fi
		;;
	*)
		dashboard_print_usage
		;;
esac
