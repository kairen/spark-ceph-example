# Quick Start Rados
Quick boot a Ceph cluster and compile rados-java jar. Major help to deploy a dev environment use to learning librados(C) API.

Easy enough! install [vagrant](http://www.vagrantup.com/downloads.html) and [virtualbox](https://www.virtualbox.org/wiki/Linux_Downloads):
```sh
$ wget https://releases.hashicorp.com/vagrant/1.9.2/vagrant_1.9.2_x86_64.deb
$ wget http://download.virtualbox.org/virtualbox/5.1.18/virtualbox-5.1_5.1.18-114002~Ubuntu~xenial_amd64.deb
$ sudo dpkg -i vagrant_1.9.2_x86_64.deb
$ sudo dpkg -i virtualbox-5.1_5.1.18-114002~Ubuntu~xenial_amd64.deb
```

Create a vm using vagrant with virtualbox. When the operation is completed, type `vagrant ssh <name>` into vm:
```sh
$ vagrant up
$ vagrant ssh ceph-aio
```

Finally, check the ceph cluster and run java example:
```sh
$ sudo ceph -s
$ cd examples
$ javac CephExample.java && sudo java CephExample
Put kyle-say
Put my-object

# use rados command check object
$ sudo rados -p data get my-object -
This is my object.
```
