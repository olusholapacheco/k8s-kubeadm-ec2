#!/bin/bash

######### ** FOR MASTER NODE ** #########

hostname bootstrap-k8s-msr-1
echo "bootstrap-k8s-msr-1" > /etc/hostname


# export AWS_DEFAULT_REGION=${region}

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
apt install containerd.io -y

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
# Get EC2 internal IP for control plane advertise-address
export ipaddr=$(ip address show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)

# Get EC2 public IP for apiserver SAN certificate
export pubip=$(dig +short myip.opendns.com @resolver1.opendns.com)



# the kubeadm init won't work entel remove the containerd config and restart it.
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

#rm /etc/containerd/config.toml

systemctl restart containerd

tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system



#Kubernetes cluster init for High availability (Recommended 3 control planes)
#You can replace 172.16.0.0/16 with your desired pod network
#kubeadm init --apiserver-advertise-address=$ipaddr --control-plane-endpoint="$/{loadbalancer_endpoint}:6443"  --pod-network-cidr=192.168.0.0/16 --apiserver-cert-extra-sans=$pubip > /tmp/restult.out

# Kubernetes cluster init for single control plane
kubeadm init --apiserver-advertise-address=$ipaddr --pod-network-cidr=192.168.0.0/16 --apiserver-cert-extra-sans=$pubip > /tmp/result.out
cat /tmp/result.out

# get command to join cluster
# tail -2 /tmp/restult.out > /tmp/join_master_command.out
# get_certkey=$(sudo kubeadm init phase upload-certs --upload-certs | sed -n '$p')
# printf " --control-plane --certificate-key $get_certkey" >> /tmp/join_master_command.out
# cp /tmp/join_master_command.out /tmp/join_master_command.sh
# aws s3 cp /tmp/join_master_command.sh s3://${s3bucket_name}

#to get join command
tail -2 /tmp/result.out > /tmp/join_worker_command.sh;
#cat /tmp/join_master_command.out > /tmp/join_master_command.sh;
aws s3 cp /tmp/join_worker_command.sh s3://${s3bucket_name};




#this adds .kube/config for root account, run same for ubuntu user, if you need it
mkdir -p /root/.kube;
cp -i /etc/kubernetes/admin.conf /root/.kube/config;
cp -i /etc/kubernetes/admin.conf /tmp/admin.conf;
chmod 755 /tmp/admin.conf

#Add kube config to ubuntu user.
mkdir -p /home/ubuntu/.kube;
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config;
chmod 755 /home/ubuntu/.kube/config

sleep 120

#to copy kube config file to s3
# aws s3 cp /etc/kubernetes/admin.conf s3://${s3bucket_name}

# ✅ NEW: Upload Kubeconfig for GitHub Actions to use kube
aws s3 cp /tmp/admin.conf s3://${s3bucket_name}/admin.conf

export KUBECONFIG=/root/.kube/config
# install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
bash get_helm.sh

# Setup flannel
kubectl create --kubeconfig /root/.kube/config ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="192.168.0.0/16" --namespace kube-flannel flannel/flannel



#Uncomment next line if you want calico Cluster Pod Network
# curl -o /root/calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
sleep 5
# kubectl --kubeconfig /root/.kube/config apply -f /root/calico.yaml
# systemctl restart kubelet

# Apply kubectl Cheat Sheet Autocomplete
source <(kubectl completion bash) # set up autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc # add autocomplete permanently to your bash shell.
echo "source <(kubectl completion bash)" >> /root/.bashrc # add autocomplete permanently to your bash shell.
alias k=kubectl
complete -o default -F __start_kubectl k
echo "alias k=kubectl" >> /home/ubuntu/.bashrc
echo "alias k=kubectl" >> /root/.bashrc
echo "complete -o default -F __start_kubectl k" >> /home/ubuntu/.bashrc
echo "complete -o default -F __start_kubectl k" >> /root/.bashrc