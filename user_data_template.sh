#!/bin/bash

sudo yum update -y
sudo yum install -y https://dl.grafana.com/oss/release/grafana-7.4.3-1.x86_64.rpm
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Set Grafana URL and API key
GRAFANA_API_KEY="${GRAFANA_API_KEY}"
GRAFANA_URL="http://${GRAFANA_PUBLIC_IP}:3000"


# Configure Grafana
sudo grafana-cli admin reset-admin-password "admin123"
sudo sed -i 's/;admin_user = admin/admin_user = admin/' /etc/grafana/grafana.ini
sudo sed -i "s/;admin_password = admin/admin_password = $GRAFANA_API_KEY/" /etc/grafana/grafana.ini
sudo sed -i 's/;http_port = 3000/http_port = 3000/' /etc/grafana/grafana.ini
sudo sed -i "s/;domain = localhost/domain = $GRAFANA_URL/" /etc/grafana/grafana.ini

# Restart Grafana
sudo systemctl restart grafana-server

# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.30.0/prometheus-2.30.0.linux-amd64.tar.gz
tar xvfz prometheus-2.30.0.linux-amd64.tar.gz
cd prometheus-2.30.0.linux-amd64/
nohup ./prometheus > /dev/null 2>&1 &

# Install Node Exporter
sudo useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.2.2.linux-amd64.tar.gz
cd node_exporter-1.2.2.linux-amd64/
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create Node Exporter service file
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF2
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF2

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "Grafana, Prometheus, and Node Exporter installation finished!"
