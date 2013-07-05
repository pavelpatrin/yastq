#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]; then source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Include common code
source $SCRIPT_DIR/common.sh

function log_manager() {
	echo "(manager) $1" | $TS
	echo "(manager) $1" | $TS >> $LOG_MANAGER
}

function show_status() {
	echo "Running $($CAT $WORKERS_PIDS_FILE 2>/dev/null | $WC -w) workers"
}

function start_workers() {
	# Max of parallels tasks (detected by count cpu cores)
	local MAX_PARALLEL_SHEDULES=$($GREP processor /proc/cpuinfo | $WC -l)
	log_manager "Detected $MAX_PARALLEL_SHEDULES CPU cores"

	if ! [[ -e $WORKERS_PIDS_FILE ]]
	then
		log_manager "Starting sheduler workers"
		echo -n "" > $WORKERS_PIDS_FILE
		for ((i=1; i<=$MAX_PARALLEL_SHEDULES; i++))
		do
			# Log about start
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
		log_manager "Sending stop signal to workers"
		$KILL -15 $($CAT $WORKERS_PIDS_FILE)

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
	    sleep 1 
	    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
	done
}

function start_tasks_queue() {
	if ! [[ -e $TASKS_QUEUE_PID_FILE ]]
	then
		# Log about start
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
		$KILL -9 $($CAT $TASKS_QUEUE_PID_FILE)
		$RM -f $TASKS_QUEUE_PID_FILE
	else
		log_manager "Tasks queue is not running"
	fi
}

function free_tasks_queue() {
	if [[ -e $TASKS_QUEUE_PID_FILE ]]
	then
		log_manager "Sending USR1 signal to tasks queue"
		$KILL -10 $($CAT $TASKS_QUEUE_PID_FILE)
	else
		log_manager "Tasks queue is not running"
	fi
}

function append_tasks_queue() {
	read COMMAND
	echo $COMMAND >> $TASKS_QUEUE_FILE
}

case $1 in 
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
		append_tasks_queue
		;;
	*)
		echo "Usage: manager.sh start|stop|status|add-task"
		;;
esac
