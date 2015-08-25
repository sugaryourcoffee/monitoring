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
* Git
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

The Vagrantfile that will be created needs to be tweaked a little. Change the 
Vagrant file so it will look like this.

    VAGRANTFILE_API_VERSION = "2"

    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      config.vm.box = "ubuntu/trusty64"
      config.vm.hostname = "ganglia"
      config.vm.network "forwarded_port", guest: 80, host: 4568
    end 

Now run `vagrant up` to create the box.

    saltspring$ vagrant up

We can now SSH to the box with

    saltsprint$ vagrant ssh

Next we install Ganglia on the box using Puppet.

Manage Ganglia with Puppet
==========================
We will install and manage Ganglia with Puppet. For that we need to install
Puppet client on our freshly created Ganglia box and Puppet master on our
Puppet server. How that can be done can be found in a little more detailed 
version at [Install Puppet](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#install-puppet). To install Puppet client on your 
Ganglia server call

    ganglia$ sudo apt-get install puppet

To prove that the installation went well we can ask for the version of Puppet

    ganglia$ puppet --version
    3.4.3

Create a Ganglia Puppet Module
------------------------------
Puppet server is already running, so we can just head into creating a Puppet 
module for Ganglia. First we add a node to `/etc/puppet/manifests/site.pp` on 
our Puppet server *uranus*.

    node 'ganglia.firtz.box' {
    } 

### Prepare the Puppet Client ganlia
In order to provision our Ganglia server we have to request a certificate from
our Puppet server. To do this we assign the IP address of our Puppet server
*uranus* to the name *puppet* in `/etc/hosts`. Add following line into
`/etc/hosts` on your Ganglia server

    ganglia$ sudo vi /etc/hosts
    192.168.178.66 puppet

No request the certificate from your Puppet server with

    ganglia$ sudo puppet agent --test
    vagrant@ganglia:~$ sudo puppet agent --test
    Info: Creating a new SSL key for ganglia.fritz.box
    Info: Caching certificate for ca
    Info: csr_attributes file loading from /etc/puppet/csr_attributes.yaml
    Info: Creating a new SSL certificate request for ganglia.fritz.box
    Info: Certificate Request fingerprint (SHA256): 
    C8:14:9A:2D:D6:5A:75:44:48:82:EA
    :D2:09:19:47:80:27:2A:C5:21:A4:D6:43:89:47:49:2D:1F:AC:94:F4:04
    Info: Caching certificate for ca
    Exiting; no certificate found and waitforcert is disabled 

The last line indicates that a request is waiting for certification. To create
the certificate we head over to our Puppet server and call

    uranus$ sudo puppet cert --list
      "ganglia.fritz.box"  (SHA256) C8:14:9A:2D:D6:5A:75:44:48:82:EA:D2:09:19:47:80:27:2A:C5:21:A4:D6:43:89:47:49:2D:1F:AC:94:F4:04 
      
to look for waiting certificates. To certify the request we issue

    uranus$ sudo puppet cert sign ganglia.fritz.box

Back on our Ganglia server issuing the command should indicate that our 
certification request has been aproved.

    ganglia$ sudo puppet agent --test
    Info: Caching certificate for ganglia.fritz.box
    Info: Caching certificate_revocation_list for ca
    Info: Caching certificate for ganglia.fritz.box
    Notice: Skipping run of Puppet configuration client; administratively 
    disabled (Reason: 'Disabled by default on new installations');
    Use 'puppet agent --enable' to re-enable.

The last line says to run

    ganglia$ puppet agent --enable

Then another run of `sudo puppet agent --test` will show an error that the 
catalog could not be found. But that is o.k. for now as we don't have a module
yet.

    ganglia$ puppet agent --test
    Info: Retrieving plugin
    Notice: /File[/var/lib/puppet/lib]/mode: mode changed '0755' to '0775'
    Error: Could not retrieve catalog from remote server: Error 400 on SERVER: 
    Could not find default node or by name with 'ganglia.fritz.box, 
    ganglia.fritz, ganglia' on node ganglia.fritz.box
    Warning: Not using cache on failed catalog
    Error: Could not retrieve catalog; skipping run

### Create the Puppet Module
Now we create a Puppet module for Ganglia. On the Puppet server *uranus* we
change to `/etc/puppet/modules` and create a new Puppet module that we name
ganglia.

    uranus$ cd /etc/puppet/modules
    uranus$ puppet module generate sugaryourcoffee-ganglia
    uranus$ mv sugaryourcoffee-ganglia ganglia

Now is a good time to commit our new module to Git. How this is done can be
found at [Install Nagios on the box](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#install-nagios-on-the-box).


