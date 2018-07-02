#!/bin/bash
#
# Setup Spark with Hadoop on localhost.
#

HDP_VERSION="2.7.3"
SPARK_VERSION="2.0.0"

# install package
sudo apt-get install -y expect

expect -c "
spawn ssh-keygen -t rsa -P \"\"
expect \"Enter passphrase (empty for no passphrase):\"
send \"\r\"
expect \"Enter same passphrase again:\"
send \"\r\"
"

cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
ssh -o StrictHostKeyChecking=no localhost echo "Login Ok...."
ssh -o StrictHostKeyChecking=no 0.0.0.0 echo "Login Ok...."

# install hadoop
SOURE_URL="http://apache.stu.edu.tw/hadoop/common"
sudo chown -R ${USER}:${USER} /opt/
cd /opt/
curl -sSL ${SOURE_URL}/hadoop-${HDP_VERSION}/hadoop-${HDP_VERSION}.tar.gz | tar xz
mv hadoop-${HDP_VERSION}/ hadoop
cd /opt/hadoop/etc/hadoop/
sudo rm -rf core-site.xml mapred-site.xml.template hdfs-site.xml yarn-site.xml

# configure hadoop
CONF_DIR="/opt/hadoop/etc/hadoop"
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-oracle' >> ${CONF_DIR}/hadoop-env.sh
sudo mkdir -p /app/hadoop/tmp
sudo mkdir -p /usr/local/hadoop/tmp/dfs/name/current/
sudo chown ${USER}:${USER} /app/hadoop/tmp
sudo chown -R ${USER}:${USER} /usr/local/hadoop

SHARE_DIR="/opt/hadoop/share/hadoop"
for file in aws-java-sdk-1.7.4.jar hadoop-aws-2.7.3.jar jackson-databind-2.2.3.jar jackson-annotations-2.2.3.jar jackson-core-2.2.3.jar; do
  sudo cp ${SHARE_DIR}/tools/lib/${file} ${SHARE_DIR}/common/lib/
done

CONF_URL="https://gist.githubusercontent.com/kairen/5c2aa2855dd7ca6c4dda645df75a40https://gist.githubusercontent.com/kairen/5c2aa2855dd7ca6c4dda645df75a4085/raw/d2a96ac329558f0840b4fe54cff6803c51c261df"
wget ${CONF_URL}/core-site.xml
wget ${CONF_URL}/mapred-site.xml
wget ${CONF_URL}/hdfs-site.xml
wget ${CONF_URL}/yarn-site.xml

# namenode format
/opt/hadoop/bin/hadoop namenode -format <<EOF
reload
y
EOF

# start hadoop
/opt/hadoop/sbin/start-yarn.sh
/opt/hadoop/sbin/start-dfs.sh

cd ~/
echo "export HADOOP_HOME=/opt/hadoop" >> .bashrc
echo "export PATH=\$PATH:\$HADOOP_HOME" >> .bashrc
echo "export HADOOP_BIN=/opt/hadoop/bin" >> .bashrc
echo "export PATH=\$PATH:\$HADOOP_BIN" >> .bashrc
source .bashrc

# install spark
echo "Install Spark ...."
SPARK_URL="http://d3kbcqa49mib13.cloudfront.net"
curl -sSL ${SPARK_URL}/spark-${SPARK_VERSION}-bin-hadoop2.7.tgz | tar zx
sudo mv spark-${SPARK_VERSION}-bin-hadoop2.7 /opt/spark
sudo chown -R ${USER}:${USER} /opt/spark

cat <<EOF > /opt/spark/conf/spark-env.sh
export HADOOP_CONF_DIR=${CONF_DIR}
export YARN_CONF_DIR=${CONF_DIR}
export SPARK_HOME=/opt/spark
export PATH=\$SPARK_HOME/bin:\$PATH
SPARK_LOCAL_IP=127.0.0.1
EOF

LIB_DIR="/opt/hadoop/share/hadoop/common/lib"
cat <<EOF > /opt/spark/conf/spark-defaults.conf
spark.hadoop.fs.s3a.impl      org.apache.hadoop.fs.s3a.S3AFileSystem
spark.executor.extraClassPath ${LIB_DIR}/aws-java-sdk-1.7.4.jar:${LIB_DIR}/hadoop-aws-2.7.3.jar
spark.driver.extraClassPath   ${LIB_DIR}//aws-java-sdk-1.7.4.jar:${LIB_DIR}//hadoop-aws-2.7.3.jar
EOF

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

echo "export SPARK_HOME=/opt/spark" >> .bashrc
echo "export PATH=\$SPARK_HOME/bin:\$PATH" >> .bashrc

echo -e "
+-------------------+
| Install Finish :) |
+-------------------+
"
echo "Please type : \"source .bashrc\" to export env variable"
