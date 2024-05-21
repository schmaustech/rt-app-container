FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3 as builder

RUN echo "builder:x:1001:" >> /etc/group && \
    echo "builder:x:1001:1001:Builder:/home/build:/bin/bash" >> /etc/passwd && \
    install -o builder -g builder -m 0700 -d /home/build

RUN microdnf -y install gcc git make numactl-devel numactl automake autoconf libfastjson json-glib libtool

WORKDIR /home/build

ARG ARCH=
RUN microdnf --enablerepo=codeready-builder-for-rhel-9-${ARCH}-rpms -y install json-c-devel 

USER 1001
RUN git clone https://github.com/scheduler-tools/rt-app.git && \
    cd rt-app && \
    # Grab updated multiarch rt-app patch based from Daniel's original patch updated with aarch64
    curl https://raw.githubusercontent.com/schmaustech/rt-app-container/main/multiarch_to_send_rt-app.patch > multiarch_to_send_rt-app.patch && \
    git apply multiarch_to_send_rt-app.patch && \
    ./autogen.sh && \
    ./configure && \
    make 

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3
RUN microdnf install -y numactl-devel numactl libfastjson json-glib libtool
RUN mkdir /jsons
RUN mkdir /log
COPY --from=builder /home/build/rt-app/src/rt-app /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
#COPY rt-task.json /
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
