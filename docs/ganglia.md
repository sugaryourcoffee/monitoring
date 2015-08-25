Collecting Applicatin Metrics with Ganglia
==========================================
After we have setup a Nagios server for monitoring our servers and applications
we also want to collect metrics to realize changes in the loads over time to get
a good indication on potential problems that may occur in the future. An
application for collecting metrics is Ganglia that we want to use for that 
purpose.

The following list shows our approach to setup Ganglia collecting metrics of our
applications.

* Create a directory to host Ganglia on Virtualbox
* Create a box
* Install Ganglia on the box
* Configure Ganglia

As we will work on different machines we will prepend the prompt with the 
machine we are working on like `machine$ echo "We are on machine"` indicating
that we are currently working on `machine`. The table below shows the machines
we will use throughout the course of setting up Ganglia.

Machine    | Task
---------- | --------------------------------------------------------------
saltspring | development hosting the Ganglia server running on a VirtualBox
ganglia    | Ganglia server on VirtualBox hosted by saltspring
uranus     | Puppet server and server hosting the apptrack and secondhand staging Rails applications
mercury    | Server hosting the secondhand production application

Used Software
=============
The software packages we will use during setting up Ganglia are listed below.

* VirtualBox
* Vagrant
* Puppet
* Ganglia
* tmux

We asume that VirtualBox, Vagrant and Puppet (client/server) are already 
installed and setup. A walk through how to do this can be found at
[Monitoring an Application with Nagios](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md).

Create a Directory
==================
We need a place for our Ganglia VirtualBox and this we will create in our 
monitoring directory we have already created during our Nagios setup (see
[Create a Directory](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#create-a-directory)).

    saltspring$ mkdir ~/Monitoring/ganglia

Working Environment
===================
We will use the same environment as we used during the setup of our Nagios 
server (see [Working Environment](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#working-environment)) 
except that we won't need the Nagios pane but rather the Ganglia pane instead.

Create a VirtualBox for Ganglia
===============================
Hints on how to install VirtualBox and Vagrant can be found at
[Install VirtualBox](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#install-virtualbox) 
and [Installe Vagrant](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#install-vagrant) 
respectively.

To create a box for Ganglia we change into the Ganglia directory we have just
created and create a new box with `vagrant init` command.

    saltspring$ cd ~/Monitoring/ganglia
    saltspring$ vagrant init ubuntu/trusty64

The Vagrantfile that will be created needs to be teaked a little. Change the 
Vagrant file so it will look like this.

    
