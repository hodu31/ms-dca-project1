# ms-dca-project1

# 모두 윈도우 환경에서 git bash 로 실행
1. vagrant up
2. ./scripts/vagrant-ansible.sh setup          # 초기 설정
3. ./scripts/vagrant-ansible.sh ping           # 연결 테스트0
4. ./scripts/vagrant-ansible.sh playbook docker-setup  # Docker 설치
5. ./scripts/vagrant-ansible.sh playbook k8s-cluster   # K8s 구축
6. ./scripts/vagrant-ansible.sh playbook k8s-dashboard # 쿠버네티스 대시 보드 설치 (쿠버네티스 구성할때만 쓸 예정)