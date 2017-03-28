#!/bin/bash

set -e

# Install docker
echo -e "
+-----------------+
| Install Pkg ... |
+-----------------+
"
sudo apt-get update &>/dev/null
sudo apt-get install -y python-setuptools &>/dev/null
sudo easy_install pip &>/dev/null && sudo pip install boto &>/dev/null
curl -fsSL https://get.docker.com/ | sh &>/dev/null
sudo gpasswd -a vagrant docker &>/dev/null

# Build rados-java
echo -e "
+----------------------+
| Build rados-java ... |
+----------------------+
"
curl -s  "http://ftp.tc.edu.tw/pub/Apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz" | tar zx
sudo mv apache-maven-3.3.9 /usr/local/maven
sudo ln -s /usr/local/maven/bin/mvn /usr/bin/mvn
sudo ln -s /usr/share/java/jna-*.jar /usr/lib/jvm/java-8-oracle/jre/lib/ext/
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
sudo docker network create --driver bridge ceph-net &>/dev/null
DIR="/home/vagrant/"

## mon
sudo docker pull ceph/daemon &>/dev/null
sudo docker run -d --net=ceph-net \
-v ${DIR}/ceph:/etc/ceph \
-v ${DIR}/lib/ceph/:/var/lib/ceph/ \
-e MON_IP=172.18.0.2 \
-e CEPH_PUBLIC_NETWORK=172.18.0.0/16 \
--name mon1 \
ceph/daemon mon &>/dev/null

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
    ceph/daemon osd &>/dev/null

    sleep 1
done

sudo docker run -d --net=ceph-net \
-v ${DIR}/lib/ceph/:/var/lib/ceph/ \
-v ${DIR}/ceph:/etc/ceph \
-p 8080:8080 \
--name rgw1 \
ceph/daemon rgw &>/dev/null

sudo cp ${DIR}/ceph/* /etc/ceph
sudo chmod 775 /etc/ceph/ceph.client.admin.keyring
sudo ceph osd pool create data 32 &>/dev/null

cd ~/
cat <<EOFF > ${DIR}/create-s3-account.sh
#!/bin/bash

sudo docker exec -ti rgw1 radosgw-admin user create --uid="test" --display-name="I'm Test account" --email="test@example.com" --access-key="access-test" --secret-key="secret-test"
curl -sSL https://gist.githubusercontent.com/kairen/e0dec164fa6664f40784f303076233a5/raw/33add5a18cb7d6f18531d8d481562d017557747c/s3client -o s3client
chmod u+x s3client
cat <<EOF > test-key.sh
export S3_ACCESS_KEY="access-test"
export S3_SECRET_KEY="secret-test"
export S3_HOST="127.0.0.1"
export S3_PORT="8080"
EOF
EOFF

sudo chmod u+x ${DIR}/create-s3-account.sh
sudo chown vagrant ${DIR}/create-s3-account.sh
echo -e "
+-------------+
| Enjoying :) |
+-------------+
"
