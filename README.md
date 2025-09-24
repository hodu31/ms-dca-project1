# ms-dca-project1

# 모두 윈도우 환경에서 git bash 로 실행
1. vagrant up
2. ./scripts/vagrant-ansible.sh setup          # 초기 설정
3. ./scripts/vagrant-ansible.sh ping           # 연결 테스트0
4. ./scripts/vagrant-ansible.sh playbook k8s-cluster   # K8s 구축
5. ./scripts/vagrant-ansible.sh playbook nfs-setup   # nfs 설정
6. ./scripts/vagrant-ansible.sh playbook helm-setup    # 기본 그라파나 프로메테우스 provisioner 설치


0. ./scripts/vagrant-ansible.sh deploy-all # 한번에 설치하기