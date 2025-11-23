FROM alpine:latest

# Install nginx for HTTP/WebSocket proxying
RUN apk add --no-cache nginx netcat-openbsd

# Create nginx directories
RUN mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/conf.d

# Expose port 80 (Railway will bind domain to this port)
# PORT environment variable will be set by Railway (defaults to 80)
EXPOSE 80

# Healthcheck - simple HTTP check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD sh -c 'PORT=${PORT:-80} && wget --quiet --tries=1 --spider http://localhost:$PORT/health || exit 1'

# Create startup script that generates nginx config dynamically
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'set -e' >> /start.sh && \
    echo 'PORT=${PORT:-80}' >> /start.sh && \
    echo 'TARGET=${NEO4J_BOLT_HOST:-neo4j-deploy.railway.internal:7687}' >> /start.sh && \
    echo 'echo "[$(date)] Starting Nginx on port $PORT, proxying to $TARGET"' >> /start.sh && \
    echo 'cat > /etc/nginx/nginx.conf <<EOF' >> /start.sh && \
    echo 'worker_processes auto;' >> /start.sh && \
    echo 'error_log /var/log/nginx/error.log warn;' >> /start.sh && \
    echo 'pid /var/run/nginx.pid;' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'events {' >> /start.sh && \
    echo '    worker_connections 1024;' >> /start.sh && \
    echo '}' >> /start.sh && \
    echo '' >> /start.sh && \
    echo 'http {' >> /start.sh && \
    echo '    include /etc/nginx/mime.types;' >> /start.sh && \
    echo '    default_type application/octet-stream;' >> /start.sh && \
    echo '    access_log /var/log/nginx/access.log;' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '    # Healthcheck endpoint' >> /start.sh && \
    echo '    server {' >> /start.sh && \
    echo '        listen 0.0.0.0:$PORT;' >> /start.sh && \
    echo '        server_name _;' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '        location /health {' >> /start.sh && \
    echo '            return 200 "healthy\n";' >> /start.sh && \
    echo '            add_header Content-Type text/plain;' >> /start.sh && \
    echo '        }' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '        # Proxy all traffic to Neo4j Bolt port' >> /start.sh && \
    echo '        # Neo4j Bolt can handle both HTTP and WebSocket connections' >> /start.sh && \
    echo '        location / {' >> /start.sh && \
    echo '            proxy_pass http://$TARGET;' >> /start.sh && \
    echo '            proxy_http_version 1.1;' >> /start.sh && \
    echo '            proxy_set_header Host $host;' >> /start.sh && \
    echo '            proxy_set_header X-Real-IP $remote_addr;' >> /start.sh && \
    echo '            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' >> /start.sh && \
    echo '            proxy_set_header X-Forwarded-Proto $scheme;' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '            # WebSocket support for Neo4j Browser' >> /start.sh && \
    echo '            proxy_set_header Upgrade $http_upgrade;' >> /start.sh && \
    echo '            proxy_set_header Connection "upgrade";' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '            # Timeouts' >> /start.sh && \
    echo '            proxy_connect_timeout 60s;' >> /start.sh && \
    echo '            proxy_send_timeout 60s;' >> /start.sh && \
    echo '            proxy_read_timeout 60s;' >> /start.sh && \
    echo '        }' >> /start.sh && \
    echo '    }' >> /start.sh && \
    echo '}' >> /start.sh && \
    echo 'EOF' >> /start.sh && \
    echo 'nginx -t' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
