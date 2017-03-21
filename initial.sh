#!/bin/bash

set -e

echo -e "
+-----------------+
| Install Pkg ... |
+-----------------+
"
sudo sed -i 's/us.archive.ubuntu.com/tw.archive.ubuntu.com/g' /etc/apt/sources.list &>/dev/null
sudo apt-get update &>/dev/null
sudo apt-get install -y software-properties-common &>/dev/null

# Add repos
curl -fsSL 'https://download.ceph.com/keys/release.asc' | sudo apt-key add - &>/dev/null
echo "deb https://download.ceph.com/debian-kraken/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/ceph.list &>/dev/null
sudo add-apt-repository -y ppa:webupd8team/java &>/dev/null
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections &>/dev/null
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections &>/dev/null

# Install packages
curl -fsSL https://get.docker.com/ | sh &>/dev/null
sudo apt-get update &>/dev/null
sudo apt-get install -y ceph oracle-java8-installer git libjna-java python-rados &>/dev/null
sudo ln -s /usr/share/java/jna-*.jar /usr/lib/jvm/java-8-oracle/jre/lib/ext/

# Build rados-java
echo -e "
+----------------------+
| Build rados-java ... |
+----------------------+
"
curl -s  "http://ftp.tc.edu.tw/pub/Apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz" | tar zx
sudo mv apache-maven-3.3.9 /usr/local/maven
sudo ln -s /usr/local/maven/bin/mvn /usr/bin/mvn
git clone "https://github.com/ceph/rados-java.git" &>/dev/null
cd rados-java && git checkout v0.3.0 &>/dev/null
mvn clean install -Dmaven.test.skip=true &>/dev/null
sudo cp target/rados-0.3.0.jar /usr/share/java
sudo ln -s /usr/share/java/rados-0.3.0.jar /usr/lib/jvm/java-8-oracle/jre/lib/ext/

# Create a Ceph cluster
echo -e "
+-----------------------+
| Boot Ceph cluster ... |
+-----------------------+
"
sudo docker network create --driver bridge ceph-net
DIR="/home/vagrant/"

## mon
sudo docker pull ceph/daemon &>/dev/null
sudo docker run -d --net=ceph-net \
-v ${DIR}/ceph:/etc/ceph \
-v ${DIR}/lib/ceph/:/var/lib/ceph/ \
-e MON_IP=172.18.0.2 \
-e CEPH_PUBLIC_NETWORK=172.18.0.0/16 \
--name mon1 \
ceph/daemon mon

while [ ! -f ${DIR}/lib/ceph/bootstrap-osd/ceph.keyring  ]; do sleep 1; done

## osd
for device in sdb sdc sdd; do
  sudo docker run -d --net=ceph-net \
    --privileged=true --pid=host \
    -v ${DIR}/ceph:/etc/ceph \
    -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
    -v /dev/:/dev/ \
    -e OSD_DEVICE=/dev/${device} \
    -e OSD_TYPE=disk \
    -e OSD_FORCE_ZAP=1 \
    --name osd-${device} \
    ceph/daemon osd

    sleep 1
done

sudo cp ${DIR}/ceph/* /etc/ceph
sudo ceph osd pool create data 32 &>/dev/null

echo -e "
+-------------+
| Enjoying :) |
+-------------+
"
