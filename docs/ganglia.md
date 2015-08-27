Collecting Application Metrics with Ganglia
===========================================
After we have setup a Nagios server for monitoring our servers and applications
we also want to collect metrics to recognize changes in the loads over time to 
get a good indication of potential problems that may occur in the future. An
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
      config.vm.network "private_network", ip: "192.168.33.10"
    end 

Make sure that the first three parts of the IP-address of the 
*private-network* is not part of your network. We need this later on when we 
configure Ganglia.

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

### Prepare the Puppet Client Ganglia
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

Ganglia consist of several software packages where we will install not all of
them. To see what is available on Ubuntu 14.04LTS we can issue following
command

    ganglia$ sudo apt-cache search ganglia
    collectd-core - statistics collection and monitoring daemon (core system)
    ganglia-modules-linux - Ganglia extra modules for Linux (IO, filesystems, 
    multicpu)
    ganglia-monitor - cluster monitoring toolkit - node daemon
    ganglia-monitor-python - cluster monitoring toolkit - python modules
    ganglia-nagios-bridge - cluster monitoring toolkit - scalable Nagios 
    integration
    ganglia-webfrontend - cluster monitoring toolkit - web front-end
    gmetad - cluster monitoring toolkit - Ganglia Meta-Daemon
    libganglia1 - cluster monitoring toolkit - shared libraries
    libganglia1-dev - cluster monitoring toolkit - development libraries
    libgmetric4j-java - gmetric4j Ganglia metric transmission API
    libjmxetric-java - JMXetric Ganglia metric transmission API
    logster - Generate metrics from logfiles for Graphite and Ganglia

Ganglia is collecting data from servers and can display them in a Ganglia web
interface. On the Ganglia server we need to install *ganglia-webfrontend* and 
*gmetad*. *ganglia-webfrontend* will also install *gmetad*. *gmetad* collects 
the data from the server and *ganglia-webfrontend* displays the data. 
*ganlia-monitor*, respectively the containing application *gmond* is collecting
data on the servers and provides them to *gmetad*. That is every server we
want to collect data from we need to install *ganglia-monitor* on. As we want 
to also monitor our Ganglia server we have to install *ganglia-monitor* on the 
servers (clients) and on the Ganglia server (server).

### Install Ganglia on the Server
From the above information we can derive that we need Puppet modules for server
and clients. We first start with the server class and then create an install 
module.

Now create a server.pp file in `/etc/puppet/modules/ganglia/manifests/server.pp`
with following content.

    class ganglia::server {
      class { '::ganglia::server::install': } ->
      Class['ganglia::server']
    }

Create a directory `/etc/puppet/modules/ganglia/manifests/server/`

    uranus$ mkdir /etc/puppet/modules/ganglia/manifests/server
    
and create a file `install.pp` in that directory with following content

    class ganglia::server::install {
      package { ["ganglia-monitor", "ganglia-webfrontend"]:
        ensure => installed,
      }
    }

In order the `ganglia::server::install` class gets invoked we have to add a 
respective node to `/etc/puppet/manifests/site.pp`

    node 'ganglia.fritz.box' {
      include ::ganglia::server
    }

The next step is to install Ganglia which will install configuration files that
we need for further configuration. So we run Puppet from the Ganglia server.

    ganglia$ sudo puppet agent --test

After the installation we have two new directories `/etc/ganglia/` and
`/etc/ganglia-webfrontend/`. We can invoke `gmond` and `gmetad` on the command
line.

    ganglia$ gmond -V
    gmond 3.6.0 
    ganglia$ gmetad -V
    gmetad 3.6.0

The directory `/etc/ganglia-webfrontend` contains an Apache configuration file 
`/etc/ganglia-webfrontend/apache.conf` that we have to make available to Apache 
so it gets loaded when Apache starts up. For that to happen we create a link in
`/etc/apache2/conf-available/` to that file and run Apache's `a2enconf`. We 
have to start `a2enconf` whenever we change that file. Let's add 
`/etc/puppet/modules/ganglia/manifests/server/config.pp` with following content.

    class ganglia::server::config {
      file { "/etc/apache2/conf-available/ganglia.conf":
        ensure => link,
        target => "/etc/ganglia-webfrontend/apache.conf",
      }

      exec { "enable-ganglia-apache.conf":
        command => "/usr/sbin/a2enconf -q ganglia",
        require => File["/etc/apache2/conf-available/ganglia.conf"],
        notify  => Class["apache::service"],
      }
    }

Before we run Puppet we have to add `ganglia::server::config` to 
`/etc/puppet/ganglia/manifests/server.pp`.

    class ganglia::server {
      class { '::ganglia::server::install': } ->
      class { '::ganglia::server::config':  } ->
      Class['ganglia::server']
    }

A last step is to import our Apache module to our Ganglia node in 
`/etc/puppet/manifests/site.pp`. 

    node 'ganglia.fritz.box' {
      include ::ganglia::server
      include ::apache
    }

Now we run Puppet on the Ganglia server to get the files in place.

    ganglia$ sudo puppet agent --test

