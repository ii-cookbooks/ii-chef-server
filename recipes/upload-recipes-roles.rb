# This needs to be modified to utilize copying from knife ec2 bootstrap
# or a current server

%w{ cookbooks roles data_bags }.each do |component|
  execute "knife upload #{component}" do
    cwd File.join(Chef::Config[:knife][:current_dir],'..')
  end
end
