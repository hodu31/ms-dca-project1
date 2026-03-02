#!/bin/bash

# Ansible 연결 테스트 스크립트
# Master 노드에서 실행

echo "========================================="
echo "Ansible 연결 테스트를 시작합니다..."
echo "========================================="

# 현재 위치 확인
echo "현재 디렉토리: $(pwd)"

# Ansible 설정 파일 확인
if [ -f "/home/vagrant/shared/ansible/ansible.cfg" ]; then
    echo "✅ ansible.cfg 파일 발견"
else
    echo "❌ ansible.cfg 파일 없음"
fi

# 인벤토리 파일 확인
if [ -f "/home/vagrant/shared/ansible/inventory/hosts.yml" ]; then
    echo "✅ hosts.yml 파일 발견"
else
    echo "❌ hosts.yml 파일 없음"
fi

# Ansible 작업 디렉토리로 이동
cd /home/vagrant/shared/ansible

echo ""
echo "========================================="
echo "1. 인벤토리 확인"
echo "========================================="
ansible-inventory --list

echo ""
echo "========================================="
echo "2. 모든 노드에 ping 테스트"
echo "========================================="
ansible all -m ping

echo ""
echo "========================================="
echo "3. 각 노드 정보 수집"
echo "========================================="
ansible all -m setup -a "filter=ansible_hostname,ansible_distribution*,ansible_memtotal_mb"

echo ""
echo "========================================="
echo "4. SSH 키 기반 연결 설정"
echo "========================================="

# SSH 키를 각 워커에 복사
for worker in k8s-worker1 k8s-worker2; do
    echo "SSH 키를 $worker에 복사 중..."
    sshpass -p 'owncloud123!' ssh-copy-id -o StrictHostKeyChecking=no root@$worker
    
    if [ $? -eq 0 ]; then
        echo "✅ $worker SSH 키 복사 성공"
    else
        echo "❌ $worker SSH 키 복사 실패"
    fi
done

echo ""
echo "========================================="
echo "5. SSH 키 기반 연결 테스트"
echo "========================================="

# 패스워드 없이 연결 테스트
for worker in k8s-worker1 k8s-worker2; do
    echo "SSH 키 연결 테스트: $worker"
    ssh -o StrictHostKeyChecking=no root@$worker 'hostname && date'
    
    if [ $? -eq 0 ]; then
        echo "✅ $worker SSH 키 연결 성공"
    else
        echo "❌ $worker SSH 키 연결 실패"
    fi
done

echo ""
echo "========================================="
echo "6. 최종 Ansible 연결 확인"
echo "========================================="
ansible all -m ping

echo ""
echo "연결 테스트가 완료되었습니다!"