#!/bin/bash
yum install -y wget nano less cronie openssh-clients openssh-server openssh openssl cifs-utils

hostnamectl set-hostname $1
echo "`hostname -I` `hostname`"	>> /etc/hosts

systemctl start firewalld
systemctl enable firewalld
firewall-cmd --zone=public --add-port=22/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=4432/tcp --permanent
firewall-cmd --zone=public --add-port=4433/tcp --permanent
firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --zone=public --add-port=8081/tcp --permanent
firewall-cmd --zone=public --add-port=8140/tcp --permanent
firewall-cmd --zone=public --add-port=8142/tcp --permanent
firewall-cmd --zone=public --add-port=8143/tcp --permanent
firewall-cmd --zone=public --add-port=8170/tcp --permanent
firewall-cmd --reload

mkdir -p /etc/puppetlabs/puppet
mkdir -p /etc/puppetlabs/puppetserver/ssh
ssh-keygen -t rsa -b 4096 -N "" -f /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa

export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

PE_VERSION=$(curl -s http://versions.puppet.com.s3-website-us-west-2.amazonaws.com/ | tail -n1)
PE_SOURCE=puppet-enterprise-${PE_VERSION}-el-7-x86_64
DOWNLOAD_URL=https://s3.amazonaws.com/pe-builds/released/${PE_VERSION}/${PE_SOURCE}.tar.gz

while [ 1 ]; do
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 --tries=0 --continue --progress=bar ${DOWNLOAD_URL}
    if [ $? = 0 ]; then break; fi; # check return value, break if successful (0)
    sleep 1s;
done;
tar zxf ${PE_SOURCE}.tar.gz

cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
extension_requests:
    pp_role:  master_server
YAML

cd ${PE_SOURCE}

cat > pe.conf << FILE
"console_admin_password": "puppet"
"puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
"puppet_enterprise::profile::master::code_manager_auto_configure": true
"puppet_enterprise::profile::master::r10k_remote": "https://github.com/puppetlabs/control-repo.git"
"puppet_enterprise::profile::master::r10k_private_key": "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
FILE

./puppet-enterprise-installer -c pe.conf
chown -R pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh
puppet agent -t
puppet agent -t

/opt/puppetlabs/puppet/bin/gem install bolt

cd ..
rm -fr ${PE_SOURCE}
rm -f ${PE_SOURCE}.tar.gz
yum clean all
rm -rf /var/cache/yum/x86_64/7/puppet_enterprise
echo 'eval `ssh-agent`'>> ~/.bashrc
history -c
