#!/bin/bash
echo "Enable DEADLINE hrtick..."
echo HRTICK_DL > /sys/kernel/debug/sched/features
echo "Allow real-time tasks may use up to 100% of CPU times..."
sysctl kernel.sched_rt_runtime_us=-1
echo "Set preemptive scheduling to full..."
echo full > /sys/kernel/debug/sched/preempt
echo "Creating log and json directories..."
if [ ! -d log ]; then
	mkdir log
fi

if [ ! -d jsons ]; then
	mkdir jsons
fi
echo "Set variable values for run..."
# Type should be one of the following: single, three, broken
TYPE="three"
CPUS="5"
EXEC_TIME=50
DL_RUNTIME=100
DL_PERIOD=1000
DELAY=0
STEP=200000
DURATION=60
CURRPATH=`pwd`

# Update basic.json to reflect CPU used
sed -i "s/\"cpus\" :.*/\"cpus\" : [ ${CPUS} ],/" basic.json

# You need to measure CAL on the CPU where you will run
# the workload. Use the command bellow to get it. It is
# the pLoad in the output. We need to know it in advance
# because one workload interfere with the other if they all
# measure at the same time.
#
# Once you know it, write it in the CAL bellow, otherwise
# let the script figure it out.
echo "Measure the CAL for core $CPUS..."
CAL=
if [ x$CAL == x ]; then
	CAL=`rt-app basic.json 2>&1 | grep pLoad |  awk '{print $5}' | sed 's/ns//'`
fi

echo "Build up test json files..."
for i in UN DEUX TROIS; do
	case $TYPE in
		single)
			cat template.json | sed "s/NAME/$i/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$i.json
			let "DELAY=$DELAY + $STEP"
			;;
		three)
			EXEC_TIME=50
			DL_RUNTIME=75
			DL_PERIOD=1000
			NAME=$i-onems

			cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json

       			EXEC_TIME=250
        		DL_RUNTIME=300
        		DL_PERIOD=5000
        		NAME=$i-fivems

			cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json


        		EXEC_TIME=500
        		DL_RUNTIME=600
        		DL_PERIOD=10000
        		NAME=$i-tenms

        		cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json

			let "DELAY=$DELAY + $STEP"
			;;
		broken)	
		        EXEC_TIME=50
                        DL_RUNTIME=75
                        DL_PERIOD=1000
                        NAME=$i-onems

                        cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json

                        EXEC_TIME=100000
                        DL_RUNTIME=300
                        DL_PERIOD=5000
                        NAME=$i-fivems

                        cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json


                        EXEC_TIME=500
                        DL_RUNTIME=600
                        DL_PERIOD=10000
                        NAME=$i-tenms

                        cat single.json | sed "s/NAME/$NAME/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$NAME.json

                        let "DELAY=$DELAY + $STEP"
			;;

		*)
                        cat template.json | sed "s/NAME/$i/g; s/CAL/$CAL/g; s/CPUS/$CPUS/g; s/EXEC_TIME/$EXEC_TIME/ ; s/DL_RUNTIME/$DL_RUNTIME/ ; s/DL_PERIOD/$DL_PERIOD/ ; s/DURATION/$DURATION/g ; s/DELAY/$DELAY/g " > jsons/$i.json
                        let "DELAY=$DELAY + $STEP"
                        ;;
		esac
done
echo "Create and run the pods..."
for i in UN DEUX TROIS; do
			podman create --privileged --name $i-container -e TYPE=$TYPE -e i=$i -v $CURRPATH/jsons:/jsons -v $CURRPATH/log:/log quay.io/bschmaus/rt-app-container:latest
			podman start $i-container
			sleep 1 # to let the threads be created and have sequencial pid.. easier to see on kernelshark
done
echo "Gather the trace-cmd recording..."
trace-cmd record -e sched:sched_wakeup -e sched:sched_switch sleep 60

sleep 10

# Remove all the pods we generated
echo "Cleanup the pods..."
podman rm -a
