#!/bin/bash
user="`whoami`"
if [[ "${user}" != "root" ]];then
  echo 当前执行脚本的用户为 ${user}，请加sudo或者root用户执行。
  exit 1
fi
read -p "请输入要安装客户端的cdh集群任意节点ip: " cdh_ip
read -s -p "请输入 $cdh_ip 的root密码: " cdh_root_passwd
# cdh_ip=10.26.251.93
# cdh_root_passwd=
cdh_port=22
sudo yum install -y openssl-devel gcc pcre-devel openssh-clients openssh openssh-devel autoconf automake > /dev/null 2>&1 
sudo yum install -y sshpass
sudo yum install -y rsync
sshpass -p $cdh_root_passwd ssh root@$cdh_ip  -p $cdh_port -o StrictHostKeyChecking=no 'echo 密码输入正确，即将开始安装。。。'
if [[ $? -ne 0 ]]; then
	echo -e '\n密码输入错误，程序退出。'
	exit 1
fi
sleep 1
sudo mkdir -p /opt/cloudera/parcels
echo 'start rsync /opt/cloudera/parcels...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/opt/cloudera/parcels /opt/cloudera/  > /dev/null
echo 'rsync /opt/cloudera/parcels ok!'
sudo chown -R deploy:deploy /opt/cloudera/parcels
echo '
export HADOOPHOME=/opt/cloudera/parcels/CDH/lib/hadoop 
export SPARKHOME=/opt/cloudera/parcels/CDH/lib/spark
export PATH=$PATH:$HADOOPHOME/sbin:$HADOOPHOME/bin:$SPARKHOME/bin' | sudo tee -a /home/deploy/.bashrc > /dev/null
echo 'start rsync /etc/alternatives/*...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/etc/alternatives/* /etc/alternatives/ > /dev/null
echo 'rsync /etc/alternatives/* ok!'
echo 'start rsync /etc/hadoop...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/etc/hadoop /etc/ > /dev/null
echo 'rsync /etc/hadoop ok!'
echo 'start rsync /etc/hive...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/etc/hive /etc/ > /dev/null
echo 'rsync /etc/hive ok!'
echo 'start rsync /etc/spark*...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/etc/spark* /etc/ > /dev/null
echo 'rsync /etc/spark* ok!'
echo 'start rsync /etc/hbase*...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/etc/hbase* /etc/ > /dev/null
echo 'rsync /etc/hbase* ok!'
echo 'start rsync /usr/bin/spark*...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/usr/bin/spark* /usr/bin/ > /dev/null
echo 'rsync /usr/bin/spark* ok!'
echo 'start rsync /usr/bin/h*...'
sshpass -p $cdh_root_passwd sudo rsync -e "ssh -p $cdh_port" -av root@$cdh_ip:/usr/bin/h* /usr/bin/ > /dev/null
echo 'rsync /usr/bin/h* ok!'
cd /etc/alternatives
ln -s /etc/hive/conf.cloudera.hive hive-conf
ln -s /etc/hadoop/conf.cloudera.yarn hadoop-conf
ln -s /etc/spark/conf.cloudera.spark spark-conf
cd /etc/hive
ln -s /etc/alternatives/hive-conf conf
cd /etc/hadoop
ln -s /etc/alternatives/hadoop-conf conf
cd /etc/hbase
ln -s /etc/alternatives/hbase-conf conf
sudo cp /etc/hive/conf/hive-site.xml /etc/spark/conf/
sudo cp /etc/hive/conf/hive-site.xml /etc/spark2/conf/
sudo cp /etc/hive/conf/hive-site.xml /etc/hadoop/conf/
sudo cp /etc/yarn/conf/yarn-site.xml /etc/hadoop/conf/
sshpass -p $cdh_root_passwd ssh root@$cdh_ip  -p $cdh_port 'sudo su - hdfs -c "hadoop fs -mkdir -p /user/deploy"'
sshpass -p $cdh_root_passwd ssh root@$cdh_ip  -p $cdh_port 'sudo su - hdfs -c "hadoop fs -mkdir -p /user/shuqi"'
sshpass -p $cdh_root_passwd ssh root@$cdh_ip  -p $cdh_port 'sudo su - hdfs -c "hadoop fs -chown -R deploy:deploy /user/deploy"'
sshpass -p $cdh_root_passwd ssh root@$cdh_ip  -p $cdh_port 'sudo su - hdfs -c "hadoop fs -chown -R deploy:deploy /user/shuqi"'

echo "HDFS permission executed successfully"
echo 'cdh客户端安装完毕，请执行以下操作以使配置生效：
1，以deploy用户执行source命令重新加载环境变量：source ~/.bashrc
2，请手动把cdh集群所有节点的hosts信息，写入执行代理的hosts文件中，重要！！！'
