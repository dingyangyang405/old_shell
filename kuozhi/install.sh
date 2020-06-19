#!/bin/bash
set -x
time=`date +"%Y%m%d%H%M%S"`

#确认IP地址的有效性
is_ip() {
	ping -c 2 $var_ip >& /dev/null
	if [ $? = 0 ]
	then
		echo "即将进入安装过程"
	else
		echo "$var_ip服务器不存在"
		exit 1
	fi
}



#下面域名awk 有问题
#确认域名有效性，有效的域名则在tmp/domain.sock下写入1记录
is_domain() {
	num_domain=`echo "$var_domain" | wc -w` #域名个数
	for (( i=1; i<=$num_domain; i++ ))
	do
		domain=`echo $var_domain | awk '{print $i}'`
		ip_domain=`ping -c 2 $domain | sed -n 2p | cut -d : -f 1 | awk '{print $NF}' | cut -d ")" -f 1 | cut -d "(" -f 2`
		ping -c 2 $domain >& /dev/null
		if [ $? -eq 0 ] && [ "$ip_domain" = "$var_ip" ]
		then
			echo "$domain 域名有效"
			echo "1" >> /tmp/domain.sock
			url=$domain
		else
			echo "$domain 域名无效"
			echo "0" >> /tmp/domain.sock
		fi
	done
	#统计有效域名个数
	no_domain=`cat /tmp/domain.sock | grep 1 | wc -l`
	if [ $no_domain -eq 0 ]
	then
		url=$var_ip
		nginx_domain=`echo "$var_domain $var_ip"`
	else
		nginx_domain=`echo $var_domain`
	fi
}
is_level(){
	grep -w $var_level /etc/ansible/hosts
	if [ $? != 0 ]
	then
		echo "系统版本有误，请查看"
		exit 1
	fi
}

#检查host数据
is_hosts(){
	no_line=`grep -n children /etc/ansible/hosts | cut -d : -f 1`
	sed -n '$no_line,$p' /etc/ansible/hosts | grep $var_ip
	if [ $? != 0 ]
	then
		echo "host中未查到该ip地址"
		insert
	fi
}

#插入host文件中对应的IP地址
insert() {
	cp -rf /etc/ansible/hosts /usr/local/bak/hosts${time}old
	#查找系统版本的行数
	no_level=`grep -n -w "\[$var_level\]" /etc/ansible/hosts | cut -d : -f 1`
	sed -i "${no_level}a @	$var_ip" /etc/ansible/hosts
	sed -i "s/@//g" /etc/ansible/hosts
}


#nginx.conf配置添加body大小
is_nginx() {
	var_nginx=`ansible $var_ip -m shell -a 'grep -w client_max_body_size /etc/nginx/nginx.conf' | tail -1`
	if [ "$var_nginx" != "" ]
	then
		ansible $var_ip -m shell -a "sed -i 's/$var_nginx/	client_max_body_size 1024M;/g' /etc/nginx/nginx.conf"
	else
		ansible $var_ip -m shell -a "sed -i '17 a \	client_max_body_size 1024M;' /etc/nginx/nginx.conf"
	fi
	nginx -t
	if [ $? != 0 ]
	then
		exit 1
	else
		ansible $var_ip -m shell -a "nginx -s reload"
	fi
}


#安装过程
install() {
	echo "欢迎使用自动部署"
	cp -rf /etc/ansible/hosts /usr/local/bak/hosts$time
	cp -rf /etc/ansible/roles/newiptables/vars/hosts.yml /usr/local/bak/hosts.yml$time
	cp -rf /etc/ansible/roles/newnginx/files/edusoho	/usr/local/bak/edusoho$time
	cp -rf /etc/ansible/roles/newphp/tasks/main.yml /usr/local/bak/main.yml$time
	#对hosts中myself下的字段做变量
	var_hosts=`cat /etc/ansible/hosts | grep -A 1 -w myself | tail -1`
	var_iptables=`cat /etc/ansible/roles/newiptables/vars/hosts.yml | grep hosts | cut -d " " -f 2`
	var_nginx=`cat /etc/ansible/roles/newnginx/files/edusoho | grep -w server_name`
	var_main=`cat /etc/ansible/roles/newphp/tasks/main.yml | grep -A 1 -w 'name: Copy PHP www.conf' | tail -1 | cut -d / -f 3`
	var_nginxtrue="server_name ${nginx_domain};"
	sed -i "s/$var_hosts/$var_ip/g" /etc/ansible/hosts
	sed -i "s/$var_iptables/$var_master/g" /etc/ansible/roles/newiptables/vars/hosts.yml
	sed -i "s/$var_nginx/	$var_nginxtrue/g" /etc/ansible/roles/newnginx/files/edusoho
	unset $2
	var_mem=`ansible $var_ip -m shell -a 'free -m' | grep Mem | awk '{print $2}'`
	echo "$var_mem"
	if [ $var_mem -lt 2400 ]
	then
		var_num=2
		echo "$var_num"
	elif [ $var_mem -lt 5050 ] && [ $var_mem -ge 2600 ]
	then
		var_num=4
		echo "var_num"
	elif [ $var_mem -lt 9000 ] && [ $var_mem -ge 5050 ] 
	then
		var_num=8
		echo "var_num"
	elif [ $var_mem -ge 9050 ]
	then
		var_num=16
		echo "var_num"
	fi
	sed -i "s/$var_main/${var_num}www.conf dest=/g" /etc/ansible/roles/newphp/tasks/main.yml
	cd /etc/ansible/
	ansible-playbook newinstall.yml #此处将自动为服务器默认yes访问,在跳板机上设置StrictHostKeyChecking no配置
	echo "部署已经完成，稍后进行网址检查"
	echo "配置zabbix_agent"
	ansible $var_ip -m shell -a "sed -i 156a\HostMetadata=$var_level /etc/zabbix/zabbix_agentd.conf"
}

