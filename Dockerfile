FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        xl2tpd \
        ppp \
        iproute2 \
        iputils-ping \
        openssh-client \
        sshpass \
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
RUN chmod +x /entrypoint.sh /usr/local/bin/ssh-target

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
