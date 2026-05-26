#!/bin/bash
set -eux

dnf install -y docker
systemctl enable docker
systemctl start docker

docker pull stirlingtools/stirling-pdf:latest

cat > /etc/systemd/system/app.service <<'EOF'
[Unit]
Description=Stirling PDF
Requires=docker.service
After=docker.service network-online.target

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f stirling-pdf
ExecStart=/usr/bin/docker run --name stirling-pdf -p 80:8080 stirlingtools/stirling-pdf:latest
ExecStop=/usr/bin/docker stop stirling-pdf

[Install]
WantedBy=multi-user.target
EOF

# ALB health check hits port 8081 path /. App's responsibility to keep this
# answering 200 — decoupled from the main app so app port (80) and app
# behavior on `/` are independent of liveness signaling.
mkdir -p /srv/health
echo ok > /srv/health/index.html

cat > /etc/systemd/system/health.service <<'EOF'
[Unit]
Description=Health check responder (port 8081, ALB hits /)
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8081 --directory /srv/health
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app.service
systemctl enable health.service
