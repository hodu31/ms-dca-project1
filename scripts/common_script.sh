#!/bin/bash

echo "========================================="
echo "VM 공통 설정을 시작합니다..."
echo "========================================="

# 패스워드 설정
echo "root:#{root_password}" | chpasswd
echo "vagrant:#{vagrant_password}" | chpasswd

# SSH 설정 - root 로그인 허용
echo "=== SSH 설정 - root 로그인 허용 ==="
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# 기본 패키지 설치
echo "=== 기본 패키지 설치 ==="
dnf install -y epel-release vim wget curl git net-tools nano

# 타임존 설정
echo "=== 시간 설정 ==="
timedatectl set-timezone Asia/Seoul
timedatectl set-ntp true

# hosts 파일 설정
echo "=== host 파일 설정 ==="
cat << EOF >> /etc/hosts
#{k8s_master_ip} k8s-master
#{network_subnet}.#{k8s_worker_start_ip} k8s-worker1
#{network_subnet}.#{k8s_worker_start_ip.to_i + 1} k8s-worker2
EOF

echo "VM 기본 설정이 완료되었습니다."