#!/bin/bash

##
## Does all common job
##
## Exits with codes:
##	1 - configuration file errors
##	2 - dependencies errors
##

# Config check (logging level)
[ -n "$LOG_LEVEL" ] || ! [[ "$LOG_LEVEL" =~ ^[[:digit:]]+$ ]] || { echo "Error: config directive LOG_LEVEL not defined correctly"; exit 1;}

# Config check (parallel tasks)
[ -n "$PARALLEL_TASKS" ] || ! [[ "$PARALLEL_TASKS" =~ ^[[:digit:]]+$ ]] || { echo "Error: config directive PARALLEL_TASKS not defined correctly"; exit 1;}

# Config check (script parts directories)
[ -n "$SCRIPT_DIR" -a -d "$SCRIPT_DIR" -a -w "$SCRIPT_DIR" -a -x "$SCRIPT_DIR" ] || { echo "Error: config directive SCRIPT_DIR not defined correctly"; exit 1;}
[ -n "$LOCK_DIR" -a -d "$LOCK_DIR" -a -w "$LOCK_DIR" -a -x "$LOCK_DIR" ] || { echo "Error: config directive LOCK_DIR not defined correctly"; exit 1;}
[ -n "$PIPE_DIR" -a -d "$PIPE_DIR" -a -w "$PIPE_DIR" -a -x "$PIPE_DIR" ] || { echo "Error: config directive PIPE_DIR not defined correctly"; exit 1;} 
[ -n "$TASK_DIR" -a -d "$TASK_DIR" -a -w "$TASK_DIR" -a -x "$TASK_DIR" ] || { echo "Error: config directive TASK_DIR not defined correctly"; exit 1;}
[ -n "$LOG_DIR" -a -d "$LOG_DIR" -a -w "$LOG_DIR" -a -x "$LOG_DIR" ] || { echo "Error: config directive LOG_DIR not defined correctly"; exit 1;}
[ -n "$PID_DIR" -a -d "$PID_DIR" -a -w "$PID_DIR" -a -x "$PID_DIR" ] || { echo "Error: config directive PID_DIR not defined correctly"; exit 1;}

# Config check (script part files)
[ -n "$COMMON_SCRIPT_FILE" -o -e "$COMMON_SCRIPT_FILE" ] || { echo "Error: config directive COMMON_SCRIPT_FILE not defined correctly"; exit 1;}
[ -n "$WORKER_SCRIPT_FILE" -o -e "$WORKER_SCRIPT_FILE" -o  -x "$WORKER_SCRIPT_FILE" ] || { echo "Error: config directive WORKER_SCRIPT_FILE not defined correctly"; exit 1;}
[ -n "$DASHBOARD_SCRIPT_FILE" -o -e "$DASHBOARD_SCRIPT_FILE" -o  -x "$DASHBOARD_SCRIPT_FILE" ] || { echo "Error: config directive DASHBOARD_SCRIPT_FILE not defined correctly"; exit 1;}
[ -n "$TASKSQUEUE_SCRIPT_FILE" -o -e "$TASKSQUEUE_SCRIPT_FILE" -o  -x "$TASKSQUEUE_SCRIPT_FILE" ] || { echo "Error: config directive TASKSQUEUE_SCRIPT_FILE not defined correctly"; exit 1;}

# Config check (script files)
[ -n "$WORKERS_PID_FILE" ] || { echo "Error: config directive WORKERS_PID_FILE not defined correctly"; exit 1;}
[ -n "$TASKSQUEUE_PID_FILE" ] || { echo "Error: config directive TASKSQUEUE_PID_FILE not defined correctly"; exit 1;}
[ -n "$TASKS_DELAYED_FILE" ] || { echo "Error: config directive TASKS_DELAYED_FILE not defined correctly"; exit 1;}
[ -n "$TASKS_DELAYED_FILE_LOCK" ] || { echo "Error: config directive TASKS_DELAYED_FILE_LOCK not defined correctly"; exit 1;}
[ -n "$TASKS_TRANSPORT_PIPE" ] || { echo "Error: config directive TASKS_TRANSPORT_PIPE not defined correctly"; exit 1;}
[ -n "$TASKS_TRANSPORT_PIPE_LOCK" ] || { echo "Error: config directive TASKS_TRANSPORT_PIPE_LOCK not defined correctly"; exit 1;}

# Dependencies check
WC=$(type -P wc) || { echo "Error: wc not found"; exit 2;}
PS=$(type -P ps) || { echo "Error: ps not found"; exit 2;}
RM=$(type -P rm) || { echo "Error: rm not found"; exit 2;}
CAT=$(type -P cat) || { echo "Error: cat not found"; exit 2;}
SED=$(type -P sed) || { echo "Error: sed not found"; exit 2;}
DATE=$(type -P date) || { echo "Error: date not found"; exit 2;}
KILL=$(type -P kill) || { echo "Error: kill not found"; exit 2;}
GREP=$(type -P grep) || { echo "Error: grep not found"; exit 2;}
TOUCH=$(type -P touch) || { echo "Error: touch not found"; exit 2;}
MKDIR=$(type -P mkdir) || { echo "Error: mkdir not found"; exit 2;}
NOHUP=$(type -P nohup) || { echo "Error: nohup not found"; exit 2;}
SLEEP=$(type -P sleep) || { echo "Error: sleep not found"; exit 2;}
FLOCK=$(type -P flock) || { echo "Error: flock not found"; exit 2;}
FALSE=$(type -P false) || { echo "Error: false not found"; exit 2;}
BASE64=$(type -P base64) || { echo "Error: base64 not found"; exit 2;}
MKFIFO=$(type -P mkfifo) || { echo "Error: mkfifo not found"; exit 2;}

# Logging

##
## Sends message to log with ERROR logging level
##
log_error()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOG_LEVEL & 1 )) && echo "[$($DATE '+%F %T.%N')][$LOG_SOURCE $$][ERROR] $LOG_MESSAGE" >> "$LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with WARN logging level
##
log_warn()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOG_LEVEL & 2 )) && echo "[$($DATE '+%F %T.%N')][$LOG_SOURCE $$][WARN] $LOG_MESSAGE" >> "$LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with INFO logging level
##
log_info()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOG_LEVEL & 4 )) && echo "[$($DATE '+%F %T.%N')][$LOG_SOURCE $$][INFO] $LOG_MESSAGE" >> "$LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with DEBUG logging level
##
log_debug()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOG_LEVEL & 8 )) && echo "[$($DATE '+%F %T.%N')][$LOG_SOURCE $$][DEBUG] $LOG_MESSAGE" >> "$LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with TRACE logging level
##
log_trace()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOG_LEVEL & 16 )) && echo "[$($DATE '+%F %T.%N')][$LOG_SOURCE $$][TRACE] $LOG_MESSAGE" >> "$LOG_DIR/$LOG_SOURCE.log"
}
