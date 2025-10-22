#!/bin/bash

# OpenTAK Server Data Check Script
# This script checks if ATAK data is being received and processed

echo "==================================="
echo "OpenTAK Server Data Check"
echo "==================================="
echo ""

# Check if we're root or have sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo or as root"
    exit 1
fi

# Check services
echo "1. Checking Services..."
systemctl is-active opentakserver eud_handler eud_handler_ssl rabbitmq-server | while read status; do
    if [ "$status" = "active" ]; then
        echo "  ✓ Service active"
    else
        echo "  ✗ Service not active: $status"
    fi
done
echo ""

# Check connections
echo "2. Checking Active Connections..."
echo "  TCP (8089):"
lsof -i :8089 -n -P 2>/dev/null | grep ESTABLISHED | wc -l | xargs echo "    Connections:"
echo "  SSL (8446):"
lsof -i :8446 -n -P 2>/dev/null | grep ESTABLISHED | wc -l | xargs echo "    Connections:"
echo ""

# Check database
echo "3. Checking Database..."
cd /home/opentakserver/OpenTAKServer
sudo -u opentakserver bash -c "source opentakserver_venv/bin/activate && python << 'EOF'
from opentakserver.app import create_app, db
from opentakserver.models.EUD import EUD
from opentakserver.models.CoT import CoT
from opentakserver.models.Point import Point
from opentakserver.models.Marker import Marker

app = create_app()
app.app_context().push()

print(f\"  Connected Devices (EUD): {EUD.query.count()}\")
euds = EUD.query.all()
for e in euds:
    print(f\"    - {e.callsign} ({e.uid})\")
    print(f\"      Last seen: {e.last_event_time}\")

print(f\"\\n  CoT Messages: {CoT.query.count()}\")
print(f\"  Points: {Point.query.count()}\")
print(f\"  Markers: {Marker.query.count()}\")

if Marker.query.count() > 0:
    print(\"\\n  Recent Markers:\")
    for m in Marker.query.order_by(Marker.created_timestamp.desc()).limit(5):
        print(f\"    - {m.sender_callsign}: {m.created_timestamp}\")
EOF
" 2>/dev/null
echo ""

# Check RabbitMQ
echo "4. Checking RabbitMQ Queues..."
rabbitmqctl list_queues 2>/dev/null | grep -v "^Timeout" | grep -v "^Listing" | grep -v "^name" | while read queue count; do
    echo "  Queue: $queue - Messages: $count"
done
echo ""

# Check recent logs
echo "5. Recent Activity (last 5 minutes)..."
echo "  SSL Handler:"
journalctl -u eud_handler_ssl --since "5 minutes ago" -n 5 --no-pager 2>/dev/null | tail -3 | sed 's/^/    /'
echo "  OpenTAK Server:"
journalctl -u opentakserver --since "5 minutes ago" -n 5 --no-pager 2>/dev/null | tail -3 | sed 's/^/    /'
echo ""

echo "==================================="
echo "Check Complete"
echo "==================================="
echo ""
echo "INTERPRETATION:"
echo "- If you see your device listed but CoT/Markers = 0:"
echo "  → Device is connected but markers aren't being saved"
echo "  → Try placing a NAMED marker with specific type in ATAK"
echo "  → Check if real-time position shows on Web UI map"
echo ""
echo "- If RabbitMQ queues have messages:"
echo "  → Data is queued but not being processed"
echo "  → Check opentakserver logs for errors"
echo ""
echo "- If everything is 0:"
echo "  → Data might not be reaching the server"
echo "  → Check ATAK connection status and try sending test marker"
echo ""