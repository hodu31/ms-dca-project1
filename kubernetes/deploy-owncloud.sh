#!/bin/bash

# ===================================
# ownCloud Kubernetes 배포 스크립트
# 실행: master 노드에서 실행
# ===================================

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 스크립트 실행 디렉토리
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 로그 파일
LOG_FILE="deploy-owncloud-$(date +%Y%m%d-%H%M%S).log"

# 함수: 로그 출력
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# 함수: 성공/실패 메시지 출력
print_status() {
    if [ $1 -eq 0 ]; then
        log "${GREEN}✓ $2${NC}"
    else
        log "${RED}✗ $2 failed${NC}"
        log "${RED}Check the log file: $LOG_FILE${NC}"
        exit 1
    fi
}

# 함수: 리소스 상태 확인
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-300}
    
    log "${BLUE}⏳ Waiting for $resource_type/$resource_name to be ready...${NC}"
    
    if kubectl wait --for=condition=ready "$resource_type" -l "app=$resource_name" -n "$namespace" --timeout="${timeout}s" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        return 1
    fi
}

# 함수: 파일 존재 확인
check_files() {
    local files=("$@")
    local missing=0
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            log "${RED}Missing file: $file${NC}"
            missing=1
        fi
    done
    
    return $missing
}

# ===================================
# 메인 배포 스크립트 시작
# ===================================

log "${BLUE}========================================${NC}"
log "${BLUE}🚀 Starting ownCloud Deployment${NC}"
log "${BLUE}Time: $(date)${NC}"
log "${BLUE}========================================${NC}"

# 0. 사전 확인
log "\n${YELLOW}📋 Pre-flight checks...${NC}"

# kubectl 확인
if ! command -v kubectl &> /dev/null; then
    log "${RED}kubectl command not found!${NC}"
    exit 1
fi

# 클러스터 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    log "${RED}Cannot connect to Kubernetes cluster!${NC}"
    exit 1
fi

log "${GREEN}✓ Kubernetes cluster is accessible${NC}"

# 파일 존재 확인
log "\n${YELLOW}📁 Checking required files...${NC}"

required_files=(
    "namespace/namespace.yaml"
    "configmap-secret/configmap.yaml"
    "configmap-secret/secret.yaml"
    "database/mariadb-statefulset.yaml"
    "database/mariadb-service.yaml"
    "redis/redis-statefulset.yaml"
    "redis/redis-service.yaml"
    "owncloud/owncloud-pvc.yaml"
    "owncloud/owncloud-deployment.yaml"
    "owncloud/owncloud-service.yaml"
)

check_files "${required_files[@]}"
print_status $? "All required files found"

# ===================================
# 1. Namespace 생성
# ===================================
log "\n${YELLOW}1️⃣ Creating namespace...${NC}"

kubectl apply -f namespace/namespace.yaml >> "$LOG_FILE" 2>&1
print_status $? "Namespace created"

# Namespace가 Active 상태인지 확인
sleep 2
if kubectl get namespace owncloud &> /dev/null; then
    log "${GREEN}✓ Namespace 'owncloud' is active${NC}"
else
    log "${RED}✗ Namespace 'owncloud' not found${NC}"
    exit 1
fi

# ===================================
# 2. ConfigMap과 Secret 생성
# ===================================
log "\n${YELLOW}2️⃣ Creating ConfigMap and Secret...${NC}"

kubectl apply -f configmap-secret/ >> "$LOG_FILE" 2>&1
print_status $? "ConfigMap and Secret created"

# 생성 확인
sleep 2
if kubectl get configmap owncloud-config -n owncloud &> /dev/null && \
   kubectl get secret owncloud-secret -n owncloud &> /dev/null; then
    log "${GREEN}✓ ConfigMap and Secret verified${NC}"
else
    log "${RED}✗ ConfigMap or Secret not found${NC}"
    exit 1
fi

# ===================================
# 3. MariaDB 배포
# ===================================
log "\n${YELLOW}3️⃣ Deploying MariaDB...${NC}"

kubectl apply -f database/ >> "$LOG_FILE" 2>&1
print_status $? "MariaDB resources created"

# MariaDB가 준비될 때까지 대기
wait_for_resource "pod" "mariadb" "owncloud" 300
print_status $? "MariaDB is ready"

# MariaDB 연결 테스트
log "${BLUE}Testing MariaDB connection...${NC}"
kubectl exec -n owncloud mariadb-0 -- mysqladmin ping -h localhost >> "$LOG_FILE" 2>&1
print_status $? "MariaDB connection test passed"

