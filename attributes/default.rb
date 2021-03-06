# -*- coding: utf-8 -*-
default['private_chef']['config']['topology'] = 'standalone'

default['private_chef']['config']['api_fqdn'] = case node['resolver']
                                                when nil # we aren't using the resolver cookbook
                                                  'chef.localdomain'
                                                else # we are using the resolver cookbook
                                                  "chef.#{node['resolver']['search']}"
                                                end
default['private_chef']['advconfig']["opscode_org_creator['max_workers']"] = '10'
default['private_chef']['advconfig']["opscode_org_creator['ready_org_depth']"] = '50'
default['private_chef']['advconfig']["opscode_webui['worker_processes']"] = '8'
default['private_chef']['advconfig']["opscode_account['worker_processes']"] = '8'
default['private_chef']['advconfig']["opscode_solr['commit_interval']"] = 10 * 1000 # in milliseconds


# this could be migrated to another area
default['private_chef']['bootstrap']['email'] = 'ii@instantinfrastructure.org'
default['private_chef']['bootstrap']['username'] = 'opscode'
default['private_chef']['bootstrap']['password'] = 'opscode123'
default['private_chef']['bootstrap']['firstname'] = 'Instant'
default['private_chef']['bootstrap']['lastname'] = 'Infrastructure'
default['private_chef']['bootstrap']['organization'] = 'training'

default['private_chef']['lxc']['container'] = 'chef'

default['model_chef']['lxc']['container'] = 'model-chef'

default['model_chef']['config']['api_fqdn'] = case node['resolver']
                                                when nil # we aren't using the resolver cookbook
                                                  'model-chef.localdomain'
                                                else # we are using the resolver cookbook
                                                  "model-chef.#{node['resolver']['search']}"
                                                end
