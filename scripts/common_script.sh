#!/bin/bash

echo "========================================="
echo "VM 공통 설정을 시작합니다..."
echo "========================================="

echo "=== SSH 서버 설치 ==="
dnf install -y openssh-server openssh-clients

# 패스워드 설정 - 대문자로 수정
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "vagrant:${VAGRANT_PASSWORD}" | chpasswd

echo "=== 방화벽 설정 ==="
systemctl start firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --zone=trusted --add-source=192.168.100.0/24
firewall-cmd --reload

echo "=== DNS 설정 ==="
echo "nameserver 168.126.63.1" >> /etc/resolv.conf

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

# hosts 파일 설정 - 대문자로 수정
echo "=== host 파일 설정 ==="
cat << EOF >> /etc/hosts
${K8S_MASTER_IP} k8s-master
${NETWORK_SUBNET}.${K8S_WORKER_START_IP} k8s-worker1
${NETWORK_SUBNET}.$((${K8S_WORKER_START_IP} + 1)) k8s-worker2
EOF

# 커널 모듈 로드
modprobe br_netfilter
echo 'br_netfilter' > /etc/modules-load.d/k8s.conf

# 커널 파라미터 설정
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "VM 기본 설정이 완료되었습니다."