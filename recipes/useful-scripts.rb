srv_root = "/var/lib/lxc/#{node['private_chef']['lxc']['container']}/rootfs"

template "/usr/local/bin/associate_orgs" do
  source "associate_orgs.erg"
  mode 0755
end
cookbook_file "/usr/local/bin/list_orgs" do
  mode 0755
end
cookbook_file "/usr/local/bin/delete_org" do
  mode 0755
end
cookbook_file "#{srv_root}/usr/local/bin/create-opc" do
  mode "0755"
end

template "/usr/local/bin/create-training-containers" do
  source "create-training-containers.erb"
  mode "0755"
end
