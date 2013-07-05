#!/bin/bash

# Include config file
if [[ -e ~/.yastq.conf ]]; then source ~/.yastq.conf
elif [[ -e /etc/yastq.conf ]]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Get and check utilities paths
WC=`which wc`
if ! [[ -e $WC ]]; then echo "wc is not found"; exit 1; fi
TS=`which ts`
if ! [[ -e $TS ]]; then echo "ts is not found"; exit 1; fi
PS=`which ps`
if ! [[ -e $PS ]]; then echo "ps is not found"; exit 1; fi
RM=`which rm`
if ! [[ -e $RM ]]; then echo "rm is not found"; exit 1; fi
CAT=`which cat`
if ! [[ -e $CAT ]]; then echo "cat is not found"; exit 1; fi
KILL=`which kill`
if ! [[ -e $KILL ]]; then echo "kill is not found"; exit 1; fi
HEAD=`which head`
if ! [[ -e $HEAD ]]; then echo "head is not found"; exit 1; fi
TAIL=`which tail`
if ! [[ -e $TAIL ]]; then echo "tail is not found"; exit 1; fi
GREP=`which grep`
if ! [[ -e $GREP ]]; then echo "grep is not found"; exit 1; fi
TOUCH=`which touch`
if ! [[ -e $TOUCH ]]; then echo "touch is not found"; exit 1; fi
NOHUP=`which nohup`
if ! [[ -e $NOHUP ]]; then echo "nohup is not found"; exit 1; fi
SPONGE=`which sponge`
if ! [[ -e $SPONGE ]]; then echo "sponge is not found"; exit 1; fi
MKFIFO=`which mkfifo`
if ! [[ -e $MKFIFO ]]; then echo "mkfifo is not found"; exit 1; fi

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
