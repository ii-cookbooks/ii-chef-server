# This needs to be modified to utilize copying from knife ec2 bootstrap
# or a current server

execute "knife cookbook upload -c /root/chef-repo/.chef/knife.rb -a" do # ; touch /tmp/cookbooks_uploaded" do
  # cwd Chef::Config[:knife][:current_dir]
  #... let's see if we can run from anywhere now
  # creates '/tmp/cookbooks_uploaded'
  # alternatively, we could look at the uploaded cookbooks... but I think it's too slow
  # not_if "cd #{::File.dirname config_dir} ; knife cookbook show knife-workstation"
  #not_if { ENV['NOUPLOAD'] }
end


execute "knife role from file -c /root/chef-repo/.chef/knife.rb #{Chef::Config[:knife][:current_dir]}/../roles/*" do # ; touch /tmp/roles_uploaded" do
  #creates '/tmp/roles_uploaded'
  #not_if { ENV['NOUPLOAD'] }
end

