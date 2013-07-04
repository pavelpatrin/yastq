#!/bin/bash

# Include common code
source `dirname $0`/common.sh

function show_status() {
	echo "Delayed $($WC -l $QUEUE_DELAYED_FILE | $CUT -f 1 -d " ") tasks"
	echo "Complete $($WC -l $QUEUE_COMPLETE_FILE | $CUT -f 1 -d " ") tasks"
	echo "Failed $($WC -l $QUEUE_FAILED_FILE | $CUT -f 1 -d " ") tasks"
}

function stop_workers() {
	if [[ -e $WORKERS_PIDS_FILE ]]; then
		log_master "Sending stop signal to workers"
		$KILL -15 $($CAT $WORKERS_PIDS_FILE)

		log_master "Waiting for workers"
		wait_workers
		
		log_master "All workers done"
		$RM -f $WORKERS_PIDS_FILE
	else
		log_master "Sheduler is not running"
	fi
}

function wait_workers() {
	while [[ ${?} == 0 ]] 
	do
	    sleep 1 
	    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
	done
}

function start_workers() {
	if ! [[ -e $WORKERS_PIDS_FILE ]]; then
		log_master "Starting sheduler workers ($MAX_PARALLEL_SHEDULES)"
		echo -n "" > $WORKERS_PIDS_FILE
		for (( i=1; i<=$MAX_PARALLEL_SHEDULES; i++ ))
		do
			eval "worker.sh &"
			echo -n "$! " >> $WORKERS_PIDS_FILE
			log_master "Started worker $!"
		done
	else
		log_master "Sheduler is already running"
	fi
}

function start_tasks_queue() {
	eval "queue.sh &"
	echo -n "$! " >> $TASKS_QUEUE_PID_FILE

	if [[ -e $TASKS_QUEUE_PID_FILE ]]; then
		log_master "Starting tasks queue"
		echo -n "$!" > $TASKS_QUEUE_PID_FILE
	else
		log_master "Tasks queue is already running"
	fi
}

function stop_tasks_queue() {
	if [[ -e $TASKS_QUEUE_PID_FILE ]]; then
		log_master "Sending kill signal to tasks queue"
		$KILL -9 $($CAT $TASKS_QUEUE_PID_FILE)
		$RM -f $TASKS_QUEUE_PID_FILE
	else
		log_master "Tasks queue is not running"
	fi
}

function append_queue() {
	read COMMAND
	echo $COMMAND >> $QUEUE_DELAYED_FILE
}

case $1 in 
	"start")
		start_workers
		start_tasks_queue
		;;
	"stop")
		stop_workers
		stop_tasks_queue
		;;
	"status")
		show_status
		;;
	"add-task")
		append_queue
		;;
	*)
		echo "Usage: master.sh start|stop|status|add-task"
		;;
esac
