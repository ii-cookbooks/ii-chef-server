chef_container = node['model_chef']['lxc']['container']
srv_root = "/var/lib/lxc/#{chef_container}/rootfs"

execute "lxc-create -n #{chef_container} -t training -- -a amd64" do
  creates srv_root
  #not_if "lxc-ls | grep #{chef_container}"
end

execute "lxc-start -d -n #{chef_container}" do
  not_if "lxc-info --name #{chef_container} | grep state: | grep RUNNING"
end

# these items don't work well within containers
%w{10-console-messages.conf 10-kernel-hardening.conf 10-ptrace.conf}.each do |sysctl_file|
  file "#{srv_root}/etc/sysctl.d/#{sysctl_file}" do
    action :delete
    only_if { ::File.exists? "#{srv_root}/etc/sysctl.d/#{sysctl_file}" }
  end
end

