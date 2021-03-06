require 'resolv'
require 'socket'
require 'timeout'
require 'net/ssh'

include_recipe 'ii-chef-server::knife-acl' # a gem I found useful
include_recipe 'ii-chef-server::lxc-create' # bring the container up so we can copy (and eventually ssh)
include_recipe 'ii-chef-server::lxc-ssh-setup' # create key and copy it to the chef lxc
include_recipe 'ii-chef-server::lxc-opc-download' # execute cp..... fixme
include_recipe 'ii-chef-server::lxc-install-opc' # waits for container to have ssh
include_recipe 'ii-chef-server::useful-scripts' #used in lxc-knife
include_recipe 'ii-chef-server::lxc-customize-webui' # we customize the webui slightly
include_recipe 'ii-chef-server::lxc-setup-knife' # create training org and grab pems

include_recipe 'ii-chef-server::upload-recipes-roles'

# chef-server is now ready to create the model-workstation
include_recipe 'ii-chef-server::classroom-models'
