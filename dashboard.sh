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
	if [ -e $MANAGER_PID_FILE ]
	then
		local MANAGER_PID
		read -r MANAGER_PID < $MANAGER_PID_FILE

		log_dashboard "Sending status request"
		$KILL -s SIGUSR1 $MANAGER_PID

		log_dashboard "Waiting 5 second for status response"
		local MANAGER_STATUS
		read -t 5 MANAGER_STATUS <> $MANAGER_STATUS_PIPE

		if [ -n "$MANAGER_STATUS" ]
		then
			log_dashboard "Status: $MANAGER_STATUS"
		else
			log_dashboard "No response received from manager"
		fi
	else 
		log_dashboard "Manager is not running"
	fi
}

start_manager() {
	if ! [ -e "$MANAGER_PID_FILE" ]
	then
		log_dashboard "Starting manager"

		# Run manager script with nohup
		$NOHUP $SCRIPT_MANAGER 2>/dev/null 1>/dev/null &
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

append_manager_tasks() {
	log_dashboard "Adding task '$1' with success '$2' and fail '$3' to manager tasks"

	echo $(echo $1 | $BASE64 -w 0) $(echo $2 | $BASE64 -w 0) $(echo $3 | $BASE64 -w 0) >> $MANAGER_TASKS_FILE
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		start_manager
		;;
	"stop")
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
			log_dashboard "Task is empty"; 
		fi
		;;
	*)
		echo "Usage: $0 start|stop|status|add-task"
		echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL]"
		;;
esac
