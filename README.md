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