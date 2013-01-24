chef_container = node['private_chef']['lxc']['container']
srv_root = "/var/lib/lxc/#{node['private_chef']['lxc']['container']}/rootfs"

ruby_block "wait for #{node['private_chef']['config']['api_fqdn']} dhcp/dns/sshd" do
  block do
    Timeout::timeout(60) do
      while true do
        begin
          Chef::Log.info "trying to ssh to #{node['private_chef']['config']['api_fqdn']}"
          # we need to check dns first... dnsmasq can lag out, and I want a different error
          addr=Resolv::DNS.new.getaddress("#{node['private_chef']['config']['api_fqdn']}").to_s
          # going back and forth at to which is a better idea... actual ssh vs tcp
          # Net::SSH.start(addr, 'root')
          TCPSocket.new addr, 22
          break
        rescue Net::SSH::AuthenticationFailed => e
          Chef::Log.info "unable to authenticate #{node['private_chef']['config']['api_fqdn']}"
          sleep 5
        rescue Resolv::ResolvError => e
          Chef::Log.info "unable to resolve #{node['private_chef']['config']['api_fqdn']}"
          sleep 5
        rescue Errno::EHOSTUNREACH => e
          Chef::Log.info "unable to reach #{node['private_chef']['config']['api_fqdn']}"
          sleep 5
        # rescue Exception => e
        #   puts e
        #   sleep 5
        end
        # Something that should be interrupted if it takes too much time...
      end
    end
  end
  not_if do
    begin
      addr=Resolv::DNS.new.getaddress("#{node['private_chef']['config']['api_fqdn']}").to_s
      # Net::SSH.start(addr, 'root')
      TCPSocket.new addr, 22
    rescue
      false
    end
  end
end

execute "install private chef" do
  command "ssh root@#{node['private_chef']['config']['api_fqdn']} dpkg -i /root/#{node['private_chef']['package_file']}"
  not_if {File.exists? "#{srv_root}/opt/opscode/bin"}
end

directory "#{srv_root}/etc/opscode" do
  owner "root"
  group "root"
  mode 00755
end

template "#{srv_root}/etc/opscode/private-chef.rb" do
  source "private-chef.rb.erb"
  cookbook 'private-chef'
  owner "root"
  owner "root"
  mode 00644
  notifies :run, "execute[private-chef-ctl reconfigure via ssh]", :immediately
end

execute "private-chef-ctl reconfigure via ssh" do
  command "ssh root@#{node['private_chef']['config']['api_fqdn']} private-chef-ctl reconfigure"
  action :nothing
  # this seems to fail a few times
end