# ===================================
# 4. Redis 배포
# ===================================
log "\n${YELLOW}4️⃣ Deploying Redis...${NC}"

kubectl apply -f redis/ >> "$LOG_FILE" 2>&1
print_status $? "Redis resources created"

# Redis가 준비될 때까지 대기
wait_for_resource "pod" "redis" "owncloud" 300
print_status $? "Redis is ready"

# Redis 연결 테스트
log "${BLUE}Testing Redis connection...${NC}"
kubectl exec -n owncloud redis-0 -- redis-cli -a redis123! ping >> "$LOG_FILE" 2>&1
print_status $? "Redis connection test passed"

# ===================================
# 5. ownCloud 배포
# ===================================
log "\n${YELLOW}5️⃣ Deploying ownCloud...${NC}"

# PVC 먼저 생성
kubectl apply -f owncloud/owncloud-pvc.yaml >> "$LOG_FILE" 2>&1
print_status $? "ownCloud PVC created"

# PVC가 Bound 상태가 될 때까지 대기
log "${BLUE}⏳ Waiting for PVC to be bound...${NC}"
for i in {1..30}; do
    if kubectl get pvc owncloud-shared-pvc -n owncloud -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Bound"; then
        log "${GREEN}✓ PVC is bound${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        log "${RED}✗ PVC binding timeout${NC}"
        exit 1
    fi
    sleep 2
done

# Deployment와 Service 생성
kubectl apply -f owncloud/owncloud-deployment.yaml >> "$LOG_FILE" 2>&1
print_status $? "ownCloud deployment created"

kubectl apply -f owncloud/owncloud-service.yaml >> "$LOG_FILE" 2>&1
print_status $? "ownCloud service created"

# ownCloud가 준비될 때까지 대기
wait_for_resource "pod" "owncloud" "owncloud" 600
print_status $? "ownCloud pods are ready"

# ===================================
# 6. 배포 상태 확인
# ===================================
log "\n${YELLOW}📊 Deployment Status${NC}"
log "${BLUE}========================================${NC}"

# Pod 상태
log "\n${YELLOW}Pods:${NC}"
kubectl get pods -n owncloud -o wide | tee -a "$LOG_FILE"

# Service 상태
log "\n${YELLOW}Services:${NC}"
kubectl get svc -n owncloud | tee -a "$LOG_FILE"

# PVC 상태
log "\n${YELLOW}Storage:${NC}"
kubectl get pvc -n owncloud | tee -a "$LOG_FILE"

# ===================================
# 7. 접속 정보 출력
# ===================================
log "\n${GREEN}========================================${NC}"
log "${GREEN}✅ Deployment Completed Successfully!${NC}"
log "${GREEN}========================================${NC}"

# NodePort 확인
NODE_PORT=$(kubectl get svc owncloud-service -n owncloud -o jsonpath='{.spec.ports[0].nodePort}')
NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

log "\n${YELLOW}🌐 Access Information:${NC}"
log "${BLUE}------------------------${NC}"
for node in $NODES; do
    log "URL: ${GREEN}http://$node:$NODE_PORT${NC}"
done
log "${BLUE}------------------------${NC}"
log "Username: ${GREEN}admin${NC}"
log "Password: ${GREEN}admin123!${NC}"
log "${BLUE}------------------------${NC}"

# 유용한 명령어
log "\n${YELLOW}📝 Useful Commands:${NC}"
log "View logs: ${BLUE}kubectl logs -n owncloud deployment/owncloud${NC}"
log "Watch pods: ${BLUE}kubectl get pods -n owncloud -w${NC}"
log "Delete all: ${BLUE}kubectl delete namespace owncloud${NC}"

log "\n${YELLOW}📄 Deployment log saved to: $LOG_FILE${NC}"

# ===================================
# 8. 헬스체크 (선택사항)
# ===================================
log "\n${YELLOW}🏥 Running health check...${NC}"

# ownCloud 상태 확인
if kubectl exec -n owncloud deployment/owncloud -- curl -s http://localhost:8080/status.php | grep -q "installed"; then
    log "${GREEN}✓ ownCloud is responding${NC}"
else
    log "${YELLOW}⚠️ ownCloud may still be initializing${NC}"
fi

log "\n${GREEN}🎉 Deployment script completed!${NC}"