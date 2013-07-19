#!/bin/bash

##
## Does all common job
##
## Exits with codes:
##	1 - dependencies errors
##	2 - configuration file errors
##

# Dependencies check
DEPENDENCIES=(wc ps rm cat sed bash date kill grep touch mkdir nohup sleep flock false mkfifo)
for DEPENDENCY in "${DEPENDENCIES[@]}"
do
	type -a "$DEPENDENCY" 1>/dev/null || { echo "Error: [$DEPENDENCY] not found" 1>&2; exit 1; }
done

# Config check (logging level)
[ -n "$LOG_LEVEL" ] || ! [[ "$LOG_LEVEL" =~ ^[[:digit:]]+$ ]] || { echo "Error: config directive LOG_LEVEL is not defined correctly" 1>&2; exit 2; }

# Config check (parallel tasks)
[ -n "$PARALLEL_TASKS" ] || ! [[ "$PARALLEL_TASKS" =~ ^[[:digit:]]+$ ]] || { echo "Error: config directive PARALLEL_TASKS is not defined correctly" 1>&2; exit 2; }

# Config check (script parts directories)
[ -n "$SCRIPT_DIR" -a -d "$SCRIPT_DIR" -a -w "$SCRIPT_DIR" -a -x "$SCRIPT_DIR" ] || { echo "Error: config directive SCRIPT_DIR is not defined correctly" 1>&2; exit 2; }
[ -n "$PIPE_DIR" -a -d "$PIPE_DIR" -a -w "$PIPE_DIR" -a -x "$PIPE_DIR" ] || { echo "Error: config directive PIPE_DIR is not defined correctly" 1>&2; exit 2; } 
[ -n "$TASK_DIR" -a -d "$TASK_DIR" -a -w "$TASK_DIR" -a -x "$TASK_DIR" ] || { echo "Error: config directive TASK_DIR is not defined correctly" 1>&2; exit 2; }
[ -n "$LOCK_DIR" -a -d "$LOCK_DIR" -a -w "$LOCK_DIR" -a -x "$LOCK_DIR" ] || { echo "Error: config directive LOCK_DIR is not defined correctly" 1>&2; exit 2; }
[ -n "$LOG_DIR" -a -d "$LOG_DIR" -a -w "$LOG_DIR" -a -x "$LOG_DIR" ] || { echo "Error: config directive LOG_DIR is not defined correctly" 1>&2; exit 2; }
[ -n "$PID_DIR" -a -d "$PID_DIR" -a -w "$PID_DIR" -a -x "$PID_DIR" ] || { echo "Error: config directive PID_DIR is not defined correctly" 1>&2; exit 2; }

# Config check (script part files)
[ -n "$COMMON_SCRIPT_FILE" -o -e "$COMMON_SCRIPT_FILE" ] || { echo "Error: config directive COMMON_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$LOGGER_SCRIPT_FILE" -o -r "$LOGGER_SCRIPT_FILE" ] || { echo "Error: config directive LOGGER_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$QUEUEDB_SCRIPT_FILE" -o -r "$QUEUEDB_SCRIPT_FILE" ] || { echo "Error: config directive QUEUEDB_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$WORKER_SCRIPT_FILE" -o -e "$WORKER_SCRIPT_FILE" -o  -x "$WORKER_SCRIPT_FILE" ] || { echo "Error: config directive WORKER_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$DASHBOARD_SCRIPT_FILE" -o -e "$DASHBOARD_SCRIPT_FILE" -o  -x "$DASHBOARD_SCRIPT_FILE" ] || { echo "Error: config directive DASHBOARD_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKSQUEUE_SCRIPT_FILE" -o -e "$TASKSQUEUE_SCRIPT_FILE" -o  -x "$TASKSQUEUE_SCRIPT_FILE" ] || { echo "Error: config directive TASKSQUEUE_SCRIPT_FILE is not defined correctly" 1>&2; exit 2; }

# Config check (script files)
[ -n "$WORKERS_PID_FILE" ] || { echo "Error: config directive WORKERS_PID_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKSQUEUE_PID_FILE" ] || { echo "Error: config directive TASKSQUEUE_PID_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKS_FILE" ] ||{ echo "Error: config directive TASKS_FILE is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKS_FILE_LOCK" ] ||{ echo "Error: config directive TASKS_FILE_LOCK is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKS_PIPE" ] || { echo "Error: config directive TASKS_PIPE is not defined correctly" 1>&2; exit 2; }
[ -n "$TASKS_PIPE_LOCK" ] || { echo "Error: config directive TASKS_PIPE is not defined correctly" 1>&2; exit 2; }

# Create parts if needed
[ -e "$TASKS_FILE" ] || touch "$TASKS_FILE" || { echo "Error: touching $TASKS_FILE failed ($?)" 1>&2; exit 2; }
[ -e "$TASKS_FILE_LOCK" ] || touch "$TASKS_FILE_LOCK" || { echo "Error: touching $TASKS_FILE_LOCK failed ($?)" 1>&2; exit 2; }
[ -p "$TASKS_PIPE" ] || mkfifo "$TASKS_PIPE" || { echo "Error: creating pipe $TASKS_PIPE failed ($?)" 1>&2; exit 2; }
[ -e "$TASKS_PIPE_LOCK" ] || touch "$TASKS_PIPE_LOCK" || { echo "Error: touching $TASKS_PIPE_LOCK failed ($?)" 1>&2; exit 2; }

# Import logging functins
source "$LOGGER_SCRIPT_FILE" "$LOG_DIR" "$LOG_LEVEL" || { echo "Error: sourcing logger script file failed ($?)" 1>&2; exit 2; }

# Import queuedb functions
source "$QUEUEDB_SCRIPT_FILE" "$TASKS_FILE" "$TASKS_FILE_LOCK" "10" || { echo "Error: sourcing queuedb script file failed ($?)" 1>&2; exit 2; }
