#!/bin/bash

# Correct $PATH
PATH=$PATH:`dirname $0`

# Max of parallels tasks
MAX_PARALLEL_SHEDULES=5

# File with queue
QUEUE_DELAYED_FILE=db/delayed

# File with running tasks
QUEUE_ACTIVE_FILE=db/active

# File with running tasks
QUEUE_COMPLETE_FILE=db/complete

# File with failed tasks
QUEUE_FAILED_FILE=db/failed

# Workers pids file
WORKERS_PIDS_FILE=pid/workers.pids

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

# Logs
LOG_WORKER=log/worker.log
LOG_MASTER=log/master.log

# Create queue files
$TOUCH $QUEUE_DELAYED_FILE
$TOUCH $QUEUE_ACTIVE_FILE
$TOUCH $QUEUE_COMPLETE_FILE
$TOUCH $QUEUE_FAILED_FILE

# Create log files
$TOUCH $LOG_MASTER
$TOUCH $LOG_WORKER

function log_master() {
	echo "$1" | $TS
	echo "$1" | $TS >> $LOG_MASTER
}

function log_worker() {
	echo "$1" | $TS >> $LOG_WORKER
}
