#!/bin/sh
# Entrypoint script for client container
# Substitutes environment variables in config.js and nginx.conf at runtime

set -e

# Substitute config.js
#
# ALLOWLIST FORM. The argument is the list of variables envsubst may replace;
# every other ${...} in the template is emitted LITERALLY. Adding a placeholder to
# config.js.template therefore does nothing until the name is listed here — and if
# it were forgotten, the literal text "${SHIPIT_HOST_KEY_FINGERPRINT}" would reach
# the browser and be presented to the operator as a fingerprint. Keep this list
# and config.js.template's placeholders in step.
#
# An unset variable substitutes to empty, which the client normalises back to
# "unconfigured". An unlisted one substitutes to literal text, which it cannot.
envsubst '${CONTROL_PLANE_API} ${SHIPIT_HOST_KEY_FINGERPRINT} ${SHIPIT_OPERATOR_NAME}' \
  < /usr/share/nginx/html/config.js.template > /usr/share/nginx/html/config.js

# Substitute nginx.conf
envsubst '${API_UPSTREAM}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Execute the original command (nginx)
exec "$@"