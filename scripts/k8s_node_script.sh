#!/bin/bash
# Kubernetes 클러스터를 위한 설정
echo "Kubernetes 노드 설정을 시작합니다..."

# SELinux 비활성화 (K8s 클러스터용)
echo "=== SELinux 비활성화 ==="
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

echo "=== 방화벽 설정 (Kubernetes Master 포트) ==="
firewall-cmd --permanent --add-port=6443/tcp      # API Server
firewall-cmd --permanent --add-port=2379-2380/tcp # etcd
firewall-cmd --permanent --add-port=10250/tcp     # kubelet
firewall-cmd --permanent --add-port=10251/tcp     # kube-scheduler
firewall-cmd --permanent --add-port=10252/tcp     # kube-controller-manager
firewall-cmd --permanent --add-port=10255/tcp     # kubelet read-only
# Calico 사용 시
firewall-cmd --permanent --add-port=179/tcp
firewall-cmd --permanent --add-port=4789/udp

# Flannel 사용 시
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --reload

# Swap 비활성화 (K8s 요구사항)
echo "=== Swap 비활성화 ==="
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 커널 모듈 로드
echo "커널 모듈 설정 중..."
cat << EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "Kubernetes 노드 설정이 완료되었습니다."