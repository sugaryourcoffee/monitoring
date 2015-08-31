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
uranus     | Puppet server and server hosting the apptrack and secondhand 
           | staging Rails applications
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

    node 'ganglia.fritz.box' {
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
*ganglia-monitor*, respectively the containing application *gmond* is collecting
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
want to run `a2enconf` only if the file is not in `/etc/apache2/conf-enabled/`.
This is checked with the `unless` parameter. Let's add 
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
        unless  => "/usr/bin/test -f /etc/apache2/conf-enabled/ganglia.conf",
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
* Set the TCP accept channel

The configuration of *gmetad* has to be done in *gmetad.conf* as outlined below.

* Add a data source for each cluster

Before we move on some background information about the connection between
*gmond* and *gmetad*. *gmond* sends and accepts, over the UDP send and receive
channel, data per default on port 8649. That is we have to configure the send 
and receive port in *gmond*, which is port 8649. In *gmetad* we have to 
configure over which port the data source can be connected to, this is also 
8649. The TCP accept channel is where *gmond* reports the cluster state to 
*gmetad*.

#### Configure *gmond*
Open up `/etc/ganglia/gmond.conf` and change the content as follows. The parts
to change are in different positions within the file, so a search would be 
convenient.

First we look up *cluster {* and change the name to "Monitoring" as our Ganglia
server belongs to the monitoring cluster.

    cluster {
     name = "Monitoring"
    }

Next look for *udp_send_channel {* and add the following content which might be
already in place. We are using *multicast* for the communication within the
cluster.

    udp_send_channel {
      mcast_join = 239.2.11.71
      port = 8649
      ttl = 1
    }

We also have to configure how to receive data from the cluster this server is
in. Search for *udp_recv_channel {* and add this content.

    udp_recv_channel {
      mcast_join = 239.2.11.71
      port = 8649
      bind = 239.2.11.71
    }

We have to define a port over that *gmetad* can communicate with *gmond*. this
is in *tcp_accept_channel*.

    tcp_accept_channel {
      port 8649
    }

Note: All servers that belong to the same cluster have to use the same 
configuration as show above. That is the multicast IP address and the port.

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
*udp_send_channel*, *udp_recv_channel* and *tcp_accept_channel* directives.

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

You can also run *gmond* and *gmetad* in debug mode like so

    ganglia$ gmond -d 5 -c /etc/ganglia/gmond.conf

or

    ganglia$ gmetad -d 5 -c /etc/ganglia/gmond.conf

where `-d 5` means *run gmond in debug level 5* and `-c` is followed by the 
configuration file.

To check whether the multicast address `239.2.11.71` is considered as a group
issue

    ganglia$ netstat -g
    Interface      RefCnt Group
    -------------- ------ -----------
    eth0           1      239.2.11.71

If not check whether multicast is enabled on your network card by issuing
`ifconfig` and see whether your interface shows something like 
`UP BROADCAST RUNNING MULTICAST MTU:1500 Metric:1`

If everything works we want to manage these files with Puppet. We copy these 
files to the Ganglia Puppet module in the files directory on our Puppet server.

#### Manage Ganglia Configuration Files with Puppet
We have to manage the Ganglia server and the servers (clients) we want to 
monitor based on gathered metrics. We first look at how to manage the Ganglia
server and in the next section we look at the clients, that is servers we 
gather metrics from.

##### Configure the Ganglia Server
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
      source  => "puppet:///modules/ganglia/gmond.conf":
      owner   => "root",
      group   => "root",
      mode    => 644,
      require => Class["ganglia::server::install"],
      notify  => Class["ganglia::server::service"],
    }

    File { "/etc/ganglia/gmetad.conf":
      source  => "puppet:///modules/ganglia/gmetad.conf":
      owner   => "root",
      group   => "root",
      mode    => 644,
      require => Class["ganglia::server::install"],
      notify  => Class["ganglia::server::service"],
    }

The *service* class doesn't exist yet so we have to create it and call it in
our *server.pp* file. Open a new file `etc/puppet/ganglia/manifests/server/service.pp` and add the service class definition.

    class ganglia::server::service {
      service { "ganglia-monitor":
        hasrestart => true,
      }

      service { "gmetad":
        hasrestart => true,
      }
    }

Now open up `/etc/puppet/modules/ganglia/manifests/server.pp` and add

    class { '::ganglia::server::service': } ->

Now back on our Ganglia server we call Puppet to get the files in place.

    ganglia$ sudo puppet agent --test

When we go to [localhost:4568/ganglia](http://localhost:4568/ganglia) we should
see the metrics collected from our Ganglia server within the *Monitoring*
cluster.

Next we want to collect metrics from our servers *uranus* and *mercury*.

##### Configure the Monitored Clients
To configure the monitored servers is rather easy. We have to decide to which
cluster a server belongs to and add this cluster to *gemeta.conf* on the 
Ganglia server. On the client we have to install *gmond* and configure 
*gmond.conf*.

On the Puppet server *uranus* we create for each cluster a *gmond-CLUSTER.conf*
file where *CLUSTER* has to be replaced by the cluster name. At the moment we 
have the cluster *Monitoring*. An overview of the clusters we want to maintain 
is show in the following table.

Cluster        | Server  | Port | Description                                  
-------------- | ------- | -----| -------------------------------------------- 
Monitoring     | ganglia | 8649 | Hosting the Ganglia server                   
Monitoring     | nagios  | 8649 | Hosting the Nagios server                    
Staging        | uranus  | 8653 | Hosting Secondhand Staging and non critical
               |         |      | applications
Production     | mercury | 8654 | Hosting the Secondhand Production application
Infrastructure | earth   | 8655 | NAS server  

Note that each cluster has to have its own unique port assigned. If you have the
same port to two different clusters assigned the cluster will not be shown 
correctly. Also don't use ports 8651 and 8652 as they are ports *gmetad* uses
for other communication.

Next we copy `/etc/puppet/ganglia/files/gmond.conf` in the same directory to
`gmond-monitoring`, `gmond-production`, `gmond-staging` and 
`gmond-infrastructure`.     

    uranus$ cd /etc/puppet/modules/ganglia/files
    uranus$ for file in monitoring production staging infrastructure; do \
    > cp gmond.conf "gmond-$file.conf"; done

Change in each file the name of the *cluster* directive to the cluster name 
indicated by the filename and the *udp_send_channel*, *udp_recv_channel* and
the *tcp_accept_channel* with the port we have chosen in the table above.

    uranus$ vi /etc/puppet/modules/ganglia/files/gmond-monitoring.conf
    cluster {
      name = "Monitoring"
    }

    udp_send_channel {
      mcast_join = 239.2.11.71
      port = 8649
      ttl = 1
    }

    udp_recv_channel {
      mcast_join = 239.2.11.71
      port = 8649
      bind = 239.2.11.71
    }

    uranus$ vi /etc/puppet/modules/ganglia/files/gmond-production.conf
    cluster {
      name = "Production"
    }

    udp_send_channel {
      mcast_join = 239.2.11.71
      port = 8654
      ttl = 1
    }

    udp_recv_channel {
      mcast_join = 239.2.11.71
      port = 8654
      bind = 239.2.11.71
    }

    uranus$ vi /etc/puppet/modules/ganglia/files/gmond-staging.conf
    cluster {
      name = "Staging"
    }

    udp_send_channel {
      mcast_join = 239.2.11.71
      port = 8653
      ttl = 1
    }

    udp_recv_channel {
      mcast_join = 239.2.11.71
      port = 8653
      bind = 239.2.11.71
    }

    uranus$ vi /etc/puppet/modules/ganglia/files/gmond-infrastructure.conf
    cluster {
      name = "Infrastructure"
    }

    udp_send_channel {
      mcast_join = 239.2.11.71
      port = 8654
      ttl = 1
    }

    udp_recv_channel {
      mcast_join = 239.2.11.71
      port = 8654
      bind = 239.2.11.71
    }

As our Ganglia server is running as a virtual machine on a host computer we 
cannot access the Ganglia server directly. To make the Ganglia server publicly 
available we have to configure the Ganglia server with a public network.

Add following directive to the Vagrantfile.

    vm.config.network "public_network"

You can also specify an IP address with

    vm.config.network "public_network", ip: 129.168.178.120

But you have to make sure that the IP address is not taken by another machine.

To take effect we have to reload the Vagrantfile with

    saltspring$ vagrant reload

You will be prompted which network to bridge, e.g.

    1) wlan0
    2) eth2

Enter the number (1 or 2) depending on how your your machine is connected to
the network.

The next steps are for each cluster we create following files.

* CLUSTER.pp in `/etc/puppet/modules/ganglia/manifests` where CLUSTER will be
  monitoring, production, staging and infrastructure.
* In the directory `/etc/puppet/modules/ganglia/manifests/client/` we create
  `install.pp`, `service.pp` and for each cluster a `config-CLUSTER.pp`, where
  *CLUSTER* has to be replaced with *monitoring*, *production*, *staging* and
  *infrastructure*.
* For each server we have to add a node to `/etc/puppet/manifests/site.pp` 
* On the Ganglia server we have to provide the information about new clients in
  *gmetad.conf*.

First we create the cluster files in `/etc/puppet/modules/ganglia/manifests/`

File `/etc/puppet/modules/ganglia/manifests/monitoring.pp`

    class ganglia::monitoring {
      class { '::ganglia::client::install':    } ->
      class { '::ganglia::client::config_monitoring': } ->
      class { '::ganglia::client::service':    } ->
      Class['ganglia::monitoring']
    }

File `/etc/puppet/modules/ganglia/manifests/production.pp`

    class ganglia::production {
      class { '::ganglia::client::install':    } ->
      class { '::ganglia::client::config_production': } ->
      class { '::ganglia::client::service':    } ->
      Class['ganglia::production']
    }

File `/etc/puppet/modules/ganglia/manifests/staging.pp`

    class ganglia::staging {
      class { '::ganglia::client::install':    } ->
      class { '::ganglia::client::config_staging': } ->
      class { '::ganglia::client::service':    } ->
      Class['ganglia::staging']
    }

File `/etc/puppet/modules/ganglia/manifests/infrastructure.pp`

    class ganglia::infrastructure {
      class { '::ganglia::client::install':    } ->
      class { '::ganglia::client::config_infrastructure': } ->
      class { '::ganglia::client::service':    } ->
      Class['ganglia::infrastructure']
    }

Now we create the files *install.pp*, *service.pp*  and *config-CLUSTER.pp* in 
`/etc/puppet/modules/ganglia/manifests/client` for that we have to first create
the `client` directory

    uranus$ mkdir /etc/puppet/modules/ganglia/manifests/client/

Now we can create the files as follows.

File `/etc/puppet/modules/manifests/client/install.pp`

    class ganglia::client::install {
      package { "ganglia-monitor":
        ensure => installed,
      }
    }

File `/etc/puppet/modules/manifests/client/service.pp`

    class ganglia::client:service {
      service { "ganglia-monitor":
        hasrestart => true,
      }
    }

File `/etc/puppet/modules/manifests/client/config-monitoring.pp

    class ganglia::client::config_monitoring {
      file { "/etc/ganglia/gmond.conf":
        source => "puppet:///modules/ganglia/gmond-monitoring.conf"
        owner  => "root",
        group  => "root",
        mode   => 644,
        require => Class["ganglia::client::install"],
        notify  => Class["ganglia::client::service"],
      }
    }

File `/etc/puppet/modules/manifests/client/config-production.pp

    class ganglia::client::config_production {
      file { "/etc/ganglia/gmond.conf":
        source => "puppet:///modules/ganglia/gmond-production.conf"
        owner  => "root",
        group  => "root",
        mode   => 644,
        require => Class["ganglia::client::install"],
        notify  => Class["ganglia::client::service"],
      }
    }

File `/etc/puppet/modules/manifests/client/config-staging.pp

    class ganglia::client::config_staging {
      file { "/etc/ganglia/gmond.conf":
        source => "puppet:///modules/ganglia/gmond-staging.conf"
        owner  => "root",
        group  => "root",
        mode   => 644,
        require => Class["ganglia::client::install"],
        notify  => Class["ganglia::client::service"],
      }
    }

File `/etc/puppet/modules/manifests/client/config-infrastructure.pp

    class ganglia::client::config_infrastructure {
      file { "/etc/ganglia/gmond.conf":
        source => "puppet:///modules/ganglia/gmond-infrastructure.conf"
        owner  => "root",
        group  => "root",
        mode   => 644,
        require => Class["ganglia::client::install"],
        notify  => Class["ganglia::client::service"],
      }
    }

And finally we add the server nodes to `/etc/puppet/manifests/site.pp`

    node 'uranus.fritz.box' {
      include "ganglia::staging"
    }

    node 'nagios.fritz.box' {
      include "ganglia::monitoring"
    }

    node 'mercury.fritz.box' {
      include "ganglia::production"
    }

    node 'earth.fritz.box' {
      include "ganglia::infrastructure"
    }

Now we run puppet on each server. If is asumed that each of the servers has
installed and configured Puppet client. How to do that can be looked up in
[Install Puppet](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#install-puppet)
and in [Configure Puppet Client](https://github.com/sugaryourcoffee/monitoring/blob/master/docs/monitoring.md#prepare-the-client)

    mercury$ sudo puppet agent --test
    earth$ sudo puppet agent --test
    nagios$ sudo puppet agent --test

As the *uranus* server happens to be also our Puppet server we call Puppet with
`puppet apply` locally.

    uranus$ sudo puppet apply --verbose /etc/puppet/manifests/site.pp

Now we let the servers collect data and in the meanwhile we have to inform our
Ganglia server about the new clusters. We add the new clusters as data resources
to `/etc/puppet/modules/ganglia/files/gmetad.conf`.

    data_source monitoring localhost:8649 nagios.fritz.box:8649
    data_source production mercury.fritz.box:8652
    data_source staging uranus.fritz.box:8653
    data_source infrastructure earth.fritz.box:8654

If we go to [localhost:4568/ganglia](http://localhost:4568/ganglia) we should
see 4 clusters continuousy showing metrics.

Configuration Files
===================
The following table shows the different configuration files and where these are
located.

File        | Path                     | Description
----------- | ------------------------ | -----------
gmetad.conf | /etc/ganglia/            | Collecting data from servers by talking to gmond. Has to be installed on the Ganglia server
gmond.conf  | /etc/ganglia/            | Collecting metrics from servers and sending them to gmetad. Has to be installed on the Ganlia server and clients
apache.conf | /etc/ganglia-webfrontend | Apache configuration file for Ganglia's web interface. Has to be linked to /etc/apache2/conf-enabled/

Trouble Shooting
================
Even though setting up Ganglia is rather easy, there might occur some problems
you come across. 

* Cluster doesn't show all nodes in web interface
* Web interface is showing page with *fsckopen error*
* Node (*gmond*) is not sending data
* Node (*gmond*) is sending data but it is not receveived by *gmetad*

There several tools that help to analyze the problem.

* `ifconfig` to check which interfaces are available
* `netstat -g` to see whether the node is in a multicast group
* `netcat` or `telnet` to check whether we can send data over the respective
  port, e.g. 8649.
* `lsof` to check whether the connections between nodes is established
* `tcpdump` to check that data is actually send
* `gstat` to see whether the metrics of a cluster are collected at a node that
  represents the node
* `/var/log/auth.log` to see which user is accessing which appliations
* `gmond` and `gmetad` running in debug mode to check for errors

Cluster doens't show all nodes in the web interface
---------------------------------------------------
Event though data gets send by `gmond` it doesn't arrive at the Ganglia server.
If you have more than one interface you might sending from the wrong interface.
If you are using multicast then you can check whether your node is in a 
multicast group with

    node$ netstat -g

To check whether the connection between nodes is established call

    node$ sudo lsof -i :8649
    COMMAND   PID    USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
    gmond   32563 ganglia    5u  IPv4 7887179      0t0  UDP 239.2.11.71:8653 
    gmond   32563 ganglia    6u  IPv4 7887181      0t0  TCP *:8653 (LISTEN)
    gmond   32563 ganglia    7u  IPv4 7887183      0t0  UDP uranus.fritz.box:507
    87->239.2.11.71:8653

As we can see uranus is sending to the multicast address.

Next check the interfaces with

    node$ ifconfig
    eth0      Link encap:Ethernet  HWaddr 08:00:27:3a:0b:5b
              inet addr:10.0.2.15 Bcast:10.0.2.255 Mask:255.255.255.0
              inet6 addr: fe80::a00:27ff:fe3a:b5b/64 Scope:Link
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
              RX packets:4423 errors:0 dropped:0 overruns:0 frame:0
              TX packets:5520 errors:0 dropped:0 overruns:0 carrier:0
              collisions:0 txqueuelen:1000
              RX bytes:608674 (608.6 KB)  TX bytes:7965736 (7.9 MB)

    eth1      Link encap:Ethernet  HWaddr 08:00:27:f7:02:57
              inet addr:192.168.178.111 Bcast:192.168.178.255 Mask:255.255.255.0
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
              RX packets:3733 errors:0 dropped:0 overruns:0 frame:0
              TX packets:3747 errors:0 dropped:0 overruns:0 carrier:0
              collisions:0 txqueuelen:1000
              RX bytes:807186 (807.1 KB)  TX bytes:822338 (822.3 KB)

We can see we have two interfaces that are poth capable of sending multicast. We
have to send the data over the IP address that is configured in `gmetad.conf`.
In this case the only address that is visible to other hosts is 
*192.168.178.111* which is *eth1*. If `gmond` sends over *eth0* we have to 
configure `mcast_if = eth1` in the nodes `gmond.conf` configuration file. To 
check which interface is sending the data we issue

    node$ sudo tcpdump -i eth0 udp port 8649
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes

If you don't see any data then check the interface *eth1*

    node$ sudo tcpdump -i eth1 udp port 8649
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth1, link-type EN10MB (Ethernet), capture size 65535 bytes
    08:28:01.948653 IP nagios.43492 > 239.2.11.71.8649: UDP, length 52
    08:28:01.949091 IP nagios.43492 > 239.2.11.71.8649: UDP, length 52
    08:28:01.999188 IP nagios.43492 > 239.2.11.71.8649: UDP, length 44
    08:28:01.999639 IP nagios.43492 > 239.2.11.71.8649: UDP, length 48
    08:28:01.999971 IP nagios.43492 > 239.2.11.71.8649: UDP, length 48
    08:28:03.186822 IP 192.168.178.120.50833 > 239.2.11.71.8649: UDP, length 48
    08:28:03.187330 IP 192.168.178.120.50833 > 239.2.11.71.8649: UDP, length 44
    08:28:03.187345 IP 192.168.178.120.50833 > 239.2.11.71.8649: UDP, length 44
    08:28:03.187359 IP 192.168.178.120.50833 > 239.2.11.71.8649: UDP, length 44
    08:28:03.325125 IP 192.168.178.120.50833 > 239.2.11.71.8649: UDP, length 48
    08:28:03.332437 IP nagios.43492 > 239.2.11.71.8649: UDP, length 48

As we can see data is send over *eth1*. In this case we have to add the IP 
*192.168.178.111* to the `data_source` definition in the `gmetad.conf`
configuration file.


Web interface is showing page with *fsckopen error*
---------------------------------------------------
This typically means that `gmetad` is not running. Try

    node$ sudo service gmetad restart

If it still doesn't start up run `gmetad` in debug mode

    node$ sudo gmetad -d 10 -c /etc/ganglia/gmetad.conf

And see if it exits with an error. You can also look into `/var/lgo/syslog` if
there are error messages in regard to `gmetad`.

Node (*gmond*) is not sending data
----------------------------------
A problem might be that the wrong interface is used (see [
Cluster doens't show all nodes in the web interface]()). You can also check
whether you are able to send data over the port *8649*. This can be done with
`netcat`.

If node1 is configured with `udp_recv_channel` so it will receive data start
`netcat -lup 8649` this will listen (-l) on UDP connection (-u) on port (-p)
8649.

    node1$ nc -ulp 8649
    
Next on node2 start netcat with an UDP connection to node1 (-u node1) on port
8649.

    node2$ nc -u node1 8649
    message from node 2

On node1 you should see the message

    node1$ nc -ulp 8649
    message from node 2

If you don't receive the message check
  
* if node1 has a `udp_recv_channel` configured
* that node1 has set `deaf = off`
* if node2 has a `udp_send_channel` configured
* that node2 is set `mute = off`
* that you have set the correct `mcast_if` if there are multiple
  interfaces configured
* that the ports are set correctly

If all has been checked you may check whether port 8649 is open with `netstat`

    node$ sudo netstat -atun | grep 8549
    tcp        0      0 0.0.0.0:8649            0.0.0.0:*            LISTEN
    udp        0      0 239.2.11.71:8649        0.0.0.0:*
    udp        0      0 192.168.178.111:43492   239.2.11.71:8649     ESTABLISHED

This check for all sockets currently in use (-a) that are TCP (-t) and UDP (-u)
and show host IP addresses instead of names (-n).

If you don't see any output you may open the port 8649 with `iptables`.

    node$ sudo iptables -A INPUT -p tcp -m state --state NEW \
    -s 192.168.178.0/24 --dport 8649 -j ACCEPT

    node$ sudo iptables -A INPUT -p udp -m state --state NEW \
    -s 192.168.178.0/24 --dport 8649 -j ACCEPT

To see if the rules are set you can issue `sudo iptables -L`.

Node (*gmond*) is sending data but it is not receveived by *gmetad*
-------------------------------------------------------------------
In this case check whether you have

* `gmetad` is running
* configured a `data_source` in `gemtad.conf` with the node and the correct IP 
  address and port
* `gmond` is sending on an interface with a public IP address

Resources
=========
To get more detailed information on Ganglia you could have a look at these
books.

* [Deploying Rails](https://pragprog.com/book/cbdepra/deploying-rails) 
  from Anthony Burns and Tom Copeland. This book is unfortunately out of print.
* [Ganglia](http://shop.oreilly.com/product/0636920025573.do) from Matt Massie
  et al

There is an excellent post about troubleshooting Ganglia at

* [hakunamapdata.com](http://hakunamapdata.com/ganglia-configuration-for-a-small-hadoop-cluster-and-some-troubleshooting/) from Adam Kawa

