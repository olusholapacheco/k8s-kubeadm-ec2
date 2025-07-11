#!/bin/bash

######### ** FOR WORKER NODE ** #########

hostname bootstrap-k8s-wrk-${worker_number}
echo "bootstrap-k8s-wrk-${worker_number}" > /etc/hostname


apt update
apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

#Installing Docker
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter


apt update
apt-cache policy docker-ce
apt install docker-ce -y


sudo apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version  

#Be sure to understand, if you follow official Kubernetes documentation, in Ubuntu 20 it does not work, that is why, I did modification to script
#Adding Kubernetes repositories

#Next 2 lines are different from official Kubernetes guide, but the way Kubernetes describe step does not work
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
# echo "deb https://packages.cloud.google.com/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kurbenetes.list

mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


#Turn off swap
swapoff -a
sudo sed -i '/swap/d' /etc/fstab
mount -a
ufw disable

#Installing Kubernetes tools
apt update
# apt install kubelet kubeadm kubectl -y
apt install -y kubeadm=1.28.1-1.1 kubelet=1.28.1-1.1 kubectl=1.28.1-1.1
apt-mark hold kubelet kubeadm kubectl



#next line is getting EC2 instance IP, for kubeadm to initiate cluster
# Get EC2 internal IP address (used to join the cluster)
export ipaddr=$(ip address show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)


# the kubeadm init won't work entel remove the containerd config and restart it.
rm /etc/containerd/config.toml
systemctl restart containerd

tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# to insure the join command start when the installion of master node is done.
sleep 5m

aws s3 cp s3://${s3bucket_name}/join_worker_command.sh /tmp/.
chmod +x /tmp/join_worker_command.sh
sudo bash /tmp/join_worker_command.sh