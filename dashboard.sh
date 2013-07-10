#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

##
## Sends message to log
##
dashboard_log() 
{
	echo "$($DATE +'%F %T') (dashboard) $1"
	echo "$($DATE +'%F %T') (dashboard) $1" >> $LOG_DASHBOARD
}

##
## Echoes pid of manager or returns error code
##
manager_pid() 
{
	if ! [ -e "$MANAGER_PID_FILE" ]
	then 
		return 1
	fi

	local MANAGER_PID
	read -r MANAGER_PID < $MANAGER_PID_FILE

	if ! $PS -p $MANAGER_PID >/dev/null
	then
		return 2
	fi

	echo $MANAGER_PID
	return 0
}

## 
## Query master for status
##
manager_status() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		dashboard_log "Manager is not running"
		return 1
	fi

	dashboard_log "Sending status request" 
	if ! $KILL -s SIGUSR1 $MANAGER_PID >/dev/null
	then
		dashboard_log "Cannot send status request"
		return 1
	fi

	dashboard_log "Waiting 5 second for status response"
	local MANAGER_STATUS
	read -r -t 5 MANAGER_STATUS <> $MANAGER_STATUS_PIPE

	if [ -z "$MANAGER_STATUS" ]
	then
		dashboard_log "No response received from manager"
		return 1
	fi

	dashboard_log "Status: $MANAGER_STATUS"
	return 0
}

## 
## Starts manager process in background
##
manager_start() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		dashboard_log "Manager is already running"
		return 1
	fi

	dashboard_log "Starting manager"
	$NOHUP $SCRIPT_MANAGER 2>/dev/null >/dev/null &
	echo -n "$!" > $MANAGER_PID_FILE
	return 0
}

## 
## Stops manager process
##
manager_stop() 
{
	local MANAGER_PID
	local MANAGER_RUNING
	MANAGER_PID=$(manager_pid)
	MANAGER_RUNING=$?

	if ! $MANAGER_RUNING
	then
		dashboard_log "Manager is not running"
		return 1
	fi

	dashboard_log "Sending term signal to manager"
	$KILL -TERM $MANAGER_PID >/dev/null
	$RM -f $MANAGER_PID_FILE
	return 0
}

## 
## Appends tasks queue
##
manager_append_tasks() 
{
	dashboard_log "Adding task '$1' with success '$2' and fail '$3' to manager tasks"

	echo $(echo $1 | $BASE64 -w 0) $(echo $2 | $BASE64 -w 0) $(echo $3 | $BASE64 -w 0) >> $MANAGER_TASKS_FILE
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		manager_start
		;;
	"stop")
		manager_stop
		;;
	"status")
		manager_status
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
					dashboard_log "Skipping invalid option $1"; 
					shift
					;;
			esac
		done

		# Append task or show usage
		if [ -n "$TASK" ]
		then
			manager_append_tasks "$TASK" "$SUCCESS" "$FAIL"
		else
			dashboard_log "Task is empty"; 
		fi
		;;
	*)
		echo "Usage: $0 start|stop|status|add-task"
		echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL]"
		;;
esac
