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

# Cliente PostgreSQL del repo oficial (PGDG): pg_dump debe ser >= versión del servidor.
ARG PG_CLIENT_VERSION=17
RUN install -d /usr/share/postgresql-common/pgdg \
    && curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
        https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client-${PG_CLIENT_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Carpeta de configuración y control
RUN mkdir -p /var/run/xl2tpd /etc/xl2tpd /etc/ppp

COPY config/ /config/
COPY entrypoint.sh /entrypoint.sh
COPY ssh-target /usr/local/bin/ssh-target
COPY db-forward /usr/local/bin/db-forward
COPY db-backup /usr/local/bin/db-backup
RUN chmod +x /entrypoint.sh /usr/local/bin/ssh-target /usr/local/bin/db-forward /usr/local/bin/db-backup \
    && echo '[ -f /config/auto-ssh.sh ] && . /config/auto-ssh.sh' >> /root/.bashrc

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
