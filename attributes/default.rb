# -*- coding: utf-8 -*-
default['private_chef']['config']['topology'] = 'standalone'
default['private_chef']['config']['api_fqdn'] = "chef.#{node['resolver']['search']}"
default['private_chef']['advconfig']["opscode_org_creator['max_workers']"] = '10'
default['private_chef']['advconfig']["opscode_org_creator['ready_org_depth']"] = '50'
default['private_chef']['advconfig']["opscode_webui['worker_processes']"] = '8'
default['private_chef']['advconfig']["opscode_account['worker_processes']"] = '8'
default['private_chef']['advconfig']["opscode_solr['commit_interval']"] = 10 * 1000 # in milliseconds


# this could be migrated to another area
default['private_chef']['bootstrap']['email'] = 'ii@instantinfrastructure.org'
default['private_chef']['bootstrap']['username'] = 'ii'
default['private_chef']['bootstrap']['password'] = 'ii123'
default['private_chef']['bootstrap']['firstname'] = 'Instant'
default['private_chef']['bootstrap']['lastname'] = 'Infrastructure'
default['private_chef']['bootstrap']['organization'] = 'training'

default['private_chef']['lxc']['container'] = 'chef'

