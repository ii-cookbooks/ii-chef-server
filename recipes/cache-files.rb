opc_file = File.join(Chef::Config[:file_cache_path], node['private_chef']['package_file'])
# if node['private_chef']['package_temp_url']
#   remote_file opc_file do
#     source node['private_chef']['package_temp_url']
#     checksum node['private_chef']['package_checksum']
#     not_if {::File.exists? opc_file}
#   end
# end

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
  not_if {::File.exists? chef_package_file} # the file is large, checksum takes a minute
  retries 5
  retry_delay 10
end

