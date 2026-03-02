#!/bin/bash

echo "========================================="
echo "VM 공통 설정을 시작합니다..."
echo "========================================="

echo "=== SSH 서버 설치 ==="
dnf install -y openssh-server openssh-clients

# 패스워드 설정
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "vagrant:${VAGRANT_PASSWORD}" | chpasswd

# 방화벽 완전 비활성화 (Kubernetes 권장)
echo "=== 방화벽 비활성화 ==="
systemctl stop firewalld
systemctl disable firewalld

# DNS 설정 (중복 방지)
echo "=== DNS 설정 ==="
if ! grep -q "nameserver 168.126.63.1" /etc/resolv.conf; then
    echo "nameserver 168.126.63.1" >> /etc/resolv.conf
fi
if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

echo "=== sudoers 설정 ==="
echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant
echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/admin

echo "=== SSH 설정 ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# SSH 키 설정
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
if [ -f /home/vagrant/.ssh/authorized_keys ]; then
    chmod 600 /home/vagrant/.ssh/authorized_keys
fi
chown -R vagrant:vagrant /home/vagrant/.ssh

# SSH 서비스 재시작
systemctl restart sshd
systemctl enable sshd

# 타임존 설정
echo "=== 시간 설정 ==="
timedatectl set-timezone Asia/Seoul
timedatectl set-ntp true

# hosts 파일 설정
echo "=== host 파일 설정 ==="
# 중복 방지
grep -q "k8s-master" /etc/hosts || cat << EOF >> /etc/hosts
${K8S_MASTER_IP} k8s-master
${NETWORK_SUBNET}.${K8S_WORKER_START_IP} k8s-worker1
${NETWORK_SUBNET}.$((${K8S_WORKER_START_IP} + 1)) k8s-worker2
EOF

# 커널 모듈 로드
echo "=== 커널 모듈 설정 ==="
modprobe overlay
modprobe br_netfilter

# 커널 모듈 영구 설정
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 커널 파라미터 설정
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "VM 기본 설정이 완료되었습니다."