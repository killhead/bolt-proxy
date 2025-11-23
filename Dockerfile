FROM alpine:latest

# Install haproxy for TCP proxying (better than socat for this use case)
RUN apk add --no-cache haproxy netcat-openbsd

# Create haproxy config directory
RUN mkdir -p /etc/haproxy

# Expose port 80 (Railway will bind domain to this port)
# PORT environment variable will be set by Railway (defaults to 80)
EXPOSE 80

# Healthcheck - simple TCP check on PORT
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD sh -c 'PORT=${PORT:-80} && nc -z localhost $PORT || exit 1'

# Create startup script that generates haproxy config dynamically
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo 'PORT=${PORT:-80}' >> /start.sh && \
    echo 'TARGET=${NEO4J_BOLT_HOST:-neo4j-deploy.railway.internal:7687}' >> /start.sh && \
    echo 'echo "[$(date)] Starting HAProxy on port $PORT, proxying to $TARGET"' >> /start.sh && \
    echo 'cat > /etc/haproxy/haproxy.cfg <<EOF' >> /start.sh && \
    echo 'global' >> /start.sh && \
    echo '    daemon' >> /start.sh && \
    echo '    maxconn 4096' >> /start.sh && \
    echo '    log stdout local0' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'defaults' >> /start.sh && \
    echo '    mode tcp' >> /start.sh && \
    echo '    log global' >> /start.sh && \
    echo '    option tcplog' >> /start.sh && \
    echo '    timeout connect 5000ms' >> /start.sh && \
    echo '    timeout client 50000ms' >> /start.sh && \
    echo '    timeout server 50000ms' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'frontend neo4j_bolt' >> /start.sh && \
    echo '    bind *:$PORT' >> /start.sh && \
    echo '    default_backend neo4j_backend' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'backend neo4j_backend' >> /start.sh && \
    echo '    server neo4j $TARGET check' >> /start.sh && \
    echo 'EOF' >> /start.sh && \
    echo 'exec haproxy -f /etc/haproxy/haproxy.cfg' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
