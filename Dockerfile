FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3 as builder

RUN echo "builder:x:1001:" >> /etc/group && \
    echo "builder:x:1001:1001:Builder:/home/build:/bin/bash" >> /etc/passwd && \
    install -o builder -g builder -m 0700 -d /home/builder

RUN microdnf -y install gcc git make numactl-devel numactl automake autoconf libfastjson json-glib libtool

WORKDIR /home/build
#COPY --chown=1001:1001 0001-Add-cyclicstress-application-same-as-cyclictest.patch /home/build
COPY --chown=1001:1001 rt-task.json /home/build

# Copy entitlements
COPY --chown=0:0 --chmod=644 ./entitlement/* /etc/pki/entitlement
# Copy subscription manager configurations
COPY --chown=0:0 --chmod=644 ./rhsm.conf /etc/rhsm/rhsm.conf
CMD mkdir /etc/rhsm/ca
COPY --chown=0:0 --chmod=644 ./ca /etc/rhsm/ca
RUN rm /etc/rhsm-host && \
    microdnf repolist --disablerepo=* && \
    microdnf --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms -y install json-c-devel && \
    rm -rf /etc/pki/entitlement && \
    rm -rf /etc/rhsm

USER 1001
#RUN git config --global user.name "Builder" && \
#    git config --global user.email "builder@acme.com" && \
RUN git clone https://github.com/scheduler-tools/rt-app.git && \
    cd rt-app && \
    #git checkout 8c7532b710390882ffd7e96d50e75fce99a8249f && \
    #mv /home/build/0001-Add-cyclicstress-application-same-as-cyclictest.patch . && \
    #git am 0001-Add-cyclicstress-application-same-as-cyclictest.patch && \
    ./autogen.sh && \
    ./configure && \
    make 

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3
RUN microdnf install -y gcc git make numactl-devel numactl automake autoconf libfastjson json-glib libtool
COPY --from=builder /home/build/rt-app/src/rt-app /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rt-task.json /
RUN chmod +x /usr/local/bin/entrypoint.sh
ENV CORE_MASK="0x5"
ENV PRIORITY="99"
ENV LOADCPU="10"
ENV INTERVAL="1000"
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
