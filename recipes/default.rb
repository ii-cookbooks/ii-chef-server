require 'resolv'
require 'socket'
require 'timeout'
require 'net/ssh'

include_recipe 'private-chef::knife-acl' # a gem I found useful
include_recipe 'private-chef::lxc-create' # bring the container up so we can copy (and eventually ssh)
include_recipe 'private-chef::lxc-ssh-setup' # create key and copy it to the chef lxc
include_recipe 'private-chef::lxc-opc-download' # execute cp..... fixme
include_recipe 'private-chef::lxc-install-opc' # waits for container to have ssh
include_recipe 'private-chef::useful-scripts' #used in lxc-knife
include_recipe 'private-chef::lxc-customize-webui' # we customize the webui slightly
include_recipe 'private-chef::lxc-setup-knife' # create training org and grab pems

include_recipe 'private-chef::upload-recipes-roles'

# chef-server is now ready to create the model-workstation
include_recipe 'private-chef::classroom-models'
