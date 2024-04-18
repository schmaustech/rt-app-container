#!/usr/bin/bash
exec /usr/bin/taskset ${CORE_MASK} /usr/local/bin/rt-app /home/builder/rt-task.json
