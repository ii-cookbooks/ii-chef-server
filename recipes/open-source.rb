require 'resolv'
require 'socket'
require 'timeout'
require 'net/ssh'


include_recipe 'ii-chef-server::lxc-create' # bring the container up so we can copy (and eventually ssh)
include_recipe 'ii-chef-server::lxc-ssh-setup' # create key and copy it to the chef lxc
include_recipe 'ii-chef-server::lxc-osc-download' # execute cp..... fixme
include_recipe 'ii-chef-server::lxc-install-osc' # waits for container to have ssh
include_recipe 'ii-chef-server::lxc-setup-osc-knife' # create admin user

include_recipe 'ii-chef-server::upload-recipes-roles'

# chef-server is now ready to create the model-workstation
include_recipe 'ii-chef-server::classroom-models'
