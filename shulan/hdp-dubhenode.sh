#!/bin/bash
user="`whoami`"
if [[ "${user}" != "root" ]];then
  echo 当前执行脚本的用户为 ${user}，请加sudo或者root用户执行。
  exit 1
fi
read -p "请输入要安装客户端的hdp集群任意节点ip: " hdp_ip
read -s -p "请输入 $hdp_ip 的root密码: " hdp_root_passwd
hdp_port=22
sudo yum install -y openssl-devel gcc pcre-devel openssh-clients openssh openssh-devel autoconf automake > /dev/null 2>&1 
sudo yum install -y sshpass
sudo yum install -y rsync
sshpass -p $hdp_root_passwd ssh root@$hdp_ip  -p $hdp_port -o StrictHostKeyChecking=no 'echo 密码输入正确，即将开始安装。。。'
if [[ $? -ne 0 ]]; then
	echo -e '\n密码输入错误，程序退出。'
	exit 1
fi
sleep 1


sudo mkdir -p /usr/hdp/
sshpass -p $hdp_root_passwd sudo rsync -e "ssh -p $hdp_port" -av root@$hdp_ip:/usr/hdp/* /usr/hdp/ > /dev/null
sshpass -p $hdp_root_passwd sudo rsync -e "ssh -p $hdp_port" -av root@$hdp_ip:/etc/hadoop /etc/ > /dev/null
sshpass -p $hdp_root_passwd sudo rsync -e "ssh -p $hdp_port" -av root@$hdp_ip:/etc/hive /etc/ > /dev/null
sshpass -p $hdp_root_passwd sudo rsync -e "ssh -p $hdp_port" -av root@$hdp_ip:/etc/spark* /etc/ > /dev/null
sshpass -p $hdp_root_passwd sudo rsync -e "ssh -p $hdp_port" -av root@$hdp_ip:/etc/hbase* /etc/ > /dev/null

echo '
export HADOOP_COMMON_HOME=/usr/hdp/2.6.0.3-8/hadoop
export HADOOP_HDFS_HOME=/usr/hdp/2.6.0.3-8/hadoop-hdfs
export HADOOP_MAPRED_HOME=/usr/hdp/2.6.0.3-8/hadoop-mapreduce
export HADOOP_YARN_HOME=/usr/hdp/2.6.0.3-8/hadoop-yarn
export HIVE_HOME=/usr/hdp/2.6.0.3-8/hive
export HBASE_HOME=/usr/hdp/2.6.0.3-8/hbase
export SPARK_HOME=/usr/hdp/2.6.0.3-8/spark2
export SQOOP_HOME=/usr/hdp/2.6.0.3-8/sqoop
PATH=$PATH:$SPARK_HOME/bin:$HADOOP_COMMON_HOME/bin:$HADOOP_HDFS_HOME/bin:$HADOOP_MAPRED_HOME/bin:$HIVE_HOME/bin:$HBASE_HOME/bin:/usr/local/bin/python3/bin:$STORM_HOME/bin:$SQOOP_HOME/bin
export HDP_VERSION=2.6.0.3-8' | sudo tee -a /home/deploy/.bashrc > /dev/null

sudo cp /etc/hive/conf/hive-site.xml /etc/spark/conf/
sudo cp /etc/hive/conf/hive-site.xml /etc/spark2/conf/
sudo cp /etc/hive/conf/hive-site.xml /etc/hadoop/conf/
sshpass -p $hdp_root_passwd ssh root@$hdp_ip  -p $hdp_port 'sudo su - hdfs -c "hadoop fs -mkdir -p /user/deploy"'
sshpass -p $hdp_root_passwd ssh root@$hdp_ip  -p $hdp_port 'sudo su - hdfs -c "hadoop fs -mkdir -p /user/shuqi"'
sshpass -p $hdp_root_passwd ssh root@$hdp_ip  -p $hdp_port 'sudo su - hdfs -c "hadoop fs -chown -R deploy:deploy /user/deploy"'
sshpass -p $hdp_root_passwd ssh root@$hdp_ip  -p $hdp_port 'sudo su - hdfs -c "hadoop fs -chown -R deploy:deploy /user/shuqi"'
echo "HDFS permission executed successfully"
echo 'hdp客户端安装完毕，请执行以下操作以使配置生效：
1，以deploy用户执行source命令重新加载环境变量：source ~/.bashrc
2，请手动把hdp集群所有节点的hosts信息，写入执行代理的hosts文件中，重要！！！'