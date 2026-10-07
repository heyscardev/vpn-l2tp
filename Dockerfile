FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        xl2tpd \
        ppp \
        iproute2 \
        iputils-ping \
        openssh-client \
        sshpass \
        socat \
        gettext-base \
        net-tools \
        procps \
        ca-certificates \
        less \
        vim-tiny \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Carpeta de configuración y control
RUN mkdir -p /var/run/xl2tpd /etc/xl2tpd /etc/ppp

COPY config/ /config/
COPY entrypoint.sh /entrypoint.sh
COPY ssh-target /usr/local/bin/ssh-target
COPY db-forward /usr/local/bin/db-forward
RUN chmod +x /entrypoint.sh /usr/local/bin/ssh-target /usr/local/bin/db-forward \
    && echo '[ -f /config/auto-ssh.sh ] && . /config/auto-ssh.sh' >> /root/.bashrc

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