#初始化过程
run_go() {
	ssh root@$var_ip <<EOF
	cd /var/www/edusoho
	sudo -u www-data app/console util:init-website  $var_accesskey $var_secretkey $var_username $var_email $var_passwd $var_name
EOF

	#判断返回网页是否正常
	sleep 5
	var_url=`curl -f http://${url}/systeminfo`
	if [ "$?" = 0 ]
	then
		echo "The requested URL returned succeed"
		rm -rf /tmp/domain.sock
		exit 0
	else
		echo "The requested URL returned error: 404 Not Found"
		rm -rf /tmp/domain.sock
		exit 1
	fi
}

#传参过程
while getopts ":i:m:d:l:a:s:u:p:e:n:hv" arg #选项后面的冒号表示该选项需要参数
do
    case $arg in
        i)
            var_ip=$OPTARG  #IP 参数存在$OPTARG中
            ;;
        m)
			var_master=$OPTARG  #主机号
            ;;
        d)
			var_domain=$OPTARG  #域名 
#此处需添加额外的其他参数，
#可参照域名1 域名2 域名3来判断
            ;;
        l)
			var_level=$OPTARG  #需要安装的系统版本
            ;;
        a)
			var_accesskey=$OPTARG  #初始化安装参数accesskey
            ;;
        s)
			var_secretkey=$OPTARG  #初始化安装参数secretkey
            ;;
        u)
			var_username=$OPTARG  #初始化安装参数username
            ;;
        p)
			var_passwd=$OPTARG  #初始化安装参数passwd
            ;;
        e)
			var_email=$OPTARG  #初始化安装参数email
            ;;
        n)
			var_name=$OPTARG  #初始化安装参数网校名称name
            ;;
        h)
		#获取帮助
			echo "Usage : ./autoinstall.sh [options...]"
			echo "-i --ip           安装saas主机的ip地址;"
			echo "-m --master       安装saas主机的主机号;"
			echo "-d --domain       安装edusoho的域名，如果有多个域名请使用单引号包括，如'dns1 dns2 dns3';"
			echo "-l --level        安装edusoho的版本:"
			echo "					web_personal_ali"
			echo "					web_personal_baidu"
			echo "					web_basic_ali"
			echo "					web_basic_baidu"
			echo "					web_medium_ali"
			echo "					web_medium_baidu"
			echo "					web_advanced_ali"
			echo "					web_advanced_baidu"
			echo "					web_gold_ali"
			echo "					web_gold_baidu"
			echo "					web_custom_ali"
			echo "					web_custom_baidu"
			echo "					web_wanren_ali"
			echo "					web_wanren_baidu"
			echo "					web_tongyong_ali"
			echo "					web_tongyong_baidu"
			echo "-a --accesskey    accesskey验证码;"
			echo "-s --secretkey    secretkey验证码;"
			echo "-u --username     edusoho管理员用户，建议admin;"
			echo "-e --email        edusoho管理员邮箱;"
			echo "-p --passwd       edusoho管理员密码;"
			echo "-v --version      autoinstall版本说明;"
			echo "-h --help         autoinstall使用帮助;"
			echo "-n --name         edusoho网校名称;"
			echo "样例：./saasinstall.sh -i 118.89.22.72 -m es-119 -d 'wangj11111p.edusoho.cn xxx12.edusoho.cn' -l web_tongyong_baidu -a wsxqaz -s edcrfv -u admin -e 1111111@163.com -p admin -n 阔知"
			exit
            ;;
        v)
            echo "-v 脚本版本号3.5"
			echo "解决 
			输入参数问题，客户版本问题、默认访问问题、主机存活判断问题
			增加云平台传递的初始化参数功能！
			完善了传递参数的成立性判断
			完善主机判断机制
			完善备份机制
			主机IP地址参数由-p 更改为-i
			3.2
			增加完成安装对网址的判断。
			增加对云平台的返回值
			修改帮助文档
			去除首次ssh登录判断，在跳板机做设置
			3.3
			修改配置文件的修改策略
			3.4
			增加多域名支持
			增加域名的判断，如果所有域名都不可用的情况会直接退出
			3.5
			增加初始化数据库时网校名称参数
			4.0
			对框架整体更改，更清晰，修复初始化bug
"
			exit
            ;;
        ?) 
			#var_num=[$OPTIND - 1]
			#此处需要修复提升错误详细
			echo "未合法的参数"  # $OPTIND 表示输入的参数标识
			exit 1
			;;
		esac
done

if [ $var_ip ] && [ $var_level ] && [ "$var_domain" ] && [ $var_master ] && [ $var_accesskey ] && [ $var_secretkey ] && [ $var_username ] && [ $var_email ] && [ $var_passwd ] && [ $var_name ]
then
	is_ip
	is_level
	is_hosts
	is_domain
	is_hosts
	install
	is_nginx
	run_go
else
	echo "请输入-h 查看帮助"
	exit 1
fi






