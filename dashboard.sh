#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

log_dashboard() 
{
	echo "$($DATE +'%F %T') (dashboard) $1"
	echo "$($DATE +'%F %T') (dashboard) $1" >> $LOG_DASHBOARD
}

##
## Echoes managers pid or returns error code
##
manager_get_pid() 
{
	if ! [ -e $MANAGER_PID_FILE ]
	then 
		return 1
	fi

	local MANAGER_PID
	read -r MANAGER_PID < $MANAGER_PID_FILE

	if ! $PS -p $MANAGER_PID 2>/dev/null >/dev/null
	then
		return 2
	fi

	echo $MANAGER_PID
	return 0
}

## 
## Query master for status
##
show_status() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_get_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		log_dashboard "Manager is not running"
		return 1
	fi

	log_dashboard "Sending status request" 
	if ! $KILL -s SIGUSR1 $MANAGER_PID 2>/dev/null >/dev/null
	then
		log_dashboard "Cannot send status request"
		return 1
	fi

	log_dashboard "Waiting 5 second for status response"
	local MANAGER_STATUS
	read -r -t 5 MANAGER_STATUS <> $MANAGER_STATUS_PIPE

	if [ -z "$MANAGER_STATUS" ]
	then
		log_dashboard "No response received from manager"
		return 1
	fi

	log_dashboard "Status: $MANAGER_STATUS"
	return 0
}

## 
## Starts manager process in background
##
start_manager() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_get_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		log_dashboard "Manager is already running"
		return 1
	fi

	log_dashboard "Starting manager"
	$NOHUP $SCRIPT_MANAGER 2>/dev/null >/dev/null &
	echo -n "$!" > $MANAGER_PID_FILE
	return 0
}

## 
## Stops manager process
##
stop_manager() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_get_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		log_dashboard "Manager is not running"
		return 1
	fi

	log_dashboard "Sending term signal to manager"
	$KILL -TERM $MANAGER_PID 2>/dev/null >/dev/null
	$RM -f $MANAGER_PID_FILE
	return 0
}

append_manager_tasks() 
{
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
