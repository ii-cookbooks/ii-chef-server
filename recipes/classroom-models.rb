srv_root = "/var/lib/lxc/#{node['private_chef']['lxc']['container']}/rootfs"

# We need the workstations to be able to get the Certificate
file File.join(node['fileserver']['docroot'], "chefserver.crt") do
  content "#{srv_root}/var/opt/opscode/nginx/ca/#{node['private_chef']['config']['api_fqdn']}.crt"
  provider Chef::Provider::File::Copy
  backup false
end

model_workstation_lxc='model-workstation'
execute "lxc-create -n #{model_workstation_lxc} -t training -- -a amd64 --auth-key /etc/lxc/ssh_id_rsa.pub --priv-key /etc/lxc/ssh_id_rsa -c" do
  not_if "lxc-ls | grep #{model_workstation_lxc}"
end

execute "lxc-start -d -n #{model_workstation_lxc}" do
  not_if "lxc-info --name #{model_workstation_lxc} | grep state: | grep RUNNING"
end

model_target_lxc='model-target'
execute "lxc-create -n #{model_target_lxc} -t training -- -a amd64 --auth-key /etc/lxc/ssh_id_rsa.pub --priv-key /etc/lxc/ssh_id_rsa" do
  not_if "lxc-ls | grep #{model_target_lxc}"
end

execute "lxc-start -d -n #{model_target_lxc}" do
  not_if "lxc-info --name #{model_target_lxc} | grep state: | grep RUNNING"
end
