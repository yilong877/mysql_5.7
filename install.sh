#!/bin/bash
# ==============================
# Author: Lance Zhao
# Email: yilong877@gmail.com
# ==============================

. ./config


# install mysql dependencies
yum install gcc gcc-c++ make ncurses ncurses-devel \
            cmake bison openssl openssl-devel -y


# download mysql source code.
wget https://dev.mysql.com//Downloads/MySQL-5.7/mysql-boost-5.7.37.tar.gz

# check md5sum
MD5=`md5sum mysql-boost-5.7.37.tar.gz | awk '{print $1}'`


# compile and install
if [ ${MD5} == ${original_boost_MD5} ]; then

    # add group mysql and add user mysql to group mysql
    groupadd -r mysql
    useradd -r -M -g mysql -s /bin/false mysql

    # make directories
    mkdir -p ${base_dir}/{data,tmp}

    tar -zxvf mysql-boost-5.7.37.tar.gz
    cd mysql-5.7.37

    # set compile options
    counter=0

    compile

    while [ $? -ne 0 ]; do

        let $counter++

        if [ ${counter} -eq 3 ]; then
            echo "compiling failed......please compile manually"
            echo "Exit!!!"
            exit 2
        fi

        rm -rf CMakeCache.txt && make clean
        compile
    done

    # backup my.cnf
    mv /etc/my.cnf{,.bak}

    # create my.cnf
    cat > /etc/my.cnf <<EOF
[mysqld]
basedir=${base_dir}
datadir=${base_dir}/data
socket=${base_dir}/tmp/mysql.sock
port=3306
user=mysql
symbolic-links=0
character_set_server=utf8
tls_version=TLSv1.2
log-error=${base_dir}/tmp/error.log
server-id=1
log-bin=mysql-bin
[client]
port=3306
socket=${base_dir}/tmp/mysql.sock
EOF

    # set ENV
    echo "MYSQL_HOME=${base_dir}" >> /etc/profile
    echo 'PATH=$PATH:$MYSQL_HOME/bin' >> /etc/profile
    echo 'export MYSQL_HOME PATH' >> /etc/profile
    source /etc/profile

    # create files necessary
    touch ${base_dir}/tmp/{mysqld.pid,mysql.sock,error.log}
    chown -R mysql:mysql ${base_dir}

    # initialize mysql
    ${base_dir}/bin/mysqld --initialize-insecure --user=mysql \
                           --basedir=${base_dir} --datadir=${data_dir}

    # cp autostart file
    cp ${base_dir}/usr/lib/systemd/system/mysqld.service /usr/lib/systemd/system/
    systemctl daemon-reload

    # start mysql
    systemctl enable mysqld.service && systemctl start mysqld.service
    ${base_dir}/bin/mysqladmin -u root password "$password"

else
    echo "Oops, file is not correct or downloading failed......"
    echo "Exit!"
    exit 1
fi

