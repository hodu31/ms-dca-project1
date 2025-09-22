#!/bin/bash
echo "Kubernetes Master 설정을 시작합니다..."

# Ansible 설치 (Control Node)
echo "=== Ansible 설치 ==="
dnf install -y python3-pip sshpass
pip3 install ansible

# SSH 키 생성 (Ansible용)
echo "=== SSH 키 생성 ==="
if [ ! -f /root/.ssh/id_rsa ]; then
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
fi

# Ansible 설정 디렉토리 생성
echo "Ansible 설정 디렉토리 준비 중..."
mkdir -p /etc/ansible
mkdir -p /root/ansible

# SSH 설정 최적화
echo "SSH 설정 최적화 중..."
cat << EOF >> /root/.ssh/config
Host k8s-worker*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF


# Git 저장소 클론
echo "== Git 저장소 클론 =="
cd /root 
git clone https://github.com/hodu31/ms-dca-project1.git


chmod 600 /root/.ssh/config

echo "Master 노드 설정이 완료되었습니다."
echo "Ansible이 설치되었습니다. 이후 Ansible Playbook으로 클러스터를 구성하세요."