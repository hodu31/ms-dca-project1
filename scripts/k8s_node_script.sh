#!/bin/bash
# Kubernetes 클러스터를 위한 설정
echo "Kubernetes 노드 설정을 시작합니다..."

# 방화벽 비활성화 (K8s 클러스터용)
echo "=== 방화벽 비활성화 ==="
systemctl stop firewalld
systemctl disable firewalld

# SELinux 비활성화 (K8s 클러스터용)
echo "=== SELinux 비활성화 ==="
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

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

# 커널 파라미터 설정
echo "커널 파라미터 설정 중..."
cat << EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "Kubernetes 노드 설정이 완료되었습니다."