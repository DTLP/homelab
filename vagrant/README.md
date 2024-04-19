# <img align="left" width="40px" src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Kubernetes_logo_without_workmark.svg/1200px-Kubernetes_logo_without_workmark.svg.png" alt="awesome-ebitengine" title="kubernetes" /> Kubernetes cluster lab

A collection of templates and scripts to quickly roll out a kubernetes cluster in VirtualBox to study in a homelab environment.

## Prerequisites
- [Vagrant](www.vagrantup.com) by Hashicorp
- [Virtualbox](virtualbox.org) by Oracle

## How to use
To speed up the process of rolling out kube nodes, let's first build an up-to-date image of Ubuntu so we can reuse that later
1. `vagrant up common-box`
2. `vagrant package common-box --output common-box.box`
3. `vagrant box add common-box.box --name common-box`

Now we are ready to roll out the cluster
1. Inside `Vagrantfile` set the number of masters and workers you'd like to have
2. `vagrant up`
3. Wait until done
4. Get kube config from `.kube/config` and you are ready to go

To destroy the cluster
1. `./vagrant-destroy.sh`
2. Wait until done

## Credits
The original Vagrantfile and shell scripts are taken from https://github.com/arturscheiner/kuberverse and repurposed for own use.
