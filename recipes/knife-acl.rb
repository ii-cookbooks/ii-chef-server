# We just modified the status page to have a link to the vnc
# chef_gem "knife-acl" doesn't seem to work
knife_acl_gem_dir = ::File.join(Chef::Config.file_cache_path, 'knife-acl-gem')
knife_acl_gem = "#{knife_acl_gem_dir}/pkg/knife-acl-0.0.10.gem"
git knife_acl_gem_dir do
  repository 'git://github.com/seth/knife-acl.git'
  not_if { ::File.exists? knife_acl_gem_dir }
end

execute 'build knife-acl gem' do
  command "rake gem"
  creates knife_acl_gem
  cwd knife_acl_gem_dir
end

# useful for listing users within an org
gem_package 'knife-acl' do
  gem_binary '/opt/chef/embedded/bin/gem'
  options '--no-ri --no-rdoc'
  source knife_acl_gem
end

