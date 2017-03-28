#!/bin/bash

USER_NAME=$(whoami)
HADOOP_VERSION="hadoop-2.7.3"
SPARK_VER="2.0.0"

HOST_NAME=$(hostname)
sudo sed "2c 127.0.1.1 $(hostname)" -i /etc/hosts

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

# download hadoop
sudo chown -R ${USER}:${USER} /opt/
cd /opt/

wget http://apache.stu.edu.tw/hadoop/common/${HADOOP_VERSION}/${HADOOP_VERSION}.tar.gz
tar xvzf ${HADOOP_VERSION}.tar.gz
rm ${HADOOP_VERSION}.tar.gz
cd /opt/${HADOOP_VERSION}/etc/hadoop/
sudo rm -rf core-site.xml mapred-site.xml.template hdfs-site.xml yarn-site.xml

# hadoop-env.sh
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-oracle' >> /opt/${HADOOP_VERSION}/etc/hadoop/hadoop-env.sh

# core-site.xml
sudo mkdir -p /app/hadoop/tmp
sudo chown ${USER}:${USER} /app/hadoop/tmp
SHARE_DIR="/opt/${HADOOP_VERSION}/share/hadoop"

for file in aws-java-sdk-1.7.4.jar hadoop-aws-2.7.3.jar jackson-databind-2.2.3.jar jackson-annotations-2.2.3.jar jackson-core-2.2.3.jar; do
  sudo cp ${SHARE_DIR}/tools/lib/${file} ${SHARE_DIR}/common/lib/
done


cat <<EOF > /opt/${HADOOP_VERSION}/etc/hadoop/core-site.xml
<?xml version="1.0"?><?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
  <name>fs.defaultFS</name>
  <value>hdfs://localhost:9000</value>
</property>

<property>
  <name>hadoop.tmp.dir</name>
  <value>/app/hadoop/tmp</value>
  <description>A base for other temporary directories.</description>
</property>

<property>
  <name>fs.s3a.access.key</name>
  <value>access-test</value>
</property>

<property>
<name>fs.s3a.secret.key</name>
  <value>secret-test</value>
</property>

<property>
  <name>fs.s3a.endpoint</name>
  <value>172.16.35.100:8080</value>
</property>

<property>
  <name>fs.s3a.connection.ssl.enabled</name>
  <value>false</value>
  <description>Enables or disables SSL connections to S3.</description>
</property>
</configuration>
EOF

# mapred-site.xml
echo '<?xml version="1.0"?><?xml-stylesheet type="text/xsl" href="configuration.xsl"?><configuration><property><name>mapreduce.framework.name</name><value>yarn</value></property></configuration>' >> /opt/${HADOOP_VERSION}/etc/hadoop/mapred-site.xml

sudo mkdir -p /usr/local/hadoop/tmp/dfs/name/current/
sudo chown -R ${USER}:${USER} /usr/local/hadoop
# hdfs-site.xml
echo '<?xml version="1.0"?><?xml-stylesheet type="text/xsl" href="configuration.xsl"?><configuration><property><name>dfs.replication</name><value>1</value></property><property><name>dfs.namenode.name.dir</name><value>file:/usr/local/hadoop/tmp/dfs/name</value></property><property><name>dfs.datanode.data.dir</name><value>file:/usr/local/hadoop/tmp/dfs/data</value></property><property><name>dfs.permissions</name><value>false</value></property></configuration>' >> /opt/${HADOOP_VERSION}/etc/hadoop/hdfs-site.xml

# yarn-site.xml
echo '<?xml version="1.0"?><configuration><property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property></configuration>' >> /opt/${HADOOP_VERSION}/etc/hadoop/yarn-site.xml

# namenode format
/opt/${HADOOP_VERSION}/bin/hadoop namenode -format <<EOF
reload
y
EOF


# start hadoop
/opt/${HADOOP_VERSION}/sbin/start-yarn.sh
/opt/${HADOOP_VERSION}/sbin/start-dfs.sh

echo "export HADOOP_HOME=\"/opt/${HADOOP_VERSION}\"" | sudo tee -a ~/.bashrc
echo "export PATH=\$PATH:\$HADOOP_HOME" | sudo tee -a ~/.bashrc
echo "export HADOOP_BIN=\"/opt/${HADOOP_VERSION}/bin\"" | sudo tee -a ~/.bashrc
echo "export PATH=\$PATH:\$HADOOP_BIN" | sudo tee -a ~/.bashrc
source ~/.bashrc

# install spark
echo "Install Spark ...."
curl -s http://archive.apache.org/dist/spark/spark-${SPARK_VER}/spark-${SPARK_VER}-bin-hadoop2.7.tgz | sudo tar -xz -C /opt/
sudo mv /opt/spark-${SPARK_VER}-bin-hadoop2.7 /opt/spark
sudo chown ${USER_NAME}:${USER_NAME} -R /opt/spark

echo "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" | sudo tee -a /opt/spark/conf/spark-env.sh
echo "export YARN_CONF_DIR=\$HADOOP_HOME/etc/hadoop" | sudo tee -a /opt/spark/conf/spark-env.sh
echo "export SPARK_HOME=/opt/spark" | sudo tee -a /opt/spark/conf/spark-env.sh
echo "export PATH=\$SPARK_HOME/bin:\$PATH" | sudo tee -a /opt/spark/conf/spark-env.sh

echo "export SPARK_HOME=/opt/spark" | sudo tee -a ~/.bashrc
echo "export PATH=\$SPARK_HOME/bin:\$PATH" | sudo tee -a ~/.bashrc

echo -e "
+-------------------+
| Install Finish :) |
+-------------------+
"
echo "Please type : \"source .bashrc\" to export env variable"
