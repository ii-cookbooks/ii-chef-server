Description
===========

Requirements
============

Attributes
==========

Usage
=====

Issues
======

FATAL: Mixlib::ShellOut::ShellCommandFailed: execute[lxc-create -n model-workstation -t training -- -a amd64 --auth-key /etc/lxc/ssh_id_rsa.pub --priv-key /etc/lxc/ssh_id_rsa -c] (ii-chef-server::classroom-models line 11) had an error: Mixlib::ShellOut::ShellCommandFailed: Expected process to exit with [0], but received '1'

If you get 404s' you may need to blow away your template cache

rm -rf /var/cache/lxc/precise/rootfs-amd64
