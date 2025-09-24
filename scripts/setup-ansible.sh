#!/bin/bash

# Ansible 설정 및 노드 연결 관리 스크립트
# Author: Practice Project
# Description: Vagrant 환경에서 Ansible을 설정하고 노드들을 관리하는 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 환경 변수 설정
ANSIBLE_DIR="/vagrant/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"
ANSIBLE_CFG="$ANSIBLE_DIR/ansible.cfg"
PLAYBOOKS_DIR="$ANSIBLE_DIR/playbooks"

# 안전한 ansible 디렉토리 생성
SAFE_ANSIBLE_DIR="/vagrant/.ansible"
SAFE_CFG="$SAFE_ANSIBLE_DIR/ansible.cfg"
SAFE_INVENTORY="$SAFE_ANSIBLE_DIR/hosts.yml"

show_help() {
    cat << EOF
Ansible 설정 및 관리 스크립트

사용법: $0 [옵션] [명령]

옵션:
    -h, --help          이 도움말 표시
    -v, --verbose       상세 출력
    -d, --debug         디버그 모드

명령:
    setup               Ansible 초기 설정
    check               노드 연결 상태 확인
    ping                모든 노드에 ping 테스트
    facts               노드 정보 수집
    install             필요한 패키지 설치
    status              클러스터 상태 확인
    clean               임시 파일 정리
    debug               디버그 정보 출력
    
    playbook [name]     특정 플레이북 실행
    deploy-all          모든 플레이북 순차 실행

예제:
    $0 setup            # Ansible 환경 설정
    $0 docker           # Docker 설치
    $0 k8s              # Kubernetes 클러스터 구축
    $0 deploy-all       # 전체 환경 구축
    $0 playbook test    # test.yml 플레이북 실행
EOF
}

# 디렉토리 권한 문제 해결
fix_directory_permissions() {
    log_info "디렉토리 권한 문제를 해결합니다..."
    
    # 안전한 ansible 디렉토리 생성
    mkdir -p "$SAFE_ANSIBLE_DIR"
    chmod 755 "$SAFE_ANSIBLE_DIR"
    
    # 설정 파일 복사
    if [[ -f "$ANSIBLE_CFG" ]]; then
        cp "$ANSIBLE_CFG" "$SAFE_CFG"
        chmod 644 "$SAFE_CFG"
        log_success "ansible.cfg를 안전한 위치로 복사했습니다."
    fi
    
    if [[ -f "$INVENTORY_FILE" ]]; then
        cp "$INVENTORY_FILE" "$SAFE_INVENTORY"
        chmod 644 "$SAFE_INVENTORY"
        log_success "hosts.yml을 안전한 위치로 복사했습니다."
    fi
    
    # 환경변수 설정
    export ANSIBLE_CONFIG="$SAFE_CFG"
    export ANSIBLE_INVENTORY="$SAFE_INVENTORY"
    
    log_success "환경변수가 설정되었습니다."
    log_info "ANSIBLE_CONFIG: $ANSIBLE_CONFIG"
    log_info "ANSIBLE_INVENTORY: $ANSIBLE_INVENTORY"
}

# Ansible 설치 및 설정
setup_ansible() {
    log_info "Ansible 환경 설정을 시작합니다..."
    
    # Ansible 설치 확인
    if ! command -v ansible &> /dev/null; then
        log_info "Ansible을 설치합니다..."
        sudo dnf install -y epel-release
        sudo dnf install -y ansible python3-pip sshpass
        pip3 install --user ansible-core
    else
        log_success "Ansible이 이미 설치되어 있습니다."
    fi
    
    # 디렉토리 권한 문제 해결
    fix_directory_permissions
    
    # 원본 파일 확인
    if [[ -f "$ANSIBLE_CFG" ]]; then
        log_success "원본 ansible.cfg 파일이 존재합니다."
    else
        log_error "원본 ansible.cfg 파일을 찾을 수 없습니다: $ANSIBLE_CFG"
        return 1
    fi
    
    if [[ -f "$INVENTORY_FILE" ]]; then
        log_success "원본 hosts.yml 파일이 존재합니다."
    else
        log_error "원본 hosts.yml 파일을 찾을 수 없습니다: $INVENTORY_FILE"
        return 1
    fi
    
    # 환경변수를 bashrc에 추가
    if ! grep -q "ANSIBLE_CONFIG" ~/.bashrc; then
        echo "export ANSIBLE_CONFIG=$SAFE_CFG" >> ~/.bashrc
        echo "export ANSIBLE_INVENTORY=$SAFE_INVENTORY" >> ~/.bashrc
        log_success "환경변수를 .bashrc에 추가했습니다."
    fi
    
    log_success "Ansible 환경 설정이 완료되었습니다."
}

