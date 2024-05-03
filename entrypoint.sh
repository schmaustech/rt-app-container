#!/bin/bash
# Pass single template json
if [ $TYPE == "single" ]; then
	/usr/local/bin/rt-app /jsons/$i.json
fi
# Pass three individual jsons
if [ $TYPE == "three" ] || [ $TYPE == "broken" ]; then
	NAME=$i-onems
	/usr/local/bin/rt-app /jsons/$NAME.json &
	NAME=$i-fivems
	/usr/local/bin/rt-app /jsons/$NAME.json &
	NAME=$i-tenms
	/usr/local/bin/rt-app /jsons/$NAME.json &

fi
