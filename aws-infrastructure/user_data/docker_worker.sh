#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Configure Docker daemon
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install additional monitoring tools
apt-get install -y htop iotop sysstat bc jq

# Install Python and pip for applications
apt-get install -y python3 python3-pip
pip3 install flask psutil requests

# Wait for Docker to be fully ready
sleep 30

# Create a script to join the swarm (will be executed after manager is ready)
cat > /home/ubuntu/join-swarm.sh <<EOF
#!/bin/bash
# Wait for manager to be ready and then join the swarm
MANAGER_IP="${manager_ip}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; do
    echo "Attempting to join swarm (attempt \$((RETRY_COUNT + 1))/\$MAX_RETRIES)..."
    
    # Try to get join token from manager
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@\$MANAGER_IP "cat /home/ubuntu/swarm-join-command.sh" > /tmp/join-command.sh 2>/dev/null; then
        echo "Got join command from manager"
        chmod +x /tmp/join-command.sh
        if sudo /tmp/join-command.sh; then
            echo "Successfully joined Docker Swarm"
            break
        fi
    fi
    
    RETRY_COUNT=\$((RETRY_COUNT + 1))
    sleep 10
done

if [ \$RETRY_COUNT -eq \$MAX_RETRIES ]; then
    echo "Failed to join swarm after \$MAX_RETRIES attempts"
    echo "Manual join may be required"
fi
EOF

chmod +x /home/ubuntu/join-swarm.sh
chown ubuntu:ubuntu /home/ubuntu/join-swarm.sh

# Create a script to check if this node is part of swarm
cat > /home/ubuntu/check-swarm-status.sh <<'EOF'
#!/bin/bash
echo "Docker Swarm Node Status:"
if docker info | grep -q "Swarm: active"; then
    echo "This node is part of a Docker Swarm"
    docker node ls 2>/dev/null || echo "Cannot list nodes (worker node limitation)"
else
    echo "This node is NOT part of a Docker Swarm"
fi
EOF

chmod +x /home/ubuntu/check-swarm-status.sh
chown ubuntu:ubuntu /home/ubuntu/check-swarm-status.sh

echo "Docker Swarm worker setup completed" > /home/ubuntu/setup-complete.log

# Create a directory for the Flask application
mkdir -p /home/ubuntu/flask-app
chown ubuntu:ubuntu /home/ubuntu/flask-app