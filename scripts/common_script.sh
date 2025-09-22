#!/bin/bash

echo "========================================="
echo "VM 공통 설정을 시작합니다..."
echo "========================================="

# 패스워드 설정 - 대문자로 수정
echo "root:${ROOT_PASSWORD}" | chpasswd
echo "vagrant:${VAGRANT_PASSWORD}" | chpasswd

# SSH 설정 - root 로그인 허용
echo "=== SSH 설정 ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
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

echo "VM 기본 설정이 완료되었습니다."