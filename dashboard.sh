#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

log_dashboard() {
	echo "$($DATE +'%F %T') (dashboard) $1"
	echo "$($DATE +'%F %T') (dashboard) $1" >> $LOG_DASHBOARD
}

show_status() {
	echo "Running $($CAT $WORKERS_PIDS_FILE 2>/dev/null | $WC -w) workers"
}

start_workers() {
	if ! [ -e "$WORKERS_PIDS_FILE" ]
	then
		log_dashboard "Starting new workers"
		echo -n "" > $WORKERS_PIDS_FILE
		for ((i=1; i<=$MAX_PARALLEL_SHEDULES; i++))
		do
			log_dashboard "Starting new worker"

			# Run worker script with nohup
			$NOHUP $SCRIPT_WORKER > /dev/null 2>&1 &
			echo -n "$! " >> $WORKERS_PIDS_FILE
		done
	else
		log_dashboard "Workers are already running"
	fi
}

stop_workers() {
	if [ -e "$WORKERS_PIDS_FILE" ]
	then
		log_dashboard "Sending TERM signal to workers"
		$KILL -TERM $($CAT $WORKERS_PIDS_FILE)

		log_dashboard "Waiting for workers"
		wait_workers
		
		log_dashboard "All workers done"
		$RM -f $WORKERS_PIDS_FILE
	else
		log_dashboard "Workers are not running"
	fi
}

wait_workers() {
	while [ "${?}" = 0 ]
	do
	    $SLEEP 1s
	    $PS --pid $($CAT $WORKERS_PIDS_FILE) 2>&1 > /dev/null
	done
}

start_manager() {
	if ! [ -e "$MANAGER_PID_FILE" ]
	then
		log_dashboard "Starting manager"

		# Run manager script with nohup
		$NOHUP $SCRIPT_MANAGER > /dev/null 2>&1 &
		echo -n "$!" > $MANAGER_PID_FILE
	else
		log_dashboard "Manager is already running"
	fi
}

stop_manager() {
	if [ -e "$MANAGER_PID_FILE" ]
	then
		log_dashboard "Sending term signal to manager"
		$KILL -TERM $($CAT $MANAGER_PID_FILE)
		$RM -f $MANAGER_PID_FILE
	else
		log_dashboard "Manager is not running"
	fi
}

free_manager() {
	if [ -e "$MANAGER_PID_FILE" ]
	then
		log_dashboard "Sending USR1 signal to manager"
		$KILL -USR1 $($CAT $MANAGER_PID_FILE)
	else
		log_dashboard "Manager is not running"
	fi
}

append_manager_tasks() {
	log_dashboard "Adding task '$1' with success '$2' and fail '$3' to manager tasks"

	echo $(echo $1 | $BASE64 -w 0) $(echo $2 | $BASE64 -w 0) $(echo $3 | $BASE64 -w 0) >> $MANAGER_TASKS_FILE
}

print_usage() {
	echo "Usage: yastq.sh start|stop|status|add-task"
	echo "       yastq.sh add-task task TASK [success SUCCESS] [fail FAIL]"
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		start_workers
		start_manager
		;;
	"stop")
		free_manager
		stop_workers
		stop_manager
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
					log_dashboard "Skipping invalid option $1"; 
					shift
					;;
			esac
		done

		# Append task or show usage
		if [ -n "$TASK" ]
		then
			append_manager_tasks "$TASK" "$SUCCESS" "$FAIL"
		else
			print_usage
		fi
		;;
	*)
		print_usage
		;;
esac
