FROM redis:5.0
USER root

RUN echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >>/etc/rc.local \
    && chmod +x /etc/rc.local

