srv_root = "/var/lib/lxc/#{node['model_chef']['lxc']['container']}/rootfs"
# c = node['private_chef']['bootstrap']

# execute "ssh root@#{node['private_chef']['config']['api_fqdn']} -o StrictHostKeyChecking=no /usr/local/bin/create-opc -O /root/.chef -o #{c['organization']} -e #{c['email']} -f #{c['firstname']} -l #{c['lastname']} -p #{c['password']} -u #{c['username']}" do
#   not_if {File.exists? "#{srv_root}/root/.chef/#{c['username']}.pem"}
# end

config_dir =  Chef::Config[:knife][:current_dir] ? Chef::Config[:knife][:current_dir] : '/root/.chef'

if config_dir == '/root/.chef'
  etc_chef = directory config_dir do
    action :nothing
  end
  etc_chef.run_action(:create) unless ::File.exists? config_dir
end

# I'd like to make this a file resource, but the content isn't available
# until create-opc is run
[
  [ "#{srv_root}/etc/chef-server/admin.pem",
    "#{config_dir}/admin.pem"],
  [ "#{srv_root}/etc/chef-server/chef-validator.pem",
    "#{config_dir}/chef-validator.pem"]].each do |src,target|
  
  #execute "cp #{src} #{target}" #do #I'd love to execute this only when content differs
  #  creates target
  #end

  file target do
    mode 0600
    owner ::File.stat(config_dir).uid
    group ::File.stat(config_dir).gid
  end
  ruby_block "ensure #{target} is current" do
    block do
      open(target,'w') do |f|
        f.write(open(src).read)
        f.flush
        f.close
      end
    end
    not_if { ::File.file?(target) && open(src).read == open(target).read }
  end
end


# directory "/root/.chef" do
#     mode 0700
# end

# # directory "/etc/chef"
# #,'/etc/chef/solo.rb'

["#{config_dir}/knife.rb",'/root/.chef/knife.rb'].each do |chefconfig|
  template "#{chefconfig}" do
    source "osc-knife.rb.erb"
    owner ::File.stat(config_dir).uid
    group ::File.stat(config_dir).gid
    mode 00644
    variables({
        :chef_server => node['model_chef']['lxc']['container']
      })
  end
end


# [
#   [ "#{srv_root}/root/.chef/#{c['username']}.pem",
#     "/root/.chef/#{c['username']}.pem"],
#   [ "#{srv_root}/root/.chef/#{c['organization']}-validation.pem",
#     "/root/.chef/#{c['organization']}-validation.pem"]].each do |src,target|
  
#   file target do
#     mode 0600
#   end
#   ruby_block "ensure root #{target} pem is current" do
#     block do
#       open(target,'w') do |f|
#         f.write(open(src).read)
#         f.flush
#         f.close
#       end
#     end
#     not_if { ::File.file?(target) && open(src).read == open(target).read }
#   end
#   # a more elegant way to do this is welcome
#   # The old way doesn't update the files
#   # execute "cp #{src} #{target}" do
#   #   creates target
#   # end
  
#   # file target do
#   #   mode 0600
#   # end
# end
