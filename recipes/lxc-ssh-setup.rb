
execute "ssh-keygen  -q -f /root/.ssh/id_rsa -P ''" do
  not_if {File.exists? "/root/.ssh/id_rsa.pub"}
end

file "/root/.ssh/config" do
  content <<-EOF
  StrictHostKeyChecking false
  IdentityFile ~/.ssh/id_rsa
  IdentityFile /etc/lxc/ssh_id_rsa
  EOF
  not_if {::File.exists? "/root/.ssh/config"}
end

srv_root = "/var/lib/lxc/#{node['model_chef']['lxc']['container']}/rootfs"
directory "#{srv_root}/root/.ssh" do
  mode '0700'
end
execute "cp /root/.ssh/id_rsa.pub #{srv_root}/root/.ssh/authorized_keys" do
  not_if {File.exists? "#{srv_root}/root/.ssh/authorized_keys"}
end
