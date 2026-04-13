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
apt-get install -y htop iotop sysstat bc jq unzip

# Install Python and pip for applications
apt-get install -y python3 python3-pip
pip3 install flask psutil requests

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Wait for Docker to be fully ready
sleep 30

# Initialize Docker Swarm
docker swarm init --advertise-addr $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Get the join token for workers
docker swarm join-token worker | grep "docker swarm join" > /home/ubuntu/swarm-join-command.sh
chmod +x /home/ubuntu/swarm-join-command.sh
chown ubuntu:ubuntu /home/ubuntu/swarm-join-command.sh

# Create a simple script to check swarm status
cat > /home/ubuntu/check-swarm.sh <<'EOF'
#!/bin/bash
echo "Docker Swarm Status:"
docker node ls
echo ""
echo "Running Services:"
docker service ls
EOF

chmod +x /home/ubuntu/check-swarm.sh
chown ubuntu:ubuntu /home/ubuntu/check-swarm.sh

# Configure Docker Swarm node labels
docker node update --label-add role=manager $(docker node ls -q)

echo "Docker Swarm manager setup completed" > /home/ubuntu/setup-complete.log

# Create a directory for the Flask application
mkdir -p /home/ubuntu/flask-app
chown ubuntu:ubuntu /home/ubuntu/flask-app