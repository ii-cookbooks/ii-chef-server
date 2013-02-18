srv_root = "/var/lib/lxc/#{node['model_chef']['lxc']['container']}/rootfs"

# cc = search('chef',"*:*")
# node.normal['chef_client']['version']=cc.map{|v| v['version']}.flatten.uniq.sort.last

cs = search('chef_server',"*:*")
node.normal['chef_server']['version']=cs.map{|v| v['version']}.flatten.uniq.sort.last

chef_package = search('chef_server',
  "os_#{node.platform}:#{node.platform_version} AND version:#{node['chef_server']['version']}"
  ).first
node.normal['chef_server']['package'] = chef_package

chef_package_file = File.join(Chef::Config[:file_cache_path], chef_package['filename'])

remote_file chef_package_file do
  source chef_package['source']
  checksum chef_package['checksum']
  not_if {::File.exists? chef_package_file}
  retries 5
  retry_delay 10
end

execute "cp #{chef_package_file} #{srv_root}/root/#{chef_package['filename']}" do
  not_if {File.exists? "#{srv_root}/root/#{chef_package['filename']}"}
end
