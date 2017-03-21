Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"
  config.vm.provider "virtualbox" do |vm|
    vm.memory = 4096
    vm.cpus = 2
  end
  config.vm.define "ceph-aio" do |subconfig|
    subconfig.vm.hostname = "ceph-aio"
    subconfig.vm.network "private_network", ip: "172.16.35.100",  auto_config: true
    subconfig.vm.provider "virtualbox" do |vm|
        vm.name = "ceph-aio"
    end
    (1..3).each do |disk_id|
      subconfig.vm.provider "virtualbox" do |vm|
        vm.customize ["createhd", "--filename", "./tmp/disk#{disk_id}", "--size", "20480"]
        vm.customize [
          "storageattach", :id,
          "--storagectl", "SATA Controller",
          "--port", "#{disk_id}",
          "--type", "hdd",
          "--medium", "./tmp/disk#{disk_id}.vdi"]
      end
    end
  end
  config.vm.provision "file", source: "./examples", destination: "~/"
  config.vm.provision :shell, path: "./initial.sh"
end
