#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]
then 
	source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]
then 
	source /etc/yastq.conf
else 
	echo "Config file not found"
	exit 1
fi

# Check existance of common code
if [[ -e $SCRIPT_COMMON ]]
then
	source $SCRIPT_COMMON
else
	echo "Common file not found"
	exit 1
fi

function log_manager() {
	echo "$($DATE +'%F %T') (manager) $1"
	echo "$($DATE +'%F %T') (manager) $1" >> $LOG_MANAGER
}

function show_status() {
	echo "Running $($CAT $WORKERS_PIDS_FILE 2>/dev/null | $WC -w) workers"
}

function start_workers() {
	if ! [[ -e $WORKERS_PIDS_FILE ]]
	then
		log_manager "Starting sheduler workers"
		echo -n "" > $WORKERS_PIDS_FILE
		for ((i=1; i<=$MAX_PARALLEL_SHEDULES; i++))
		do
			log_manager "Starting new worker"

			# Run worker script with nohup
			$NOHUP $SCRIPT_WORKER > /dev/null 2>&1 &
			echo -n "$! " >> $WORKERS_PIDS_FILE
		done
	else
		log_manager "Sheduler is already running"
	fi
}

function stop_workers() {
	if [[ -e $WORKERS_PIDS_FILE ]]
	then
		log_manager "Sending TERM signal to workers"
		$KILL -TERM $($CAT $WORKERS_PIDS_FILE)

		log_manager "Waiting for workers"
		wait_workers
		
		log_manager "All workers done"
		$RM -f $WORKERS_PIDS_FILE
	else
		log_manager "Sheduler is not running"
	fi
}

function wait_workers() {
	while [[ ${?} == 0 ]]
	do
	    $SLEEP 1s
	    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
	done
}

function start_tasks_queue() {
	if ! [[ -e $TASKS_QUEUE_PID_FILE ]]
	then
		log_manager "Starting new tasks queue"

		# Run tasks queue script with nohup
		$NOHUP $SCRIPT_TASKS_QUEUE > /dev/null 2>&1 &
		echo -n "$!" > $TASKS_QUEUE_PID_FILE
	else
		log_manager "Tasks queue is already running"
	fi
}

function stop_tasks_queue() {
	if [[ -e $TASKS_QUEUE_PID_FILE ]]
	then
		log_manager "Sending kill signal to tasks queue"
		$KILL -TERM $($CAT $TASKS_QUEUE_PID_FILE)
		$RM -f $TASKS_QUEUE_PID_FILE
	else
		log_manager "Tasks queue is not running"
	fi
}

function free_tasks_queue() {
	if [[ -e $TASKS_QUEUE_PID_FILE ]]
	then
		log_manager "Sending USR1 signal to tasks queue"
		$KILL -USR1 $($CAT $TASKS_QUEUE_PID_FILE)
	else
		log_manager "Tasks queue is not running"
	fi
}

function append_tasks_queue() {
	log_manager "Adding task '$1' with success '$2' and fail '$3' to tasks queue"

	echo $(echo $1 | $BASE64) $(echo $2 | $BASE64) $(echo $3 | $BASE64) >> $TASKS_QUEUE_FILE
}

function print_usage() {
	echo "Usage: yastq.sh start|stop|status|add-task"
	echo "       yastq.sh add-task task TASK [success SUCCESS] [fail FAIL]"
}

# Currect action
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
		while [[ -n "$1" ]]
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
		if [[ -n "$TASK" ]]
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
