FROM alpine:latest

# Install HAProxy for advanced TCP/HTTP/WebSocket proxying
RUN apk add --no-cache haproxy netcat-openbsd wget

# Create haproxy directories
RUN mkdir -p /var/lib/haproxy /run/haproxy

# Expose port 80 (Railway will bind domain to this port)
EXPOSE 80

# Healthcheck - simple TCP check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD sh -c 'PORT=${PORT:-80} && nc -z localhost $PORT || exit 1'

# Create startup script that generates HAProxy config dynamically
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo 'PORT=${PORT:-80}' >> /start.sh && \
    echo 'TARGET=${NEO4J_BOLT_HOST:-neo4j-deploy.railway.internal:7687}' >> /start.sh && \
    echo 'echo "[$(date)] Starting HAProxy on port $PORT, proxying to $TARGET"' >> /start.sh && \
    echo 'cat > /etc/haproxy/haproxy.cfg <<'\''ENDOFFILE'\''' >> /start.sh && \
    echo 'global' >> /start.sh && \
    echo '    log stdout format raw local0' >> /start.sh && \
    echo '    daemon' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'defaults' >> /start.sh && \
    echo '    mode tcp' >> /start.sh && \
    echo '    log global' >> /start.sh && \
    echo '    option tcplog' >> /start.sh && \
    echo '    timeout connect 10s' >> /start.sh && \
    echo '    timeout client 1m' >> /start.sh && \
    echo '    timeout server 1m' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'frontend neo4j_bolt_frontend' >> /start.sh && \
    echo '    bind *:__PORT__' >> /start.sh && \
    echo '    default_backend neo4j_bolt_backend' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'backend neo4j_bolt_backend' >> /start.sh && \
    echo '    server neo4j __TARGET__ check' >> /start.sh && \
    echo 'ENDOFFILE' >> /start.sh && \
    echo 'sed "s|__PORT__|$PORT|g; s|__TARGET__|$TARGET|g" /etc/haproxy/haproxy.cfg > /tmp/haproxy.cfg && mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg' >> /start.sh && \
    echo 'haproxy -f /etc/haproxy/haproxy.cfg -c' >> /start.sh && \
    echo 'exec haproxy -f /etc/haproxy/haproxy.cfg -db' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