# 환경변수 로드
load_ansible_env() {
    if [[ -f "$SAFE_CFG" ]]; then
        export ANSIBLE_CONFIG="$SAFE_CFG"
    fi
    
    if [[ -f "$SAFE_INVENTORY" ]]; then
        export ANSIBLE_INVENTORY="$SAFE_INVENTORY"
    fi
}

# 노드 연결 상태 확인
check_connectivity() {
    log_info "노드 연결 상태를 확인합니다..."
    
    # 환경변수 로드
    load_ansible_env
    
    # 작업 디렉토리 설정
    cd "$SAFE_ANSIBLE_DIR"
    
    # 인벤토리 확인
    log_info "인벤토리 파일 확인 중..."
    if ansible-inventory --list &>/dev/null; then
        log_success "인벤토리 파일이 정상적으로 로드되었습니다."
    else
        log_error "인벤토리 파일 로드에 실패했습니다."
        return 1
    fi
    
    # 개별 노드 확인
    local nodes=("k8s-master" "k8s-worker1" "k8s-worker2")
    local success=0
    local total=${#nodes[@]}
    
    for node in "${nodes[@]}"; do
        log_info "노드 $node 연결 확인 중..."
        if timeout 10 ansible "$node" -m ping -o 2>/dev/null | grep -q "SUCCESS"; then
            log_success "$node: 연결 성공"
            ((success++))
        else
            log_error "$node: 연결 실패"
        fi
    done
    
    log_info "연결 결과: $success/$total 노드 연결됨"
    
    if [[ $success -eq $total ]]; then
        log_success "모든 노드가 정상적으로 연결되었습니다."
        return 0
    else
        log_warning "일부 노드 연결에 문제가 있습니다."
        return 1
    fi
}

# 모든 노드 ping 테스트
ping_all_nodes() {
    log_info "모든 노드에 ping 테스트를 실행합니다..."
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    ansible all -m ping -o
}

# 시스템 정보 수집
gather_facts() {
    log_info "노드 시스템 정보를 수집합니다..."
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    # 기본 시스템 정보
    log_info "=== 시스템 기본 정보 ==="
    ansible all -m setup -a "filter=ansible_distribution*,ansible_kernel,ansible_memtotal_mb,ansible_processor_vcpus" --tree /tmp/facts
    
    # 네트워크 정보
    log_info "=== 네트워크 정보 ==="
    ansible all -m setup -a "filter=ansible_default_ipv4,ansible_hostname"
    
    # 디스크 정보
    log_info "=== 디스크 정보 ==="
    ansible all -m shell -a "df -h"
    
    log_success "시스템 정보 수집이 완료되었습니다."
}

# 필요한 패키지 설치
install_packages() {
    log_info "필요한 패키지를 설치합니다..."
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    # 시스템 업데이트
    log_info "시스템 패키지를 업데이트합니다..."
    ansible all -m dnf -a "name=* state=latest update_cache=yes" -b
    
    # 기본 패키지 설치
    log_info "기본 패키지를 설치합니다..."
    local packages="curl,wget,git,vim,htop,net-tools"
    ansible all -m dnf -a "name=$packages state=present" -b
    
    log_success "패키지 설치가 완료되었습니다."
}

# 클러스터 상태 확인
check_cluster_status() {
    log_info "Kubernetes 클러스터 상태를 확인합니다..."
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    # 마스터 노드에서 클러스터 상태 확인
    log_info "=== 클러스터 정보 ==="
    ansible masters -m shell -a "kubectl cluster-info" 2>/dev/null || log_warning "kubectl이 설정되지 않았거나 클러스터가 실행되지 않고 있습니다."
    
    # 노드 상태 확인
    log_info "=== 노드 상태 ==="
    ansible masters -m shell -a "kubectl get nodes -o wide" 2>/dev/null || log_warning "노드 정보를 가져올 수 없습니다."
    
    # 파드 상태 확인
    log_info "=== 시스템 파드 상태 ==="
    ansible masters -m shell -a "kubectl get pods -A" 2>/dev/null || log_warning "파드 정보를 가져올 수 없습니다."
}

# 임시 파일 정리
clean_temp_files() {
    log_info "임시 파일을 정리합니다..."
    
    # Ansible 임시 파일 정리
    rm -rf /tmp/.ansible-cp/* 2>/dev/null
    rm -rf /tmp/facts/* 2>/dev/null
    
    log_success "임시 파일 정리가 완료되었습니다."
}

# 인벤토리 정보 표시
show_inventory() {
    log_info "현재 인벤토리 정보:"
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    echo "=== 등록된 호스트 ==="
    ansible-inventory --list
    
    echo -e "\n=== 호스트 그룹 ==="
    ansible-inventory --graph
}

# 디버그 정보 출력
debug_info() {
    log_info "=== Ansible 디버그 정보 ==="
    
    echo "현재 작업 디렉토리: $(pwd)"
    echo "사용자: $(whoami)"
    echo "홈 디렉토리: $HOME"
    
    echo -e "\n=== 환경변수 ==="
    echo "ANSIBLE_CONFIG: $ANSIBLE_CONFIG"
    echo "ANSIBLE_INVENTORY: $ANSIBLE_INVENTORY"
    
    echo -e "\n=== Ansible 버전 ==="
    ansible --version
    
    echo -e "\n=== 파일 존재 확인 ==="
    echo "원본 ansible.cfg: $(ls -la $ANSIBLE_CFG 2>/dev/null || echo '없음')"
    echo "원본 hosts.yml: $(ls -la $INVENTORY_FILE 2>/dev/null || echo '없음')"
    echo "안전한 ansible.cfg: $(ls -la $SAFE_CFG 2>/dev/null || echo '없음')"
    echo "안전한 hosts.yml: $(ls -la $SAFE_INVENTORY 2>/dev/null || echo '없음')"
    
    if [[ -f "$SAFE_INVENTORY" ]]; then
        echo -e "\n=== 인벤토리 테스트 ==="
        load_ansible_env
        cd "$SAFE_ANSIBLE_DIR"
        ansible-inventory --list 2>&1 || echo "인벤토리 로드 실패"
    fi
}

# 플레이북 실행 함수 추가
run_playbook() {
    local playbook_name="$1"
    
    if [[ -z "$playbook_name" ]]; then
        log_error "플레이북 이름을 지정해주세요."
        return 1
    fi
    
    # 환경변수 로드
    load_ansible_env
    cd "$SAFE_ANSIBLE_DIR"
    
    # 플레이북 경로 설정
    local playbook_path="/vagrant/ansible/playbooks/${playbook_name}.yml"
    
    # 플레이북 존재 확인
    if [[ ! -f "$playbook_path" ]]; then
        log_error "플레이북을 찾을 수 없습니다: $playbook_path"
        return 1
    fi
    
    log_info "플레이북 실행: $playbook_name"
    
    # k8s-cluster 플레이북인 경우 변수 추가
    if [[ "$playbook_name" == "k8s-cluster" ]]; then
        ansible-playbook \
            -i "$SAFE_INVENTORY" \
            "$playbook_path" \
            --extra-vars "ansible_password=owncloud123!" \
            --extra-vars "k8s_version=1.28.0" \
            --extra-vars "pod_network_cidr=10.244.0.0/16" \
            --extra-vars "service_cidr=10.96.0.0/12" \
            --extra-vars "calico_version=3.26.1"
    else
        # 일반 플레이북 실행
        ansible-playbook \
            -i "$SAFE_INVENTORY" \
            "$playbook_path" \
            --extra-vars "ansible_password=owncloud123!"
    fi
}

# 모든 플레이북 실행
run_all_playbooks() {
    log_info "모든 플레이북을 순서대로 실행합니다..."
    
    # 1. Docker 설치
    if run_docker_setup; then
        log_success "Docker 설정 완료"
    else
        log_error "Docker 설정 실패"
        return 1
    fi
    
    # 2. Kubernetes 클러스터 구축
    if run_k8s_cluster; then
        log_success "Kubernetes 클러스터 구축 완료"
    else
        log_error "Kubernetes 클러스터 구축 실패"
        return 1
    fi
    
    log_success "모든 플레이북 실행이 완료되었습니다."
}

# 메인 함수
main() {
    local verbose=false
    local debug=false
    
    # 옵션 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -d|--debug)
                debug=true
                set -x
                shift
                ;;
            setup)
                setup_ansible
                exit $?
                ;;
            check)
                check_connectivity
                exit $?
                ;;
            ping)
                ping_all_nodes
                exit $?
                ;;
            facts)
                gather_facts
                exit $?
                ;;
            install)
                install_packages
                exit $?
                ;;
            status)
                check_cluster_status
                exit $?
                ;;
            clean)
                clean_temp_files
                exit $?
                ;;
            inventory)
                show_inventory
                exit $?
                ;;
            playbook)
                shift
                run_playbook "$1"
                exit $?
                ;;
            deploy-all)
                run_all_playbooks
                exit $?
                ;;
            debug)
                debug_info
                exit $?
                ;;
            *)
                log_error "알 수 없는 명령어: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 명령어가 없으면 도움말 표시
    show_help
}

# 스크립트 실행
main "$@"
