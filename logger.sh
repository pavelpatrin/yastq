#!/bin/bash

##
## 
##
## This script must be sourced with:
##	$1 - Path to date binary
##	$2 - Path to logs directory
##	$3 - Logging level
##
## Logging level is bitwise mask:
##  1  - Log errors
##  2  - Log warnings
##  4  - Log infos
##  8  - Log debugs
##  16 - Log traces
##

# Arguments
LOGGER_LOG_DIR=$1
LOGGER_LOG_LEVEL=$2

# Check arguments
[ -n "$LOGGER_LOG_DIR" -a -x "$LOGGER_LOG_DIR" -a -w "$LOGGER_LOG_DIR" ] || return 2
[ -n "$LOGGER_LOG_LEVEL" ] || return 2

##
## Sends message to log with ERROR logging level
##
log_error()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOGGER_LOG_LEVEL & 1 )) && echo "[$(date '+%F %T.%N')][$LOG_SOURCE $$][ERROR] $LOG_MESSAGE" >> "$LOGGER_LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with WARN logging level
##
log_warn()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOGGER_LOG_LEVEL & 2 )) && echo "[$(date '+%F %T.%N')][$LOG_SOURCE $$][WARN]  $LOG_MESSAGE" >> "$LOGGER_LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with INFO logging level
##
log_info()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOGGER_LOG_LEVEL & 4 )) && echo "[$(date '+%F %T.%N')][$LOG_SOURCE $$][INFO]  $LOG_MESSAGE" >> "$LOGGER_LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with DEBUG logging level
##
log_debug()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOGGER_LOG_LEVEL & 8 )) && echo "[$(date '+%F %T.%N')][$LOG_SOURCE $$][DEBUG] $LOG_MESSAGE" >> "$LOGGER_LOG_DIR/$LOG_SOURCE.log"
}

##
## Sends message to log with TRACE logging level
##
log_trace()
{
	local LOG_SOURCE=$1
	local LOG_MESSAGE=$2
	(( $LOGGER_LOG_LEVEL & 16 )) && echo "[$(date '+%F %T.%N')][$LOG_SOURCE $$][TRACE] $LOG_MESSAGE" >> "$LOGGER_LOG_DIR/$LOG_SOURCE.log"
}