The Ganglia web interface should now be available at 
[localhost:4568/ganglia](http://localhost:4568/ganglia). 

### Configure Ganglia
Currently we are collecting metrics but we are using the defaults, e.g. without
a cluster name. We want to adopt the configuration to our system. For that we 
have to configure *gmond* and *gmetad*. *gmond* lives on any server where we 
want to collect data from. So this is also on the Ganglia server as we want to 
also monitor our Ganglia server. *gmetad* is responsible to collect the data 
from the monitored servers and provides the data to the Ganglia web interface.

To configure *gmond* we have to make some changes to *gmond.conf* as follows.

* Add the cluster name
* Set the UDP send channel
* Set the UDP receive channel

The configuration of *gmetad* has to be done in *gmetad.conf* as outlined below.

* Add a data source for each monitored server
* Set the username running *gmetad*

Before we move on some background information. *gmond* sends and accepts data
per default on port 8649. That is we have to configure the send and receive
port in *gmond* and in *gmetad* we have to configure in the port over which
port the data source can be connected to.

#### Configure *gmond*
Open up `/etc/ganglia/gmond.conf` and change the content as follows. The parts
to change are in different positions within the file, so a search would be 
convenient.

First we look *cluster {* and change the name to "Monitoring" as our Ganglia
server belongs to the monitoring cluster.

    cluster {
     name = "Monitoring"
    }

Next look for *udp_send_channel {* and add the *private_network* address and the
*forwarded_port* we have configured in the Vagrant file.

    udp_send_channel {
      host = 192.168.33.10
      port = 8649
    }

We have to define a port over that *gmetad* can communicate with *gmond*. this
is in *tcp_accept_channel*.

    tcp_accept_channel {
      port 8649
    }

At this point we are done with *gmond* configuration. We can do additional
configuration changes but to get monitoring running this is all we need. This 
we have to do on each server we want to collect metrics from. Now head over to 
the *gmetad* configuration.

#### Configure *gmetad*
We now work in `/etc/ganglia/gmetad.conf` where we need to make following 
changes.

Find the *data_source* section and add a data source for our Monitoring cluster.

    data_source "Monitoring" localhost:8649

The meaning of this line is that all servers that belong to the cluster
*Monitoring* can be contacted over the port 8649. Or in other words all servers
that belong to the *Monitoring* cluster have to have the port 8649 in their
*udp_send_channel* and *tcp_receive_channel* directives.

We can now check if everything works by restarting Ganglia with

    ganglia$ sudo service ganglia-monitor restart
    ganglia$ sudo service gmetad restart

and head over to the Ganglia web interface at 
[localhost:4568/ganglia](http://localhost:4568/ganglia). If it is not working
properly you can check *gmond* and *gmetad* with telnet.

To test *gmond* issue following command:

    ganglia$ telnet localhost 8649

This should respond with some XML data and then close the connection. *gmetad*
listens on port 8651 and we can check whether it is running with

    ganglia$ telnet localhost 8651

This should also repsond with some XML data and then close the connection.

If everything works we want to manage these files with Puppet. We copy these 
files to the Ganglia Puppet module in the files directory on our Puppet server.

#### Manage Ganglia Configuration Files with Puppet
First we copy *gmond.conf* and *gmetad.conf* from our Ganglia server to our
Puppet server.

    ganglia$ scp /etc/ganglia/gmond.conf pierre@uranus:gmond.conf
    ganglia$ scp /etc/ganglia/gmetad.conf pierre@uranus:gmetad.conf

Next we copy theses files to `/etc/puppet/modules/ganglia/files`. If the files 
directory doesn't exist yet we create it with

    uranus$ mkdir /etc/puppet/modules/ganglia/files

and copy *gmetad.conf* to `/etc/puppet/modules/ganglia/files/gmetad-server.conf`

    uranus$ cp ~/gmetad.conf \
                /etc/puppet/modules/ganglia/files/metad-server.conf

and we copy *gmondd.conf* to `/etc/puppet/modules/ganglia/files/gmond.conf`

    uranus$ cp ~/gmond.conf /etc/puppet/modules/ganglia/files/gmond.conf

In the next step we extend our `ganglia::server::config` class to manage the
configuration files. For that open 
`/etc/puppet/modules/ganglia/manifests/server/config.pp` 
and add following content.

    File { "/etc/ganglia/gmond.conf":
      source => "puppet:///ganglia/gmond.conf":
      owner  => "ganglia",
      group  => "ganglia",
      notice => Class["Ganglia"],
    }

    File { "/etc/ganglia/gmetad-server.conf":
      source => "puppet:///ganglia/gmetad.conf":
      owner  => "ganglia",
      group  => "ganglia",
      notice => Class["Ganglia"],
    }

Now back on our Ganglia server we call Puppet to get the files in place.

    ganglia$ sudo puppet agent --test

When we go to [localhost:4568/ganglia](http://localhost:4568/ganglia) we should
see the metrics collected from our Ganglia server within the *Monitoring*
cluster.

Next we want to collect metrics from our servers *uranus* and *mercury*.
