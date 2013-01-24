srv_root = "/var/lib/lxc/#{node['private_chef']['lxc']['container']}/rootfs"

execute "restart webui via ssh" do
  command "ssh #{node['private_chef']['config']['api_fqdn']} private-chef-ctl opscode-webui restart"
  action :nothing
end

cookbook_file "#{srv_root}/opt/opscode/embedded/service/opscode-webui/app/views/status/index.html.haml"
cookbook_file "#{srv_root}/opt/opscode/embedded/service/opscode-webui/app/views/layouts/application.html.haml"
cookbook_file "#{srv_root}/opt/opscode/embedded/service/opscode-webui/app/controllers/organizations_controller.rb" do
  notifies :run, "execute[restart webui via ssh]"
end
