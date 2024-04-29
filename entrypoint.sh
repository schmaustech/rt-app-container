#!/usr/bin/bash

exec /usr/bin/taskset -c ${CORE_MASK} /usr/local/bin/rt-app /rt-task.json
