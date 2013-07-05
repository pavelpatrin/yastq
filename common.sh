#!/bin/bash

# Correct $PATH
PATH=$PATH:`dirname $0`

# Max of parallels tasks
MAX_PARALLEL_SHEDULES=5

# File with queue
QUEUE_DELAYED_FILE=db/delayed

# File with running tasks
QUEUE_COMPLETE_FILE=db/complete

# File with failed tasks
QUEUE_FAILED_FILE=db/failed

# Workers pids file
WORKERS_PIDS_FILE=pid/workers

# Tasks queue
TASKS_QUEUE_PIPE=pipe/tasks
TASKS_QUEUE_PID_FILE=pid/tasksqueue

# Utilities paths
WC=wc
TS=ts
PS=ps
RM=rm
CAT=cat
CUT=cut
KILL=kill
HEAD=head
TAIL=tail
GREP=grep
TOUCH=touch
SPONGE=sponge
MKFIFO=mkfifo

# Logs
LOG_WORKER=log/worker.log
LOG_MANAGER=log/manager.log
LOG_QUEUE=log/queue.log

# Create queue files
if ! [[ -e $QUEUE_DELAYED_FILE ]]; then
	$TOUCH $QUEUE_DELAYED_FILE
fi
if ! [[ -e $QUEUE_COMPLETE_FILE ]]; then
	$TOUCH $QUEUE_COMPLETE_FILE
fi
if ! [[ -e $QUEUE_FAILED_FILE ]]; then
	$TOUCH $QUEUE_FAILED_FILE
fi

# Create log files
if ! [[ -e $LOG_MANAGER ]]; then
	$TOUCH $LOG_MANAGER
fi
if ! [[ -e $LOG_WORKER ]]; then
	$TOUCH $LOG_WORKER
fi
if ! [[ -e $LOG_QUEUE ]]; then
	$TOUCH $LOG_QUEUE
fi

# Create queueFIFO
if ! [[ -e $TASKS_QUEUE_PIPE ]]; then
	$MKFIFO $TASKS_QUEUE_PIPE
fi

function log_manager() {
	echo "(manager) $1" | $TS
	echo "(manager) $1" | $TS >> $LOG_MANAGER
}

function log_queue() {
	echo "(queue) $1" | $TS >> $LOG_QUEUE
}

function log_worker() {
	echo "(worker) $1" | $TS >> $LOG_WORKER
}
