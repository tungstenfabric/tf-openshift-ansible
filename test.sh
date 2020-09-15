ansible-playbook -i inventory/ose-install playbooks/prerequisites.yml > /var/log/bootstrap.log
ret=$?
if [ $ret -ne 0 ]; then
       echo "**"
       echo "Ansible playbooks/prerequisites.yml failed, redeploy or run the ansible, then all remaining steps in var/lib/cloud/instances/*/user-data.txt manually"
       echo "**"
       exit 0
else
       echo "Ansible completed successfuly"
fi
ansible-playbook -i inventory/ose-install playbooks/deploy_cluster.yml >> /var/log/bootstrap.log
ret=$?
if [ $ret -ne 0 ]; then
       echo "**"
       echo "Ansible deploy_cluster.yml failed, this can occur due to timeouts, rerunning"
       echo "**"
       ansible-playbook -i inventory/ose-install playbooks/deploy_cluster.yml >> /var/log/bootstrap.log
       ret2=$?
       if [ $ret2 -ne 0 ]; then
               echo "**"
               echo "Ansible deploy_cluster.yml failed a second time, redeploy or run the ansible, then all remaining steps in var/lib/cloud/instances/*/user-data.txt manually"
               echo "**"
               exit 0
       else
               echo "Ansible completed successfuly on the second run"
       fi
else
       echo "Ansible completed successfuly"
fi
ansible masters -i /root/openshift-ansible/inventory/ose-install -m shell -a "htpasswd -b /etc/origin/master/htpasswd admin contrail123"
ansible masters -i /root/openshift-ansible/inventory/ose-install -m shell -a "oc adm policy add-cluster-role-to-user cluster-admin admin"
ansible masters -i /root/openshift-ansible/inventory/ose-install -m shell -a "oc login -u admin -p contrail123"
echo "#this rule gets lost on reboot, resulting in apps failing to reach dns" >> /etc/rc.d/rc.local 
ansible -i /root/openshift-ansible/inventory/ose-install all -a "sed -i '/^-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 1936 -j ACCEPT/i -A OS_FIREWALL_ALLOW -p udp -m udp --dport 53 -j ACCEPT' /etc/sysconfig/iptables"
echo "#dnsmasq can fail on boot for some nodes" >> /etc/rc.d/rc.local  
echo "systemctl stop dnsmasq" >> /etc/rc.d/rc.local 
echo "systemctl start dnsmasq" >> /etc/rc.d/rc.local 
chmod +x /etc/rc.d/rc.local 
echo "ansible -i /root/openshift-ansible/inventory/ose-install all -a \"systemctl restart dnsmasq\"" >> /etc/rc.d/rc.local 
#selinux is  triggering a problem inside openshift apps, dns lookups fail after a reboot. openshift_docker_selinux_enabled=False does not work
ansible -i /root/openshift-ansible/inventory/ose-install all -a "setenforce permissive"
ansible -i /root/openshift-ansible/inventory/ose-install all -a "sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config"
echo "all done logs are in /var/log/bootstrap.log"
cd /tmp 
wget https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-1.4-31.tar.gz 
easy_install --script-dir /opt/aws/bin aws-cfn-bootstrap-1.4-31.tar.gz 
/opt/aws/bin/cfn-signal -e $?   --stack OpenShift-Greenfield  --resource OpenShiftInfraInstanceAZ1   --region eu-west-1
