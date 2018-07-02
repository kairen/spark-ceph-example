#!/bin/bash

set -e

# Install docker
echo -e "
+-----------------+
| Install pkgs ... |
+-----------------+
"
sudo apt-get update &>/dev/null
sudo apt-get install -y python-setuptools &>/dev/null
sudo easy_install pip &>/dev/null && sudo pip install boto &>/dev/null
curl -fsSL https://get.docker.com/ | sh &>/dev/null
sudo gpasswd -a vagrant docker &>/dev/null

# Create a Ceph cluster
echo -e "
+-----------------------+
| Boot Ceph cluster ... |
+-----------------------+
"
sudo docker network create --driver bridge ceph-net &>/dev/null
DIR="/home/vagrant/"
VERSION="master-29f1e9c-luminous-ubuntu-16.04-x86_64"

# deploy mon
sudo docker pull ceph/daemon:${VERSION} &>/dev/null
sudo docker run -d --net=ceph-net \
  -v ${DIR}/ceph:/etc/ceph \
  -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
  -e MON_IP=172.18.0.2 \
  -e CEPH_PUBLIC_NETWORK=172.18.0.0/16 \
  --name mon \
  ceph/daemon:${VERSION} mon &>/dev/null

while [ ! -f ${DIR}/lib/ceph/bootstrap-osd/ceph.keyring  ]; do sleep 1; done

# deploy mgr
sudo docker run -d --net=ceph-net \
  -v ${DIR}/ceph:/etc/ceph \
  -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
  --name mgr \
  ceph/daemon:${VERSION} mgr &>/dev/null

# deploy osds
for device in sdb sdc sdd; do
  sudo docker run -d --net=ceph-net \
    --privileged=true --pid=host \
    -v ${DIR}/ceph:/etc/ceph \
    -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
    -v /dev/:/dev/ \
    -e OSD_DEVICE=/dev/${device} \
    -e OSD_TYPE=disk \
    -e OSD_FORCE_ZAP=1 \
    -e OSD_BLUESTORE=1 \
    --name osd-${device} \
    ceph/daemon:${VERSION} osd &>/dev/null

    sleep 1
done

# deploy mds
sudo docker run -d --net=ceph-net \
  -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
  -v ${DIR}/ceph:/etc/ceph \
  -e CEPHFS_CREATE=1 \
  --name mds \
  ceph/daemon:${VERSION} mds

# deploy rgw
sudo docker run -d --net=ceph-net \
  -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
  -v ${DIR}/ceph:/etc/ceph \
  -p 8080:8080 \
  --name rgw \
  ceph/daemon:${VERSION} rgw &>/dev/null

# deploy rest api
sudo docker run -d --net=ceph-net \
  -v ${DIR}/lib/ceph/:/var/lib/ceph/ \
  -v ${DIR}/ceph:/etc/ceph \
  -p 5000:5000 \
  --name restapi \
  ceph/daemon:${VERSION} restapi &>/dev/null

sudo cp ${DIR}/ceph/* /etc/ceph
sudo chmod 775 /etc/ceph/ceph.client.admin.keyring
sudo ceph osd pool create data 32 &>/dev/null

cd ~/
curl -sSL https://gist.githubusercontent.com/kairen/e0dec164fa6664f40784f303076233a5/raw/33add5a18cb7d6f18531d8d481562d017557747c/s3client -o s3client
chmod u+x s3client
mv s3client /usr/bin

cat <<EOFF > ${DIR}/create-rgw-user.sh
#!/bin/bash

sudo docker exec -ti rgw1 radosgw-admin user create --uid="test" --display-name="I'm Test account" --email="test@example.com" --access-key="access-test" --secret-key="secret-test"
cat <<EOF > test-key.sh
export S3_ACCESS_KEY="access-test"
export S3_SECRET_KEY="secret-test"
export S3_HOST="127.0.0.1"
export S3_PORT="8080"
EOF
EOFF

cat <<EOFF > ${DIR}/create-rgw-admin.sh
#!/bin/bash

sudo docker exec -ti rgw1 radosgw-admin user create --uid="admin" --display-name="Administrator" --email="admin@example.com" --access-key="access-admin" --secret-key="secret-admin"
for role in users buckets metadata usage zone; do
  sudo docker exec -ti rgw1 radosgw-admin caps add --uid="admin" --caps="\${role}=*"
done

cat <<EOF > admin-key.sh
export S3_ACCESS_KEY="access-admin"
export S3_SECRET_KEY="secret-admin"
export S3_HOST="127.0.0.1"
export S3_PORT="8080"
EOF
EOFF

for file in create-rgw-user.sh create-rgw-admin.sh; do
  sudo chmod u+x ${DIR}/${file}
  sudo chown vagrant ${DIR}/${file}
done

echo -e "
+-------------+
| Enjoying :) |
+-------------+
"
