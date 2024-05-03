#!/bin/bash
# Pass single template json
if [ $TYPE == "single" ]; then
	/usr/local/bin/rt-app /jsons/$i.json
fi
# Pass three individual jsons
if [ $TYPE == "three" ] || [ $TYPE == "broken" ]; then
	/usr/local/bin/rt-app /jsons/$i-onems.json &
	/usr/local/bin/rt-app /jsons/$i-fivems.json &
	/usr/local/bin/rt-app /jsons/$i-tenms.json 
fi
