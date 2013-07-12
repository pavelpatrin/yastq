#!/bin/bash

# Check that running in bash
if [ -z "$BASH" ]
then 
	echo "This script could run only in bash"
	exit 1
fi

# Check configuration options
if ! [ -d "$SCRIPT_DIR" ]
then 
	echo "Error: SCRIPT_DIR is not setted propertly in configuration file."
	exit 1
fi

if ! [ -n "$MAX_PARALLEL_SHEDULES" ]
then 
	echo "Error: MAX_PARALLEL_SHEDULES is not setted propertly in configuration file."
	exit 1
fi

# Get and check utilities paths
WC=`type -P wc`
if ! [ -x "$WC" ]
then 
	echo "Error: wc is not found"
	exit 1
fi

PS=`type -P ps`
if ! [ -x "$PS" ]
then 
	echo "Error: ps is not found"
	exit 1
fi

RM=`type -P rm`
if ! [ -x "$RM" ]
then 
	echo "Error: rm is not found"
	exit 1
fi

CAT=`type -P cat`
if ! [ -x "$CAT" ]
then 
	echo "Error: cat is not found"
	exit 1
fi

SED=`type -P sed`
if ! [ -x "$SED" ]
then 
	echo "Error: sed is not found"
	exit 1
fi

DATE=`type -P date`
if ! [ -x "$DATE" ]
then 
	echo "Error: date is not found"
	exit 1
fi

KILL=`type -P kill`
if ! [ -x "$KILL" ]
then 
	echo "Error: kill is not found"
	exit 1
fi

GREP=`type -P grep`
if ! [ -x "$GREP" ]
then 
	echo "Error: grep is not found"
	exit 1
fi

TOUCH=`type -P touch`
if ! [ -x "$TOUCH" ]
then 
	echo "Error: touch is not found"
	exit 1
fi

NOHUP=`type -P nohup`
if ! [ -x "$NOHUP" ]
then 
	echo "Error: nohup is not found"
	exit 1
fi

SLEEP=`type -P sleep`
if ! [ -x "$NOHUP" ]
then 
	echo "Error: nohup is not found"
	exit 1
fi

FLOCK=`type -P flock`
if ! [ -x "$FLOCK" ]
then 
	echo "Error: flock is not found"
	exit 1
fi

FALSE=`type -P false`
if ! [ -x "$FALSE" ]
then 
	echo "Error: false is not found"
	exit 1
fi

BASE64=`type -P base64`
if ! [ -x "$BASE64" ]
then 
	echo "Error: base64 is not found"
	exit 1
fi

MKFIFO=`type -P mkfifo`
if ! [ -x "$MKFIFO" ]
then 
	echo "Error: mkfifo is not found"
	exit 1
fi

# Dashboard log file
DASHBOARD_LOG_FILE=$SCRIPT_DIR/log/dashboard.log

# Worker script
WORKER_SCRIPT=$SCRIPT_DIR/worker.sh

# Workers log file
WORKER_LOG_FILE=$SCRIPT_DIR/log/worker.log

# Worker pid file
WORKER_PID_FILE=$SCRIPT_DIR/pid/worker.pid

# Tasks queue script
TASKSQUEUE_SCRIPT=$SCRIPT_DIR/tasksqueue.sh

# Tasks queue tasks file
TASKSQUEUE_TASKS_FILE=$SCRIPT_DIR/db/tasks

# Tasks queue tasks lock
TASKSQUEUE_TASKS_FILE_LOCK=$SCRIPT_DIR/lock/tasksfile

# Tasks queue pipe to transmit tasks
TASKSQUEUE_TASKS_PIPE=$SCRIPT_DIR/pipe/tasksqueue

# Tasks queue pipe to transmit tasks lock
TASKSQUEUE_TASKS_PIPE_LOCK=$SCRIPT_DIR/lock/taskspipe

# Tasks queue pid file
TASKSQUEUE_PID_FILE=$SCRIPT_DIR/pid/tasksqueue.pid

# Tasksqueue log
TASKSQUEUE_LOG_FILE=$SCRIPT_DIR/log/tasksqueue.log

# Create tasksqueue files
if ! [ -e "$TASKSQUEUE_TASKS_FILE" ]
then 
	"$TOUCH" "$TASKSQUEUE_TASKS_FILE"
fi

if ! [ -e "$TASKSQUEUE_TASKS_FILE_LOCK" ]
then 
	"$TOUCH" "$TASKSQUEUE_TASKS_FILE_LOCK"
fi

if ! [ -e "$TASKSQUEUE_TASKS_PIPE" ]
then 
	"$MKFIFO" "$TASKSQUEUE_TASKS_PIPE"
fi

if ! [ -e "$TASKSQUEUE_TASKS_PIPE_LOCK" ]
then 
	"$TOUCH" "$TASKSQUEUE_TASKS_PIPE_LOCK"
fi

# Create log files
if ! [ -e "$LOG_TASKSQUEUE" ]
then 
	"$TOUCH" "$TASKSQUEUE_LOG_FILE"
fi
if ! [ -e "$LOG_DASHBOARD" ]
then 
	"$TOUCH" "$DASHBOARD_LOG_FILE"
fi
if ! [ -e "$LOG_WORKER" ]
then 
	"$TOUCH" "$WORKER_LOG_FILE"
fi
