# k8s-kubeadm-ec2
Creating Kubernetes Clusters using Kubeadm and Amazon EC2


![GitHub Actions](https://github.com/olusholapacheco/k8s-kubeadm-ec2/actions/workflows/deploy.yml/badge.svg)
# k8s-kubeadm-ec2

# 🚀 Bootstrap Kubernetes Cluster on AWS EC2 with GitHub Actions

This project automates the provisioning and setup of a Kubernetes cluster from scratch using:
- **Terraform** to provision EC2 instances
- **Shell scripts** to install and configure Kubernetes
- **GitHub Actions** to orchestrate the entire deployment pipeline

This repo is part of my journey to rebuild confidence and skills in DevOps by learning through doing.

---

# Project Goals

- Provision a Kubernetes cluster using Terraform
- Bootstrap control plane and worker nodes using `kubeadm`
- Automate the entire setup with GitHub Actions
- Improve Bash, Python, CI/CD, and infrastructure-as-code skills

- Deploy applications using Kubernetes manifests - working on this

---

# Infrastructure Summary

- **Cloud Provider**: AWS EC2
- **Instance Types**: t2.medium (Control Plane), t2.small (Workers)
- **OS**: Ubuntu 24.04 LTS
- **Kubernetes**: Installed using `kubeadm`
- **Networking**: Flannel CNI
- **Access**: SSH via generated key pair
- **CI/CD**: GitHub Actions handles provisioning and configuration

---

## 📁 Repo Structure
.
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions workflow for infra + k8s bootstrap
├── backend.tf                 # Terraform backend config (S3)
├── iam.tf                     # IAM roles and instance profiles
├── main.tf                    # Main Terraform EC2 definitions
├── manifest/                  # Kubernetes YAML manifests 
├── master.sh                  # Script to set up Kubernetes control plane
├── outputs.tf                 # Terraform output variables
├── README.md                  # Project documentation
├── variables.tf               # Input variables for Terraform
└── workers.sh                 # Script to configure and join worker nodes



---

##  GitHub Actions Workflow

This repo uses GitHub Actions (`.github/workflows/deploy.yml`) to automate everything:

-  Provision EC2 infrastructure using Terraform  
-  SSH into each node and run the setup scripts  
-  Bootstrap the Kubernetes cluster using `kubeadm`  
-  Deploy Kubernetes manifests from the `manifest/` folder

---

## In Progress / Next Steps

- [x] Bootstrap cluster with `kubeadm`
- [ ] Add working sample app 
- [ ] Expose the app with a `Service` or Ingress
- [ ] Add monitoring (e.g., Prometheus, Grafana)
- [ ] Document teardown process


## Build in progress
A simple Python Background Job Queue App on Kubernetes
The full picture:
A user sends a job (uploading an image). FastAPI receives the request and places the job in a Redis Queue (RQ). A background worker picks up the job, processes it (resizing the image), and stores the result. Monitoring is set up with Prometheus + Grafana.


## Core App Components:

FastAPI	- Handles incoming HTTP requests, e.g., "upload this image"
Redis	- Message broker — temporarily holds background jobs
RQ Worker -	Background job processor that pulls jobs from Redis
PostgreSQL -	Stores metadata 
Persistent Volume	- Where resized images (or results) are stored
Prometheus + Grafana - 	For monitoring metrics and creating dashboards