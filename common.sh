#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]
then 
	source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]
then 
	source /etc/yastq.conf
else 
	echo "Config file not found"
	exit 1
fi

# Check configuration options
if ! [[ -d $SCRIPT_DIR ]]; then echo "Error: SCRIPT_DIR is not setted propertly in configuration file."; exit 1; fi
if ! [[ -e $SCRIPT_WORKER ]]; then echo "Error: SCRIPT_WORKER is not setted propertly in configuration file."; exit 1; fi
if ! [[ -e $SCRIPT_TASKS_QUEUE ]]; then echo "Error: SCRIPT_TASKS_QUEUE is not setted propertly in configuration file."; exit 1; fi
if ! [[ -n $MAX_PARALLEL_SHEDULES ]]; then echo "Error: MAX_PARALLEL_SHEDULES is not setted propertly in configuration file."; exit 1; fi

# Get and check utilities paths
WC=`which wc`
if ! [[ -e $WC ]]; then echo "Error: wc is not found"; exit 1; fi
PS=`which ps`
if ! [[ -e $PS ]]; then echo "Error: ps is not found"; exit 1; fi
RM=`which rm`
if ! [[ -e $RM ]]; then echo "Error: rm is not found"; exit 1; fi
CAT=`which cat`
if ! [[ -e $CAT ]]; then echo "Error: cat is not found"; exit 1; fi
SED=`which sed`
if ! [[ -e $SED ]]; then echo "Error: sed is not found"; exit 1; fi
DATE=`which date`
if ! [[ -e $DATE ]]; then echo "Error: date is not found"; exit 1; fi
KILL=`which kill`
if ! [[ -e $KILL ]]; then echo "Error: kill is not found"; exit 1; fi
HEAD=`which head`
if ! [[ -e $HEAD ]]; then echo "Error: head is not found"; exit 1; fi
TAIL=`which tail`
if ! [[ -e $TAIL ]]; then echo "Error: tail is not found"; exit 1; fi
GREP=`which grep`
if ! [[ -e $GREP ]]; then echo "Error: grep is not found"; exit 1; fi
TOUCH=`which touch`
if ! [[ -e $TOUCH ]]; then echo "Error: touch is not found"; exit 1; fi
NOHUP=`which nohup`
if ! [[ -e $NOHUP ]]; then echo "Error: nohup is not found"; exit 1; fi
SLEEP=`which sleep`
if ! [[ -e $SLEEP ]]; then echo "Error: sleep is not found"; exit 1; fi
FALSE=`which false`
if ! [[ -e $FALSE ]]; then echo "Error: false is not found"; exit 1; fi
BASE64=`which base64`
if ! [[ -e $BASE64 ]]; then echo "Error: base64 is not found"; exit 1; fi
MKFIFO=`which mkfifo`
if ! [[ -e $MKFIFO ]]; then echo "Error: mkfifo is not found"; exit 1; fi

# Workers pids file
WORKERS_PIDS_FILE=$SCRIPT_DIR/pid/workers

# Tasks queue
TASKS_QUEUE_FILE=$SCRIPT_DIR/db/tasks
TASKS_QUEUE_PIPE=$SCRIPT_DIR/pipe/tasks
TASKS_QUEUE_PID_FILE=$SCRIPT_DIR/pid/tasksqueue

# Logs
LOG_WORKER=$SCRIPT_DIR/log/worker.log
LOG_MANAGER=$SCRIPT_DIR/log/manager.log
LOG_QUEUE=$SCRIPT_DIR/log/queue.log

# Create queue files
if ! [[ -e $TASKS_QUEUE_FILE ]]; then $TOUCH $TASKS_QUEUE_FILE; fi
if ! [[ -e $TASKS_QUEUE_PIPE ]]; then $MKFIFO $TASKS_QUEUE_PIPE; fi

# Create log files
if ! [[ -e $LOG_MANAGER ]]; then $TOUCH $LOG_MANAGER; fi
if ! [[ -e $LOG_WORKER ]]; then $TOUCH $LOG_WORKER; fi
if ! [[ -e $LOG_QUEUE ]]; then $TOUCH $LOG_QUEUE; fi
