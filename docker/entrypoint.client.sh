#!/bin/sh
# Entrypoint script for client container
# Substitutes environment variables in config.js and nginx.conf at runtime

set -e

# Substitute config.js
envsubst '${CONTROL_PLANE_API}' < /usr/share/nginx/html/config.js.template > /usr/share/nginx/html/config.js

# Substitute nginx.conf
envsubst '${API_UPSTREAM}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Execute the original command (nginx)
exec "$@"