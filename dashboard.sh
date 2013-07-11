#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check existance of common code
if ! source $SCRIPT_COMMON; then echo "Common file not found"; exit 1; fi

##
## Echoes message  and sends it to log
##
dashboard_say_log() 
{
	echo "$($DATE +'%F %T') (dashboard) $1"
	echo "$($DATE +'%F %T') (dashboard) $1" >> $LOG_DASHBOARD
}

##
## Echoes message
##
dashboard_say() 
{
	echo "$($DATE +'%F %T') (dashboard) $1"
}

##
## Echoes pids of workers or returns error code
##
workers_pids() 
{
	unset -v RESULT

	if ! [ -e "$WORKERS_PID_FILE" ]
	then 
		return 1
	fi

	local WORKERS_PIDS
	read -r WORKERS_PIDS < $WORKERS_PID_FILE
	if ! $PS -p $WORKERS_PIDS 2>/dev/null >/dev/null
	then
		return 2
	fi

	RESULT=$WORKERS_PIDS
	return 0
}

##
## Starts workers
##
workers_start() 
{
	local WORKERS_COUNT=$1

	if workers_pids
	then
		return 1
	fi

	local WORKERS_PIDS
	for ((i=1; i<=$WORKERS_COUNT; i++))
	do
		# Start worker with nohup
		$NOHUP $SCRIPT_WORKER 2>/dev/null >/dev/null &

		# Save worker pid
		WORKERS_PIDS="$WORKERS_PIDS $!"
	done

	# Store workers pids into pidfile
	echo $WORKERS_PIDS > $WORKERS_PID_FILE
	return 0
}

##
## Stops workers
##
workers_stop() 
{
	if workers_pids
	then
		local WORKERS_PIDS=$RESULT

		# Sending term signal to workers
		$KILL -s SIGTERM $WORKERS_PIDS >/dev/null

		# Waiting for workers exiting
		while $PS -p $WORKERS_PIDS >/dev/null
		do
		    $SLEEP 1s
		done
		
		# Remove pids file
		$RM -f $WORKERS_PID_FILE
		return 0
	fi
	
	return 1
}

##
## Echoes pid of tasksqueue or returns error code
##
tasksqueue_pid()
{
	unset -v RESULT

	if ! [ -e "$TASKSQUEUE_PID_FILE" ]
	then 
		return 1
	fi

	local TASKSQUEUE_PID
	read -r TASKSQUEUE_PID < $TASKSQUEUE_PID_FILE

	if ! $PS -p $TASKSQUEUE_PID 2>/dev/null >/dev/null
	then
		return 2
	fi

	RESULT=$TASKSQUEUE_PID
	return 0
}

##
## Starts tasks queue
##
tasksqueue_start()
{
	if tasksqueue_pid
	then
		return 1
	fi

	$NOHUP $SCRIPT_TASKSQUEUE 2>/dev/null >/dev/null &
	echo $! > $TASKSQUEUE_PID_FILE
	return 0
}

##
## Stops tasks queue
##
tasksqueue_stop()
{
	if tasksqueue_pid
	then
		local TASKSQUEUE_PID=$RESULT

		# Sending term signal to workers
		$KILL -s SIGTERM $TASKSQUEUE_PID >/dev/null

		# Remove pids file
		$RM -f $TASKSQUEUE_PID_FILE
		return 0
	fi

	return 1
}

## 
## Appends tasks queue
##
tasksqueue_add_task() 
{
	local TASK="$(echo $1 | $BASE64 -w 0) $(echo $2 | $BASE64 -w 0) $(echo $3 | $BASE64 -w 0)"

	if tasksqueue_pid
	then
		# Send task to running tasksqueue via pipe
		local TASKSQUEUE_PID=$RESULT
		$KILL -s SIGUSR1 $TASKSQUEUE_PID >/dev/null
		echo $TASK > $TASKSQUEUE_RECEIVE_PIPE
	else
		# Send task to stopped tasksqueue
		$SCRIPT_TASKSQUEUE receive-task >/dev/null &
		echo $TASK > $TASKSQUEUE_RECEIVE_PIPE
		wait $!
	fi

	return 0
}

# Currect action
ACTION=$1
shift

case $ACTION in 
	"start")
		dashboard_say_log "Staring $MAX_PARALLEL_SHEDULES workers..."
		if workers_start $MAX_PARALLEL_SHEDULES
		then
			dashboard_say_log "Staring $MAX_PARALLEL_SHEDULES workers ok" 
		else 
			dashboard_say_log "Staring $MAX_PARALLEL_SHEDULES workers failed ($?)"
		fi

		dashboard_say_log "Staring tasks queue..."
		if tasksqueue_start 
		then
			dashboard_say_log "Staring tasks queue ok" 
		else 
			dashboard_say_log "Staring tasks queue failed ($?)"
		fi
		;;
	"stop")
		dashboard_say_log "Stopping $MAX_PARALLEL_SHEDULES workers..."
		if workers_stop 
		then
			dashboard_say_log "Stopping $MAX_PARALLEL_SHEDULES workers ok" 
		else
			dashboard_say_log "Stopping $MAX_PARALLEL_SHEDULES workers failed ($?)"
		fi

		dashboard_say_log "Stopping tasks queue..."
		if tasksqueue_stop 
		then 
			dashboard_say_log "Stopping tasks queue ok" 
		else
			dashboard_say_log "Stopping tasks queue failed ($?)"
		fi
		;;
	"status")
		if workers_pids 
		then 
			dashboard_say "Workers are running" 
		else 
			dashboard_say "Workers are not running"
		fi

		if tasksqueue_pid
		then 
			dashboard_say "Tasks queue is running" 
		else
			dashboard_say "Tasks queue is not running"
		fi
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
					dashboard_say_log "Skipping invalid option $1"; 
					shift
					;;
			esac
		done

		# Append task or show usage
		if [ -n "$TASK" ]
		then
			dashboard_say_log "Adding task $TASK with SUCC $SUCCESS and FAIL $FAIL" 
			if tasksqueue_add_task "$TASK" "$SUCCESS" "$FAIL" 
			then
				dashboard_say_log "Adding task OK" 
			else
				dashboard_say_log "Adding task FAIL ($?)"
			fi
		else
			dashboard_say_log "Adding task FAIL (task is empty)" 
		fi
		;;
	*)
		echo "Usage: $0 start|stop|status|add-task"
		echo "       $0 add-task task TASK [success SUCCESS] [fail FAIL]"
		;;
esac
