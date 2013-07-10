#!/bin/bash

# Include config file
if [ -r ~/.yastq.conf ]; then source ~/.yastq.conf
elif [ -r /etc/yastq.conf ]; then source /etc/yastq.conf
else echo "Config file not found"; exit 1; fi

# Check configuration options
if ! [ -d "$SCRIPT_DIR" ]; then echo "Error: SCRIPT_DIR is not setted propertly in configuration file."; exit 1; fi
if ! [ -x "$SCRIPT_WORKER" ]; then echo "Error: SCRIPT_WORKER is not setted propertly in configuration file."; exit 1; fi
if ! [ -x "$SCRIPT_MANAGER" ]; then echo "Error: SCRIPT_MANAGER is not setted propertly in configuration file."; exit 1; fi
if ! [ -n "$MAX_PARALLEL_SHEDULES" ]; then echo "Error: MAX_PARALLEL_SHEDULES is not setted propertly in configuration file."; exit 1; fi

# Get and check utilities paths
WC=`type -P wc`
if ! [ -x "$WC" ]; then echo "Error: wc is not found"; exit 1; fi
PS=`type -P ps`
if ! [ -x "$PS" ]; then echo "Error: ps is not found"; exit 1; fi
RM=`type -P rm`
if ! [ -x "$RM" ]; then echo "Error: rm is not found"; exit 1; fi
CAT=`type -P cat`
if ! [ -x "$CAT" ]; then echo "Error: cat is not found"; exit 1; fi
SED=`type -P sed`
if ! [ -x "$SED" ]; then echo "Error: sed is not found"; exit 1; fi
DATE=`type -P date`
if ! [ -x "$DATE" ]; then echo "Error: date is not found"; exit 1; fi
KILL=`type -P kill`
if ! [ -x "$KILL" ]; then echo "Error: kill is not found"; exit 1; fi
GREP=`type -P grep`
if ! [ -x "$GREP" ]; then echo "Error: grep is not found"; exit 1; fi
TOUCH=`type -P touch`
if ! [ -x "$TOUCH" ]; then echo "Error: touch is not found"; exit 1; fi
NOHUP=`type -P nohup`
if ! [ -x "$NOHUP" ]; then echo "Error: nohup is not found"; exit 1; fi
SLEEP=`type -P sleep`
if ! [ -x "$SLEEP" ]; then echo "Error: sleep is not found"; exit 1; fi
FALSE=`type -P false`
if ! [ -x "$FALSE" ]; then echo "Error: false is not found"; exit 1; fi
BASE64=`type -P base64`
if ! [ -x "$BASE64" ]; then echo "Error: base64 is not found"; exit 1; fi
MKFIFO=`type -P mkfifo`
if ! [ -x "$MKFIFO" ]; then echo "Error: mkfifo is not found"; exit 1; fi

# Workers pids file
WORKERS_PIDS_FILE=$SCRIPT_DIR/pid/workers

# Manager tasks file
MANAGER_TASKS_FILE=$SCRIPT_DIR/db/tasks

# Manager pipe to receive tasks
MANAGER_TASKS_PIPE=$SCRIPT_DIR/pipe/tasks

# Manager pid file
MANAGER_PID_FILE=$SCRIPT_DIR/pid/manager

# Logs
LOG_DASHBOARD=$SCRIPT_DIR/log/dashboard.log
LOG_MANAGER=$SCRIPT_DIR/log/manager.log
LOG_WORKER=$SCRIPT_DIR/log/worker.log

# Create manager files
if ! [ -e "$MANAGER_TASKS_FILE" ]; then $TOUCH $MANAGER_TASKS_FILE; fi
if ! [ -e "$MANAGER_TASKS_PIPE" ]; then $MKFIFO $MANAGER_TASKS_PIPE; fi

# Create log files
if ! [ -e "$LOG_DASHBOARD" ]; then $TOUCH $LOG_DASHBOARD; fi
if ! [ -e "$LOG_MANAGER" ]; then $TOUCH $LOG_MANAGER; fi
if ! [ -e "$LOG_WORKER" ]; then $TOUCH $LOG_WORKER; fi
