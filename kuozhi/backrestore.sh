#!/bin/bash

#for i in `ls |  cut  -c 6- ` ;do b=`echo "$i" | cut -d - -f 1`;c=`echo "$i" | cut -d - -f 2`; ./a.sh "$b" "$c" ;done
# 好几把难过，/data/backrestore/host-12834-429还原测试失败！ 积学堂
# 好几把难过，/data/backrestore/host-21487-417还原测试失败！ 江开
# 好几把难过，/data/backrestore/host-3603-391还原测试失败！
# 好几把难过，/data/backrestore/host-3603-392还原测试失败！
# 好几把难过，/data/backrestore/host-3603-393还原测试失败！ 



SHELL=/bin/dash
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

backrestore(){
filedir='/data/backup/'`ls /data/backup/ | grep "host-${userid}-${hostid}$"`
if [ $? -ne 0 ]; then
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" host-${userid}-${hostid}的备份不存在！" >> /data/backrestore.log
        return
else
        restoredir="/data/backrestore/host-${userid}-${hostid}"
fi

if [ -d "${filedir}" ]
then
        files=`find "${filedir}" -maxdepth 1 -type f -name "${date}*" | cut -d '/' -f 5`
        if [ `echo "$files"| wc -l ` -eq 2 ] && [ `echo "$files" | grep 'edusoho'` ] && [ `echo "$files" | grep 'db'` ]; then
                if [ -d "${restoredir}" ]; then
                        rm -rf "${restoredir}"/*
                else
                        mkdir -p $restoredir
                fi
                for i in $files;do
                    cp -rf "${filedir}/$i" "$restoredir"
                done
                echo -e `date "+%Y-%m-%d %H:%M:%S"`" 数据复制到${restoredir}完成！"
        else
                if [ -z $files ]; then
                    files='空'
                fi
                echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${filedir}文件夹下${date}的备份文件为${files}，不满足还原要求！" >> /data/backrestore.log
                return
        fi
else
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${filedir}备份目录不存在！" >> /data/backrestore.log
        return
fi

dirname=`tar -ztf "${restoredir}/${date}-edusoho.tar.gz" | head -1 | cut -d / -f 1`
tar -zxf "${restoredir}/${date}-edusoho.tar.gz" -C "${restoredir}"
if [ $? -eq 0 ]; then
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${date}-edusoho.tar.gz 解压完成！"
        sed -i '/^\s*database_host/c\    database_host:     127.0.0.1' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*database_port/c\    database_port:     3306' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*database_name/c\    database_name:     edusoho' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*database_user/c\    database_user:     root' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*database_password/c\    database_password:     root' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*redis_host/c\ ' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*redis_timeout/c\ ' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*redis_reserved/c\ ' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/^\s*redis_retry_interval/c\ ' "${restoredir}/${dirname}/app/config/parameters.yml"
        sed -i '/session.handler.redis/c\ ' "${restoredir}/${dirname}/app/config/parameters.yml"
        if [ -f "${restoredir}/${dirname}/app/data/redis.php" ]; then
            sudo rm -rf "${restoredir}/${dirname}/app/data/redis.php"
        fi
        sudo chown www-data:www-data "${restoredir}/${dirname}" -R
        sqlfile=`ls "${restoredir}" | grep -v 'edusoho' | grep 'db'`
        if [ $? -eq 0 ]; then
                if [ `echo "$sqlfile" | egrep 'db.gz|db.sql.gz'` ]; then
                        gunzip -c "${restoredir}/${sqlfile}" > "${restoredir}/${date}.sql"
                        if [ $? -ne 0 ]; then
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${sqlfile}解压失败！" >> /data/backrestore.log
                                return
                        fi
                        echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${sqlfile}解压完成！"
                        mysql -uroot -proot -e 'drop database IF EXISTS edusoho ; CREATE DATABASE `edusoho` DEFAULT CHARACTER SET utf8 ;'
                        mysql -uroot -proot edusoho < ${restoredir}/${date}.sql
                        if [ $? -ne 0 ]; then
                                sed -i '1d' "${restoredir}/${date}.sql"
                                mysql -uroot -proot -e 'drop database IF EXISTS edusoho ; CREATE DATABASE `edusoho` DEFAULT CHARACTER SET utf8 ;'
                                mysql -uroot -proot edusoho < ${restoredir}/${date}.sql
                                if [ $? -ne 0 ]; then
                                    echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${date}.sql还原失败！" >> /data/backrestore.log
                                    return
                                else
                                    echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${date}.sql还原成功！"
                                fi
                        else
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${date}.sql还原成功！"
                        fi
                elif [ `echo "$sqlfile" | egrep 'db.tar.gz|db.sql.tar.gz'` ]; then 
                        sudo service mysql stop
                        if [ $? -ne 0 ]; then
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" mysql stop失败！尝试清空/var/lib/mysql/并从/data/mysqlback0808还原数据库。" >> /data/backrestore.log
                                rm /var/lib/mysql/* -rf
                                cp -rf /data/mysqlback0808/* /var/lib/mysql/
                                sudo chown mysql:mysql /var/lib/mysql/ -R
                                sudo service mysql restart
                                if [ $? -eq 0 ]; then
                                    echo -e `date "+%Y-%m-%d %H:%M:%S"`" mysql restart成功！继续恢复。。。" >> /data/backrestore.log
                                    sudo service mysql stop
                                    if [ $? -ne 0 ]; then
                                        echo -e `date "+%Y-%m-%d %H:%M:%S"`" mysql stop又失败了！停止恢复。。。" >> /data/backrestore.log
                                        return
                                    fi
                                else
                                    echo -e `date "+%Y-%m-%d %H:%M:%S"`" 好几把难过，mysql restart也失败了！停止恢复。。。" >> /data/backrestore.log
                                    return
                                fi
                        fi
                        tar -zxf "${restoredir}/${sqlfile}" -C /var/lib/
                        if [ $? -ne 0 ]; then
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${sqlfile}解压失败！" >> /data/backrestore.log
                                return
                        fi
                        echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${sqlfile}解压完成！"
                        sudo rm /var/lib/mysql -rf
                        mv /var/lib/edusoho-db-backup /var/lib/mysql
                        sudo chown mysql:mysql /var/lib/mysql/ -R
                        sudo service mysql start
                        if [ $? -ne 0 ]; then
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" mysql start失败！" >> /data/backrestore.log
                                return
                        else
                                echo -e `date "+%Y-%m-%d %H:%M:%S"`" mysql ${restoredir}/${sqlfile}还原成功！"
                        fi
                else
                    echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${sqlfile}文件不符合解压条件！" >> /data/backrestore.log
                    return
                fi
        else
                echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}下无sql备份文件！" >> /data/backrestore.log
                return
        fi
else
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" ${restoredir}/${date}-edusoho.tar.gz 解压失败！" >> /data/backrestore.log
        return
fi


echo "server {
    listen 80;

    # [改] 网站的域名
    server_name 124.160.104.75;

    # 程序的安装路径
    root ${restoredir}/${dirname}/web;

    # 日志路径
    access_log /var/log/nginx/edusoho.access.log;
    error_log /var/log/nginx/edusoho.error.log;

    location / {
        index app.php;
        try_files \$uri @rewriteapp;
    }

    location @rewriteapp {
        rewrite ^(.*)\$ /app.php/\$1 last;
    }

    location ~ ^/udisk {
        internal;
        root ${restoredir}/${dirname}/app/data/;
    }

    location ~ ^/(app|app_dev)\.php(/|\$) {
        fastcgi_pass   unix:/var/run/php5-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
        fastcgi_param  HTTPS              off;
        fastcgi_param HTTP_X-Sendfile-Type X-Accel-Redirect;
        fastcgi_param HTTP_X-Accel-Mapping /udisk=${restoredir}/${dirname}/app/data/udisk;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 8 128k;
    }

    # 配置设置图片格式文件
    location ~* \.(jpg|jpeg|gif|png|ico|swf)\$ {
        # 过期时间为3年
        expires 3y;
        
        # 关闭日志记录
        access_log off;

        # 关闭gzip压缩，减少CPU消耗，因为图片的压缩率不高。
        gzip off;
    }

    # 配置css/js文件
    location ~* \.(css|js)\$ {
        access_log off;
        expires 3y;
    }

    # 禁止用户上传目录下所有.php文件的访问，提高安全性
    location ~ ^/files/.*\.(php|php5)\$ {
        deny all;
    }

    # 以下配置允许运行.php的程序，方便于其他第三方系统的集成。
    location ~ \.php\$ {
        # [改] 请根据实际php-fpm运行的方式修改
        fastcgi_pass   unix:/var/run/php5-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
        fastcgi_param  HTTPS              off;
        fastcgi_param  HTTP_PROXY         \"\";
    }
}" > /etc/nginx/sites-enabled/backrestore

nginx -t > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e `date "+%Y-%m-%d %H:%M:%S"`" nginx重启失败！" >> /data/backrestore.log
    return
fi
sudo service nginx reload > /dev/null
echo -e `date "+%Y-%m-%d %H:%M:%S"`" nginx重启成功！" 
sleep 5
curl -L -I -m 10 -o /dev/null -s -w %{http_code} http://124.160.104.75/ > /dev/null
sleep 5
httpcode=`curl -L -I -m 10 -o /dev/null -s -w %{http_code} http://124.160.104.75/`
if [ "$httpcode" -eq 200 ]; then
    echo -e `date "+%Y-%m-%d %H:%M:%S"`" 恭喜，${restoredir}还原测试1成功！"  >> /data/backrestoresuccess.log
    if [ -d "${restoredir}" ]; then
        rm -rf "${restoredir}"
    fi
else
    sleep 5
    if [ `curl -L -I -m 10 -o /dev/null -s -w %{http_code} http://124.160.104.75/` -eq 200 ]; then
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" 恭喜，${restoredir}还原测试2成功！" >> /data/backrestoresuccess.log
        if [ -d "${restoredir}" ]; then
            rm -rf "${restoredir}"
        fi
    else
        sleep 5
        if [ `curl -L -I -m 10 -o /dev/null -s -w %{http_code} http://124.160.104.75/` -eq 200 ]; then
            echo -e `date "+%Y-%m-%d %H:%M:%S"`" 恭喜，${restoredir}还原测试3成功！" >> /data/backrestoresuccess.log
            if [ -d "${restoredir}" ]; then
                rm -rf "${restoredir}"
            fi
        else
            echo -e `date "+%Y-%m-%d %H:%M:%S"`" 好几把难过，${restoredir}还原测试失败！" >> /data/backrestore.log
            return
        fi
    fi
fi
}
mailurl='http://mail.operation.codeages.net/'
if [ $# -eq 1 ] && [ "$1" = 'all' ] ;then 
        > /data/backrestore.log
        > /data/backrestoresuccess.log
        echo -e "以下是对各saas主机在"`date  +"%Y-%m-%d" -d  "-1 days"`"凌晨2点半时的备份文件，进行的还原测试情况：\n\n" >> /data/backrestore.log  
        echo -e "本次共对"`ls /data/backup |  cut  -c 6- |wc -l`"台服务器进行还原测试，成功台，失败台，还原失败详情如下：\n">> /data/backrestore.log  
        for i in `ls /data/backup |  cut  -c 6- ` ;do 
            b=`echo "$i" | cut -d - -f 1`
            c=`echo "$i" | cut -d - -f 2`
            userid="$b"
            hostid="$c"
            date=`date  +"%Y-%m-%d" -d  "-1 days"`
            backrestore
        done
        successnum=`cat /data/backrestoresuccess.log | wc -l`
        failednum=`cat /data/backrestore.log | wc -l`
        sed -i s/'成功台'/"成功${successnum}台"/g  /data/backrestore.log
        sed -i s/'失败台'/"失败$((failednum-5))台"/g  /data/backrestore.log
        sed -i 's#$#&<br />#g' /data/backrestore.log
        curl -d @/data/backrestore.log "${mailurl}?to=dingyangyang@howzhi.com,zhouxiaohui@howzhi.com,wangjianping@howzhi.com,qichen@howzhi.com&subject=Backup-Restore-Test-Result&who=edusoho_operation"
        exit 0
elif [ $# -lt 2 ] ; then
        echo -e `date "+%Y-%m-%d %H:%M:%S"`" 参数错误！请输入用户编号和主机id！如：backtest.sh 110 110"
        exit 1
else
        userid=$1
        hostid=$2
        if [ -n "$3" ]; then
                date="$3"
        else
                date=`date  +"%Y-%m-%d" -d  "-1 days"`
        fi
        backrestore
        exit 0
fi

# for i in `cat a` ;do 
#             b=`echo "$i" | cut -d - -f 1`
#             c=`echo "$i" | cut -d - -f 2`
#             userid="$b"
#             hostid="$c"
#             date=`date  +"%Y-%m-%d" -d  "-1 days"`
#             backrestore
# done
# exit 0
