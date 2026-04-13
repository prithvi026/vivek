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

# Configure Docker daemon for Kubernetes
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=1.28.4-1.1 kubeadm=1.28.4-1.1 kubectl=1.28.4-1.1
apt-mark hold kubelet kubeadm kubectl

# Configure crictl
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl parameters
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install additional monitoring tools
apt-get install -y htop iotop sysstat bc jq

# Install Python and pip for applications
apt-get install -y python3 python3-pip
pip3 install flask psutil requests

# Create a script to join the cluster (will be executed manually or via automation)
cat > /home/ubuntu/join-cluster.sh <<'EOF'
#!/bin/bash
# This script should be run after the control plane is ready
# Get the join command from the control plane and execute it
# Example: sudo kubeadm join 10.0.1.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
echo "To join this node to the cluster, run the join command from the control plane"
EOF

chmod +x /home/ubuntu/join-cluster.sh
chown ubuntu:ubuntu /home/ubuntu/join-cluster.sh

echo "Kubernetes worker node setup completed" > /home/ubuntu/setup-complete.log