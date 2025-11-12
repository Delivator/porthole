FROM alpine:latest

# Install autossh, openssh-client and other utilities
RUN apk update && apk add --no-cache \
    autossh \
    openssh-client \
    bash \
    curl \
    tzdata

# Create directory for SSH keys and known_hosts
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Create directory for scripts
RUN mkdir -p /app

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set environment variables with defaults
ENV SSH_REMOTE_HOST="" \
    SSH_REMOTE_PORT="22" \
    SSH_REMOTE_USER="" \
    SSH_TUNNEL_LOCAL_PORT="" \
    SSH_TUNNEL_REMOTE_PORT="" \
    SSH_TUNNEL_REMOTE_HOST="localhost" \
    SSH_TUNNEL_TYPE="remote" \
    SSH_EXTRA_ARGS="" \
    AUTOSSH_GATETIME="0" \
    AUTOSSH_PORT="0" \
    AUTOSSH_POLL="60" \
    AUTOSSH_FIRST_POLL="30" \
    AUTOSSH_LOGLEVEL="1" \
    AUTOSSH_LOGFILE="/dev/stdout" \
    SSH_STRICT_HOST_KEY_CHECKING="no" \
    TZ="UTC"

WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
