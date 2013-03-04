# This needs to be modified to utilize copying from knife ec2 bootstrap
# or a current server

%w{ cookbooks roles data_bags }.each do |component|
  idfile = "#{Chef::Config[:file_cache_path]}/knife-#{component}-uploaded"
  execute "knife upload #{component}" do
    cwd File.join(Chef::Config[:knife][:current_dir],'..')
    creates idfile
  end
  file idfile
end
