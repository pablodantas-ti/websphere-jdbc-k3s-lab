#!/bin/bash
set -euo pipefail
umask 077
test -s /run/lab-admin/password
test -s /run/lab-db/app-password
# The original IBM startup consumes /tmp/PASSWORD and sets wsadmin's password.
cat /run/lab-admin/password > /tmp/PASSWORD
rm -f /tmp/lab-auth-ok
/opt/IBM/WebSphere/AppServer/bin/wsadmin.sh -lang jython -conntype NONE -f /work/lab/runtime-auth.py
test -f /tmp/lab-auth-ok
exec /bin/bash /work/start_server.sh
