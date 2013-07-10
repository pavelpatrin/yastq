#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

log_manager() {
	echo "$($DATE +'%F %T') (manager) $1" >> $LOG_MANAGER
}

start_workers() {
	if ! [ -e "$WORKERS_PIDS_FILE" ]
	then
		log_manager "Starting new workers"

		echo > $WORKERS_PIDS_FILE
		for ((i=1; i<=$MAX_PARALLEL_SHEDULES; i++))
		do
			log_manager "Starting new worker"

			# Run worker script
			$SCRIPT_WORKER > /dev/null 2>&1 &
			echo -n "$! " >> $WORKERS_PIDS_FILE

			log_manager "Worker $! has starded"
		done
		
		log_manager "All workers started"
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
		$PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
		while [ "${?}" = 0 ]
		do
		    $SLEEP 1s
		    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
		done
		
		log_manager "All workers done"
		$RM -f $WORKERS_PIDS_FILE
	else
		log_manager "Workers are not running"
	fi
}

stop_manager() {
	log_manager "Manager stopping"
	stop_workers
	exit
}

# ON TERM exiting
trap 'stop_manager' TERM

# Log about start
log_manager "Manager started"

# Start workers
start_workers

# Open descriptor to tasks file
exec 3<>$MANAGER_TASKS_FILE

# Infinitie loop
while [ 0 ]
do
	# Unset previous task
	unset -v TASK

	# Read new task from tasks file descriptor
	read -r -u 3 TASK

	# If task is not empty
	if [ -n "$TASK" ]
	then
		# Log action 
		log_manager "Sending base64 task '$TASK' to pipe"

		# Send new task to pipe
		echo $TASK > $MANAGER_TASKS_PIPE

		# Remove task from tasks file
		$SED -i 1d $MANAGER_TASKS_FILE
	else
		# Sleep if no task received
		$SLEEP 1s
	fi
done

log_manager "Manager stopped"
