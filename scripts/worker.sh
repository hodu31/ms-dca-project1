#!/bin/bash
echo "Kubernetes Worker#{i} 설정을 시작합니다..."
        
# SSH 공개키 허용을 위한 디렉토리 생성
echo "=== SSH 공개키 허용을 위한 디렉토리 생성 ==="
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "Worker#{i} 노드 설정이 완료되었습니다."