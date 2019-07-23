#!/bin/bash -ex
sed -i "s/^#Port 22/Port 443/" /etc/ssh/sshd_config
service sshd restart
amazon-linux-extras install ansible2
mkdir /tmp/ansible
cat <<EOF > ~/.ssh/id_rsa.pem
${ssh_key}
EOF
chmod 400 ~/.ssh/id_rsa.pem
cat <<EOF >  /tmp/ansible/hosts
[master]
master ansible_host=${master_ip} ansible_user=ubuntu

[workers]
worker1 ansible_host=${worker1_ip} ansible_user=ubuntu
worker2 ansible_host=${worker2_ip} ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
cat <<EOF > /tmp/ansible/ansible.cfg
[defaults]
host_key_checking = false
private_key_file = ~/.ssh/id_rsa.pem
EOF
cat <<EOF > /tmp/ansible/dependencies.yml
${dependencies}
EOF
cat <<EOF > /tmp/ansible/master.yml
${master}
EOF
cat <<EOF > /tmp/ansible/workers.yml
${workers}
EOF
ansible-playbook -i hosts /tmp/ansible/dependencies.yml
ansible-playbook -i hosts /tmp/ansible/master.yml
ansible-playbook -i hosts /tmp/ansible/workers.yml