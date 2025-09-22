# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# config.yaml 파일 로드
config_file = File.join(File.dirname(__FILE__), 'config.yaml')
if File.exist?(config_file)
  settings = YAML.load_file(config_file)
else
  puts "Warning: config.yaml not found. Using default values."
  settings = {}
end

# 설정값 가져오기
def get_setting(settings, key, default_value)
  settings[key] || default_value
end

Vagrant.configure("2") do |config|
  
  # 설정값 로드
  root_password = get_setting(settings, 'ROOT_PASSWORD', 'owncloud123!')
  vagrant_password = get_setting(settings, 'VAGRANT_PASSWORD', 'vagrant123')
  
  network_subnet = get_setting(settings, 'NETWORK_SUBNET', '192.168.56')
  k8s_master_ip = get_setting(settings, 'K8S_MASTER_IP', '192.168.56.30')
  k8s_worker_start_ip = get_setting(settings, 'K8S_WORKER_START_IP', '31')
  
  k8s_master_memory = get_setting(settings, 'K8S_MASTER_MEMORY', 3072).to_i
  k8s_worker_memory = get_setting(settings, 'K8S_WORKER_MEMORY', 2048).to_i
  worker_count = get_setting(settings, 'K8S_WORKER_COUNT', 2).to_i

  # 공통 환경변수 설정
  common_env = {
    'ROOT_PASSWORD' => root_password,
    'VAGRANT_PASSWORD' => vagrant_password,
    'NETWORK_SUBNET' => network_subnet,
    'K8S_MASTER_IP' => k8s_master_ip,
    'K8S_WORKER_START_IP' => k8s_worker_start_ip,
    'K8S_WORKER_COUNT' => worker_count.to_s
  }
  
  # Kubernetes Master (k8s-master)
  config.vm.define "k8s-master" do |master|
    master.vm.box = "generic/rocky9"
    master.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = k8s_master_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "k8s-master"
      vmware.linked_clone = false
      
      # VMware Workstation 17 호환성 설정
      vmware.vmx["virtualhw.version"] = "19"
      vmware.vmx["virtualHW.productCompatibility"] = "hosted"
      vmware.vmx["tools.syncTime"] = "TRUE"
    end
    
    master.vm.hostname = "k8s-master"
    master.vm.synced_folder ".", "/vagrant", disabled: true
    master.vm.network "private_network", ip: k8s_master_ip, netmask: "255.255.255.0"
    
    # SSH 키 복사를 위한 설정
    master.vm.synced_folder ".", "/home/vagrant/shared", create: true, owner: "vagrant", group: "vagrant"
    
    master.vm.provision "shell", path: "scripts/common_script.sh", env: common_env
    master.vm.provision "shell", path: "scripts/k8s_node_script.sh", env: common_env
    master.vm.provision "shell", path: "scripts/master.sh", env: common_env
    
  end
  
  # Kubernetes Workers (k8s-worker1, k8s-worker2, ...)
  (1..worker_count).each do |i|
    config.vm.define "k8s-worker#{i}" do |worker|
      worker.vm.box = "generic/rocky9"
      worker.vm.provider "vmware_desktop" do |vmware|
        vmware.gui = false
        vmware.memory = k8s_worker_memory
        vmware.cpus = 2
        vmware.vmx["displayName"] = "k8s-worker#{i}"
        vmware.linked_clone = false
        
        # VMware Workstation 17 호환성 설정
        vmware.vmx["virtualhw.version"] = "19"
        vmware.vmx["virtualHW.productCompatibility"] = "hosted"
        vmware.vmx["tools.syncTime"] = "TRUE"
      end
      
      worker.vm.hostname = "k8s-worker#{i}"
      worker.vm.synced_folder ".", "/vagrant", disabled: true
      
      worker_ip = "#{network_subnet}.#{k8s_worker_start_ip.to_i + i - 1}"
      worker.vm.network "private_network", ip: worker_ip, netmask: "255.255.255.0"
      
      # Worker 전용 환경변수 추가
      worker_env = common_env.merge({
        'WORKER_IP' => worker_ip,
        'WORKER_NUM' => i.to_s
      })
      
      worker.vm.provision "shell", path: "scripts/common_script.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/k8s_node_script.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/worker.sh", env: worker_env
    end
  end
end