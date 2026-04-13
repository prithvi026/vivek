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

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr=192.168.0.0/16 --cluster-name=${cluster_name} --cri-socket unix:///var/run/containerd/containerd.sock

# Setup kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Install Calico network plugin
sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -y
apt-get install -y helm

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Install additional monitoring tools
apt-get install -y htop iotop sysstat bc jq

# Create join token script for workers
kubeadm token create --print-join-command > /home/ubuntu/k8s-join-command.sh
chmod +x /home/ubuntu/k8s-join-command.sh
chown ubuntu:ubuntu /home/ubuntu/k8s-join-command.sh

# Install Python and pip for applications
apt-get install -y python3 python3-pip
pip3 install flask psutil requests

echo "Kubernetes control plane setup completed" > /home/ubuntu/setup-complete.log