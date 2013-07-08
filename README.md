# Yet another the simplest tasks queue
1. the simplest task queue writed on bash
2. every task is a bash command
3. tasks run in a parallel mode (you could hardcode quantity of parallel tasks or select it automatically with cores quantity)
4. it is possible to add success (exit code 0) and fail (exit code not 0) handlers for every task

## Installation:
1. do chmod a+x worker.sh manager.sh queue.sh
2. copy yastq.conf.sample to ~/.yastq.conf or to /etc/yastq.conf

## Use:
1. ./yastq.sh and see usage

## Examples:
### Starting:
1. ./yastq.sh start

### Adding tasks:

#### Simple adding of a new task
1. ./yastq.sh add-task task "/bin/sleep 5s && /bin/echo Hello, $(id -un) | /usr/bin/write $(id -un)"

#### Adding of a new task with status handlers
1. ./yastq.sh add-task \
	task "/bin/sleep 5s && /bin/echo Hello again, $(id -un) | /usr/bin/write $(id -un)" \
	success "echo Ok > /tmp/queuetest" \
	fail "echo Fail > /tmp/queuetest"
2. ./yastq.sh add-task \
	task "/bin/sleep 5s && /bin/echo Hello again, $(id -un) \!\!\! | /usr/bin/write $(id -un) && /bin/false" \
	success "echo Ok > /tmp/queuetest" \
	fail "echo Fail > /tmp/queuetest"

### Checking status
1. ./yastq.sh status

### Stopping:
1. ./yastq.sh stop
