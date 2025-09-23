#!/bin/bash

# Vagrant Ansible 관리 래퍼 스크립트
# Vagrant SSH를 통해 Ansible 관리 스크립트를 실행합니다.

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 로그 함수
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

# 기본 VM 설정 (Ansible이 설치될 VM)
DEFAULT_VM="k8s-master"

# Vagrant 상태 확인
check_vagrant_status() {
    log_info "Vagrant 상태를 확인합니다..."
    
    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant가 설치되지 않았습니다."
        exit 1
    fi
    
    # 특정 VM 상태 확인
    local vm_status=$(vagrant status "$DEFAULT_VM" 2>/dev/null | grep "$DEFAULT_VM" | grep "running" | wc -l)
    if [[ $vm_status -eq 0 ]]; then
        log_warning "$DEFAULT_VM VM이 실행되지 않고 있습니다."
        log_info "$DEFAULT_VM VM을 시작하시겠습니까? (y/n)"
        read -r answer
        if [[ $answer =~ ^[Yy]$ ]]; then
            log_info "$DEFAULT_VM VM을 시작합니다..."
            vagrant up "$DEFAULT_VM"
        else
            log_error "$DEFAULT_VM VM이 실행되지 않아 스크립트를 종료합니다."
            exit 1
        fi
    else
        log_success "$DEFAULT_VM VM이 실행 중입니다."
    fi
}

# Ansible 스크립트 실행
run_ansible_script() {
    local script_path="/vagrant/scripts/setup-ansible.sh"
    local args="$*"
    
    log_info "Vagrant SSH ($DEFAULT_VM)를 통해 Ansible 스크립트를 실행합니다..."
    log_info "실행 명령: $script_path $args"
    
    # Windows Git Bash 경로 문제 해결을 위해 vagrant ssh 명령을 따로 처리
    log_info "스크립트 실행 권한을 설정합니다..."
    vagrant ssh "$DEFAULT_VM" << 'EOF'
chmod +x /vagrant/scripts/setup-ansible.sh 2>/dev/null || true
EOF
    
    # 스크립트 실행 - heredoc을 사용하여 경로 문제 회피
    log_info "Ansible 설정 스크립트를 실행합니다..."
    vagrant ssh "$DEFAULT_VM" << EOF
/vagrant/scripts/setup-ansible.sh $args
EOF
}

# 도움말
show_help() {
    cat << EOF
Vagrant Ansible 관리 래퍼 스크립트 (Multi-VM 환경용)

사용법: $0 [Ansible 스크립트 옵션/명령]

이 스크립트는 $DEFAULT_VM VM을 통해 setup-ansible.sh를 실행합니다.

기본 VM: $DEFAULT_VM

예제:
    $0 setup            # Ansible 환경 설정
    $0 check            # 노드 연결 확인  
    $0 ping             # 모든 노드 ping 테스트
    $0 facts            # 시스템 정보 수집
    $0 install          # 필요한 패키지 설치
    $0 status           # 클러스터 상태 확인
    $0 clean            # 임시 파일 정리
    $0 inventory        # 인벤토리 정보 표시
    $0 --help           # Ansible 스크립트 도움말

Vagrant 관리 명령어:
    $0 vagrant-info     # 모든 VM 상태 정보
    $0 vagrant-up       # 모든 VM 시작
    $0 vagrant-up-master # 마스터 VM만 시작
    $0 vagrant-halt     # 모든 VM 종료
    $0 vagrant-ssh      # 마스터 VM에 SSH 접속
    $0 vagrant-ssh-worker1  # worker1 VM에 SSH 접속
    $0 vagrant-ssh-worker2  # worker2 VM에 SSH 접속

VM별 직접 접근:
    vagrant ssh k8s-master   # 마스터 노드 접속
    vagrant ssh k8s-worker1  # 워커1 노드 접속  
    vagrant ssh k8s-worker2  # 워커2 노드 접속

직접 명령 실행:
    $0 direct "명령어"   # VM에서 직접 명령 실행
EOF
}

# Vagrant 정보 표시
show_vagrant_info() {
    log_info "=== 모든 VM 상태 정보 ==="
    vagrant status
    
    log_info "=== 실행 중인 머신 목록 ==="
    vagrant global-status --prune
    
    log_info "=== VM별 상세 정보 ==="
    for vm in k8s-master k8s-worker1 k8s-worker2; do
        local status=$(vagrant status "$vm" 2>/dev/null | grep "$vm" | awk '{print $2}')
        if [[ "$status" == "running" ]]; then
            log_success "$vm: 실행 중"
        else
            log_warning "$vm: $status"
        fi
    done
}

# 특정 VM 시작
start_vm() {
    local vm_name="$1"
    if [[ -z "$vm_name" ]]; then
        log_info "모든 VM을 시작합니다..."
        vagrant up
    else
        log_info "$vm_name VM을 시작합니다..."
        vagrant up "$vm_name"
    fi
}

# 특정 VM 종료
halt_vm() {
    local vm_name="$1"
    if [[ -z "$vm_name" ]]; then
        log_info "모든 VM을 종료합니다..."
        vagrant halt
    else
        log_info "$vm_name VM을 종료합니다..."
        vagrant halt "$vm_name"
    fi
}

# SSH 접속
ssh_to_vm() {
    local vm_name="${1:-$DEFAULT_VM}"
    log_info "$vm_name VM에 SSH로 접속합니다..."
    vagrant ssh "$vm_name"
}

# 직접 명령 실행
run_direct_command() {
    local command="$1"
    log_info "직접 명령을 실행합니다: $command"
    vagrant ssh "$DEFAULT_VM" << EOF
$command
EOF
}

# 메인 함수
main() {
    # 인자가 없으면 도움말 표시
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # 특별한 명령어 처리
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        vagrant-info)
            show_vagrant_info
            exit 0
            ;;
        vagrant-up)
            start_vm
            exit $?
            ;;
        vagrant-up-master)
            start_vm "k8s-master"
            exit $?
            ;;
        vagrant-up-worker1)
            start_vm "k8s-worker1"
            exit $?
            ;;
        vagrant-up-worker2)
            start_vm "k8s-worker2"
            exit $?
            ;;
        vagrant-halt)
            halt_vm
            exit $?
            ;;
        vagrant-halt-master)
            halt_vm "k8s-master"
            exit $?
            ;;
        vagrant-halt-worker1)
            halt_vm "k8s-worker1"
            exit $?
            ;;
        vagrant-halt-worker2)
            halt_vm "k8s-worker2"
            exit $?
            ;;
        vagrant-ssh)
            ssh_to_vm "k8s-master"
            exit $?
            ;;
        vagrant-ssh-master)
            ssh_to_vm "k8s-master"
            exit $?
            ;;
        vagrant-ssh-worker1)
            ssh_to_vm "k8s-worker1"
            exit $?
            ;;
        vagrant-ssh-worker2)
            ssh_to_vm "k8s-worker2"
            exit $?
            ;;
        direct)
            shift
            run_direct_command "$*"
            exit $?
            ;;
    esac
    
    # Vagrant 상태 확인 (기본 VM)
    check_vagrant_status
    
    # Ansible 스크립트 실행
    run_ansible_script "$@"
}

# 스크립트 실행
main "$@"
