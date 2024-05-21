# Containerizing rt-app for Real Time Testing

Welcome to my sample container build for the rt-app.

**Goal**: Document the process for building a RHEL 9 container that contains the rt-app.

## What Is rt-app?

rt-app is a test application that starts multiple periodic threads in order to
simulate a real-time periodic load.

Code is currently maintained on GitHub:

[RT-APP Repository](https://github.com/scheduler-tools/rt-app)

## Background

The following work really builds upon the efforts Daniel Bristot de Oliveira of Red Hat built out in the following [reposititory](https://gitlab.com/rt-linux-tools/rt_consolidation_ex/-/tree/dirty?ref_type=heads).  This work is based on explanations from Daniel about how to use multiple real-time workloads in a same CPU, consolidating applications trying to provide low response times/jitter for real-time tasks.  Within that body of work were a few examples of that explaination and usage.   Here in this repository we will take that effort and leverage it via a container.

## Contents of Repository

* Dockerfile - To build the container to run the tests
* entrypoint.sh - The script that runs within the container to kickoff the rt-app workload test
* run.sh - The script that takes Daniel's work [here](https://gitlab.com/rt-linux-tools/rt_consolidation_ex/-/tree/dirty?ref_type=heads) and collapses it into one script and launches rt-app via containers.
* basic.json - This is used to compute the CAL (Function Call Interrupt) on a core
* single.json - Example json
* template.json - Example json

### Build the Container

We can build the container using the files in the repository.  This container build process has been tested on both x86_64 and aarch64.

~~~bash
# podman build -f Dockerfile --build-arg ARCH=`uname -i` -t quay.io/bschmaus/rt-app-container:latest
[1/2] STEP 1/7: FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3 AS builder
[1/2] STEP 2/7: RUN echo "builder:x:1001:" >> /etc/group &&     echo "builder:x:1001:1001:Builder:/home/build:/bin/bash" >> /etc/passwd &&     install -o builder -g builder -m 0700 -d /home/build
--> Using cache 3a05dd8b2a4da05ef3af9f0ed71ad3033f7f9ecd36c1554a9fc12237f39a41a6
--> 3a05dd8b2a4d
(...)
[2/2] STEP 11/11: ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
[2/2] COMMIT quay.io/bschmaus/rt-app-container:latest
--> c7764c58580b
Successfully tagged quay.io/bschmaus/rt-app-container:latest
c7764c58580b549c18f1a2cf59194e8657620d12289573861640f608b9f0a1fe
~~~

### Test Framework

We will be doing our testing on a Red Hat Enterprise Linux 9.3 system with low latency tuned profiles.  

~~~bash
# uname -a
Linux edge-24.edge.lab.eng.rdu2.redhat.com 5.14.0-362.8.1.el9_3.x86_64 #1 SMP PREEMPT_DYNAMIC Tue Oct 3 11:12:36 EDT 2023 x86_64 x86_64 x86_64 GNU/Linux
# cat /etc/redhat-release
Red Hat Enterprise Linux release 9.3 (Plow)
~~~


The first step we need to perform is to install the `tuned-profiles-realtime` and `tuned`.   I should note here that for aarch64 I needed to manually download the `tuned-profiles-realtime` from [Red Hat Portal](https://access.redhat.com) because even though the rpm package is a noarch it is only available in the x86_64 repos.  

~~~bash
# dnf install tuned tuned-profiles-realtime
Updating Subscription Management repositories.
Last metadata expiration check: 0:55:11 ago on Tue 23 Apr 2024 01:02:02 PM EDT.
Package tuned-2.21.0-1.el9_3.noarch is already installed.
Dependencies resolved.
==============================================================================================================================================================================================================================================
 Package                                                           Architecture                                     Version                                                     Repository                                               Size
==============================================================================================================================================================================================================================================
Installing:
 tuned-profiles-realtime                                           noarch                                           2.21.0-1.el9_3                                              beaker-NFV                                               15 k
Installing dependencies:
 tuna                                                              noarch                                           0.18-12.el9                                                 beaker-BaseOS                                           166 k

Transaction Summary
==============================================================================================================================================================================================================================================
Install  2 Packages

Total download size: 182 k
Installed size: 590 k
Is this ok [y/N]: y
Downloading Packages:
(1/2): tuned-profiles-realtime-2.21.0-1.el9_3.noarch.rpm                                                                                                                                                      1.7 MB/s |  15 kB     00:00    
(2/2): tuna-0.18-12.el9.noarch.rpm                                                                                                                                                                             14 MB/s | 166 kB     00:00    
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                                                          14 MB/s | 182 kB     00:00     
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                                                      1/1 
  Installing       : tuna-0.18-12.el9.noarch                                                                                                                                                                                              1/2 
  Installing       : tuned-profiles-realtime-2.21.0-1.el9_3.noarch                                                                                                                                                                        2/2 
  Running scriptlet: tuned-profiles-realtime-2.21.0-1.el9_3.noarch                                                                                                                                                                        2/2 
  Verifying        : tuna-0.18-12.el9.noarch                                                                                                                                                                                              1/2 
  Verifying        : tuned-profiles-realtime-2.21.0-1.el9_3.noarch                                                                                                                                                                        2/2 
Installed products updated.
Installed:
  tuna-0.18-12.el9.noarch                                                                                    tuned-profiles-realtime-2.21.0-1.el9_3.noarch                                                                          
Complete!
~~~

With the tuned profiles installed lets determine which cores we would like to set isolated.

~~~bash
# numactl --hardware
available: 1 nodes (0)
node 0 cpus: 0 1 2 3 4 5 6 7
node 0 size: 63628 MB
node 0 free: 60714 MB
node distances:
node   0 
  0:  10 
~~~

Since everything is in one NUMA here we are just going to isolate cores 4-7 for our testing.  To prepare for that we need to edit the following file `/etc/tuned/realtime-variables.conf
` and set the `isolcpus`.  Since the default setting in the file is `isolated_cores=\${f:calc_isolated_cores:1}` we can use a simple sed to make our change.

~~~bash
# sed -i s/isolated_cores=\${f:calc_isolated_cores:1}/isolated_cores=4-7/g /etc/tuned/realtime-variables.conf

# cat /etc/tuned/realtime-variables.conf|grep ^isolated_cores
isolated_cores=4-7
~~~

Now let's set the tuned profile and reboot for the changes to take effect.

~~~bash
# tuned-adm profile realtime

# reboot
~~~

To capture a kernel trace which we can view with KernelShark we will need to install `trace-cmd`

~~~bash
# dnf install -y trace-cmd
Updating Subscription Management repositories.
Last metadata expiration check: 1:43:35 ago on Tue 23 Apr 2024 01:02:02 PM EDT.
Dependencies resolved.
==============================================================================================================================================================================================================================================
 Package                                                   Architecture                                         Version                                                     Repository                                                   Size
==============================================================================================================================================================================================================================================
Installing:
 trace-cmd                                                 x86_64                                               2.9.2-10.el9                                                beaker-BaseOS                                               233 k
Installing dependencies:
 libtracecmd                                               x86_64                                               0-10.el9                                                    beaker-BaseOS                                               100 k
 libtracefs                                                x86_64                                               1.3.1-1.el9                                                 beaker-BaseOS                                                75 k

Transaction Summary
==============================================================================================================================================================================================================================================
Install  3 Packages

Total download size: 408 k
Installed size: 893 k
Is this ok [y/N]: y
Downloading Packages:
(1/3): libtracecmd-0-10.el9.x86_64.rpm                                                                                                                                                                        6.4 MB/s | 100 kB     00:00    
(2/3): libtracefs-1.3.1-1.el9.x86_64.rpm                                                                                                                                                                      4.2 MB/s |  75 kB     00:00    
(3/3): trace-cmd-2.9.2-10.el9.x86_64.rpm                                                                                                                                                                       11 MB/s | 233 kB     00:00    
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                                                                          19 MB/s | 408 kB     00:00     
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                                                      1/1 
  Installing       : libtracefs-1.3.1-1.el9.x86_64                                                                                                                                                                                        1/3 
  Installing       : libtracecmd-0-10.el9.x86_64                                                                                                                                                                                          2/3 
  Installing       : trace-cmd-2.9.2-10.el9.x86_64                                                                                                                                                                                        3/3 
  Running scriptlet: trace-cmd-2.9.2-10.el9.x86_64                                                                                                                                                                                        3/3 
  Verifying        : libtracecmd-0-10.el9.x86_64                                                                                                                                                                                          1/3 
  Verifying        : libtracefs-1.3.1-1.el9.x86_64                                                                                                                                                                                        2/3 
  Verifying        : trace-cmd-2.9.2-10.el9.x86_64                                                                                                                                                                                        3/3 
Installed products updated.

Installed:
  libtracecmd-0-10.el9.x86_64                                                  libtracefs-1.3.1-1.el9.x86_64                                                  trace-cmd-2.9.2-10.el9.x86_64                                                 
Complete!
~~~

### Running a Test

After we have built our container and have installed and configured out how we can run a test.  The `run.sh` script can peform three different tests which are defined by the TYPE variable inside the script.  Those tests are: single, three and broken.  In our test below we set the TYPE to `three` and CPUS to core `5`.   Then ran the test which looks like the following:

~~~bash
# ./run.sh
Enable DEADLINE hrtick...
Allow real-time tasks may use up to 100% of CPU times...
sysctl: setting key "kernel.sched_rt_runtime_us": Device or resource busy
Set preemptive scheduling to full...
Creating log and json directories...
Set variable values for run...
Measure the CAL for core 5...
Build up test json files...
Create and run the pods...
34e09802149a25585d54f7ed2117202b69afa5619c08312e19e190d174a2842b
UN-container
5763bf6938629ef3cb2985a927a7978a64617fe0e937543b2b752b588507f773
DEUX-container
70671f8e1b42a7548f6515399ac8e3a8ad4087285e39e2ffcc049ef5db847df3
TROIS-container
Gather the trace-cmd recording...
CPU0 data recorded at offset=0xaba000
    294912 bytes in size
CPU1 data recorded at offset=0xb02000
    520192 bytes in size
CPU2 data recorded at offset=0xb81000
    360448 bytes in size
CPU3 data recorded at offset=0xbd9000
    303104 bytes in size
CPU4 data recorded at offset=0xc23000
    0 bytes in size
CPU5 data recorded at offset=0xc23000
    39940096 bytes in size
CPU6 data recorded at offset=0x323a000
    0 bytes in size
CPU7 data recorded at offset=0x323a000
    0 bytes in size
Cleanup the pods...
5763bf6938629ef3cb2985a927a7978a64617fe0e937543b2b752b588507f773
34e09802149a25585d54f7ed2117202b69afa5619c08312e19e190d174a2842b
70671f8e1b42a7548f6515399ac8e3a8ad4087285e39e2ffcc049ef5db847df3
~~~

Once the test has run take the trace.dat output and look at it in KernelShark!

