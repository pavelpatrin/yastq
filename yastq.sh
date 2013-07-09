#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

log_manager() {
	echo "$($DATE +'%F %T') (manager) $1"
	echo "$($DATE +'%F %T') (manager) $1" >> $LOG_MANAGER
}

show_status() {
	echo "Running $($CAT $WORKERS_PIDS_FILE 2>/dev/null | $WC -w) workers"
}

start_workers() {
	if ! [ -e "$WORKERS_PIDS_FILE" ]
	then
		log_manager "Starting new workers"
		echo -n "" > $WORKERS_PIDS_FILE
		for ((i=1; i<=$MAX_PARALLEL_SHEDULES; i++))
		do
			log_manager "Starting new worker"

			# Run worker script with nohup
			$NOHUP $SCRIPT_WORKER > /dev/null 2>&1 &
			echo -n "$! " >> $WORKERS_PIDS_FILE
		done
	else
		log_manager "Workers are already running"
	fi
}

stop_workers() {
	if [ -e "$WORKERS_PIDS_FILE" ]
	then
		log_manager "Sending TERM signal to workers"
		$KILL -TERM $($CAT $WORKERS_PIDS_FILE)

		log_manager "Waiting for workers"
		wait_workers
		
		log_manager "All workers done"
		$RM -f $WORKERS_PIDS_FILE
	else
		log_manager "Workers are not running"
	fi
}

wait_workers() {
	while [ "${?}" = 0 ]
	do
	    $SLEEP 1s
	    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
	done
}

start_tasks_queue() {
	if ! [ -e "$TASKS_QUEUE_PID_FILE" ]
	then
		log_manager "Starting new tasks queue"

		# Run tasks queue script with nohup
		$NOHUP $SCRIPT_TASKS_QUEUE > /dev/null 2>&1 &
		echo -n "$!" > $TASKS_QUEUE_PID_FILE
	else
		log_manager "Tasks queue is already running"
	fi
}

stop_tasks_queue() {
	if [ -e "$TASKS_QUEUE_PID_FILE" ]
	then
		log_manager "Sending kill signal to tasks queue"
		$KILL -TERM $($CAT $TASKS_QUEUE_PID_FILE)
		$RM -f $TASKS_QUEUE_PID_FILE
	else
		log_manager "Tasks queue is not running"
	fi
}

free_tasks_queue() {
	if [ -e "$TASKS_QUEUE_PID_FILE" ]
	then
		log_manager "Sending USR1 signal to tasks queue"
		$KILL -USR1 $($CAT $TASKS_QUEUE_PID_FILE)
	else
		log_manager "Tasks queue is not running"
	fi
}

append_tasks_queue() {
	local TASK=$1
	local SUCC=$2
	local FAIL=$3

	log_manager "Adding task '$TASK' with success '$SUCC' and fail '$FAIL' to tasks queue"

	local TASK_ID=$($DATE '+%s%N')
	echo $TASK_ID $(echo $TASK | $BASE64 -w 0) $(echo $SUCC | $BASE64 -w 0) $(echo $FAIL | $BASE64 -w 0) >> $TASKS_QUEUE_FILE

	log_manager "Added new task with ID $TASK_ID"
}

remove_task_from_queue() {
	local TASK_ID=$1
	log_manager "Removing task $TASK_ID"

	# Remove task from queue
	$SED -i '/^'$TASK_ID'\s/d' $TASKS_QUEUE_FILE 2>&1 > /dev/null
}

print_usage() {
	echo "Usage: yastq.sh start|stop|status|add-task"
	echo "       yastq.sh add-task task TASK [success SUCCESS] [fail FAIL]"
}

# Current action
ACTION=$1
shift

case $ACTION in 
	"start")
		start_workers
		start_tasks_queue
		;;
	"stop")
		free_tasks_queue
		stop_workers
		stop_tasks_queue
		;;
	"status")
		show_status
		;;
	"add-task")
		SUCCESS=$FALSE
		FAIL=$FALSE

		# Fill options
		while [ -n "$1" ]
		do
			case $1 in 
				"task")
					TASK=$2
					shift; shift
					;;
				"success")
					SUCCESS=$2
					shift; shift
					;;
				"fail")
					FAIL=$2
					shift; shift
					;;
				*)		
					log_manager "Skipping invalid option $1"; 
					shift
					;;
			esac
		done

		# Append task or show usage
		if [ -n "$TASK" ]
		then
			append_tasks_queue "$TASK" "$SUCCESS" "$FAIL"
		else
			print_usage
		fi
		;;
	*)
		print_usage
		;;
esac
