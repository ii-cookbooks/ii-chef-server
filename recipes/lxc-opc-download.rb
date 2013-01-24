srv_root = "/var/lib/lxc/#{node['private_chef']['lxc']['container']}/rootfs"
opc_file = File.join(Chef::Config[:file_cache_path], node['private_chef']['package_file'])

if not node['private_chef']['package_temp_url']
  raise "Contact Opscode for a private_chef evaluation download url and put in private_chef.package_tmp_url"
else
  url = node['private_chef']['package_temp_url']
end

remote_file opc_file do
  source url
  checksum node['private_chef']['package_checksum']
  not_if {::File.exists? opc_file}
end

execute "cp #{opc_file} #{srv_root}/root/#{node['private_chef']['package_file']}" do
  not_if {File.exists? "#{srv_root}/root/#{node['private_chef']['package_file']}"}
end
