FROM alpine:latest

# Install socat and netcat-openbsd for TCP proxying and healthcheck
RUN apk add --no-cache socat netcat-openbsd

# Expose port 80 (Railway will bind domain to this port)
# PORT environment variable will be set by Railway (defaults to 80)
EXPOSE 80

# Healthcheck - simple TCP check on PORT
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD sh -c 'PORT=${PORT:-80} && nc -z localhost $PORT || exit 1'

# Use socat to proxy TCP traffic from PORT to Neo4j Bolt port
# NEO4J_BOLT_HOST will be set to neo4j-deploy.railway.internal:7687
# PORT will be set by Railway (defaults to 80)
# Add verbose logging to see all traffic
CMD sh -c "PORT=\${PORT:-80} && TARGET=\${NEO4J_BOLT_HOST:-neo4j-deploy.railway.internal:7687} && echo \"[$(date)] Starting socat: listening on port \$PORT, proxying to \$TARGET\" && exec socat -v -d -d TCP-LISTEN:\$PORT,reuseaddr,fork TCP:\$TARGET"

