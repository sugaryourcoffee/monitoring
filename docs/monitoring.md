Monitoring an Application with Nagios
=====================================
We want to monitor the Secondhand application with Nagios. We will create a 
monitoring server with a VirtualBox. We will follow these steps

* Create a directory to host our box
* Create a box
* Install Nagios on the box
* Configure monitoring

Used Software
=============
We will use different software packages to create and manage our box

* VirtualBox
* Vagrant
* Puppet

Create a Directory
==================
So this is the easy part and it is not necessarily worth a separate chapter.
But to be precise we try to document each step

First we create a directory where to host our monitoring system

    $ mkdir -p Monitoring/{docs,nagios,scripts}

Working Environment
===================
In order to work efficiently we want to set up a working environment to have
everything we need on the desktop. For that to do we use _tmux_. We will have
a window with four panes. We start a new tmux session with the name _monitoring_
in the directory `monitoring`.

    $ cd ~/Monitoring
    $ tmux new -s monitoring

Within the tmux session we create 4 panes with `CTRL` `"` and `CTRL` `%`

Pane   | Directory            | Description
------ | -------------------- | ------------------------------------------------
nagios | ~/Monitoring/nagios/ | Where we create and start the Nagios server box
puppet | uranus:/etc/puppet/  | SSH session with the the puppet server _uranus_
git    | ~/Monitoring/        | Our console for e.g. committing changes to _git_
doc    | ~/Monitoring/docs/   | Where we write the documentation of what we do

Create a box
============
The monitorin system, namely Nagios is hosted on a separate server, which in
our case is a VirtualBox. What we do is

* Install VirtualBox
* Install Vagrant
* Create the box
* Start up the box
* SSH to the box

## Install VirtualBox
VirtualBox is provided by Oracle for free under the GPL version 2. Obtain
VirtualBox at [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) and
install it.

## Install Vagrant
We will use to manage our box with Vagrant. You will find Vagrant at
[vagrant.com](http://www.vagrantup.com/downloads.html), Download the version
for your operating system and install.

## Create the box
As the operating system on our box we will use Ubuntu 14.04LTS. There are 
prepared boxes at [atlas.hashicorp.com](https://atlas.hashicorp.com/boxes/search?utm_source=vagrantcloud.com&vagrantcloud=1) in case you want to use a 
differnt box.

After we have installed VirtualBox and Vagrant we can create our box with

    $ cd ~/Monitoring/nagios
    $ vagrant init ubuntu/trusty64

This will create a Vagrantfile with a basic configuration. We supplement the
Vagrantfile as follows

    config.vm.hostname = "nagios"
    config.vm.network  = "forwarded_port", guest: 80, host: 4567
    config.vm.network  = "private_network", ip: "192.168.100.100"
    config.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus   = 2
    end

Note: The IP address 192.168.100 must not match with your local Network.
vb.memory and vb.cpus you can change to what is possible with your machine.

## Create and start the box
`vagrant up` is the command to create and start up the box. The first time
you call this command the box is created. Subsequent calls of `vagrant up` will
use the created box and start it up.

    $ vagrant up

## SSH to the box
You can SSH to the box with

    $ vagrant ssh

Manage installation configuration with Puppet
=============================================
We will install and maintain our configuration with Puppet. Puppet will be 
used in client/server mode. Before we start the installation configuration for
Nagios we will install Puppet.

## Install Puppet
Puppet is available through Ubuntu's repository as _puppet_ and _puppetmaster_.
In order to use the client/server installation we will install _puppet_ on the
client machine and _puppetmaster_ on the server machine. Our client is where we
install Nagios and our Puppet server is a different machine. In the following 
our Puppet server is called `uranus`.

It is best to have the same version for both puppet and puppetmaster. But at 
least the puppetmaster has to have the version number of puppet client.

To install puppet on the client we call

    $ sudo apt-get puppet

To install puppetmaster on the server we ssh to the server and than install 
puppetmaster

    $ sudo apt-get puppetmaster

This will also install additonal packages.

We can check the version with

    $ puppet --version

## Configure Puppet master
On the puppetmaster machine (uranus) add the server directive to 
`/etc/puppet/puppet.conf` to the main sections `[main]`. If the main section
doesn't exists you can just add it.

    [main]
    server=uranus.fritz.box

In `/etc/puppet/manifests/site.pp` we describe the configuration for the 
clients. If it is not available we create an empty file

    $ sudo touch /etc/puppet/manifests/site.pp

For each of our servers we want to provision with Puppet we need to create a
node in site.pp. Our Nagios server has the URL _nagios.fritz.box_, so we add
following to `/etc/puppet/manifests/site.pp`

    node 'nagios.fritz.box' {
    }

Puppet is listening on port 8140. In order clients can connect to puppetmaster
the port 8140 has to be open. We can check with `netstat -anltp` whether the
port 8140 is open.

    $ sudo netstat -anltp

We can open the port with `iptables`

    $ sudo iptables -A INPUT -p tcp -m state --state NeW -s 192.168.178.0/24 \
    --dport 8140 -j ACCEPT

To see whether the rule is effective we can use `sudo iptables -L`.

If all is set up we can start puppetmaster

    $ service puppetmaster start
     * starting puppet master
       ...done

In case instead of `...done.` you see `...fail!` you can lookup the messages
written by puppet to `/var/log/syslog`.

Prepare the Client
==================
The next step is to check whether we can connect to the puppetmaster with
following command on the client machine. This will also create a certification
request if no certificate is available.

    $ sudo puppet agent --test --server=uranus.fritz.box

Note: In order to install packages, which ultimately runs `apt-get install` we
have to run puppet with `sudo`

Note: If you add the IP-address of uranus.fritz.box and assign it to puppet in 
_/etc/hosts_ you don't need the server directive.

    $ sudo vi /etc/hosts
    192.168.178.66 puppet

Now we can connect to the server with

    $ sudo puppet agent --test

If you see an output 
`Exiting: no certificate found and waitforcert is dispabled` then the your 
client has requested a certifcate but it has not been created.

To create it we ssh to our server uranus

    $ ssh uranus

and look for waiting certification requests

    $ sudo puppet cert --list

We can certify the certification requests with

    $ sudo puppet cert sign nagios.fritz.box

Back in the client a call to `puppet agent --test` should indicate that the
certification request has been aproved.

Install Nagios on the box
=========================
To install Nagios we create a Puppet module.

On our Puppet server we create a directory `/etc/puppet/modules` and `cd` to it

    $ cd /etc/puppet
    $ mkdir modules
    $ cd modules

Now we create a module structure for Nagios by using the Puppet 
`module generate` command.

    $ puppet module generate sugaryourcoffee-nagios
    $ mv sugaryourcoffee-nagios nagios

If we would push our module to _Puppet Forge_ we would have to use our 
company name _sugaryourcoffe_ but for the module we need to have the pure 
nagios name in order this to be working.

Now is a good time to start managing our Puppet modules with _Git_. In 
`/etc/puppet/modules`. To do this we give the write permissions to the user for 
`/etc/puppet/modules/` and initialize our Git repository.

    $ sudo chgrp -R pierre /etc/puppet/modules
    $ sudo chmod -R g+w /etc/puppet/modules
    $ git init
    $ git add .
    $ git commit -am "Initial commit"

We create a Git repository on [Github](https://github.com) and add the remote
repository and push it to Github.

    $ git remote add origin git@github.com:sugaryourcoffee/puppet-server.git
    $ git push -u origin master

Now back to Puppet. The scaffolding of our module has created a bare 
`nagios/manifests/init.pp` file we rename to 'nagios/manifests/server.pp` and 
extend with

    class nagios::server {
      class { '::nagios::server::install`: } ->
      class { '::nagios::server::config':  } ->
      class { '::nagios::server::service': } ->
      Class['nagios::server']
    }

Now for each of the classes _install_, _config_, and _service_ we create a
pp-file in `nagios/manifests/server/`. The directory doesn't exist so we will
created with `sudo mkdir /etc/puppet/modules/nagios/manifests/server`

    class nagios::server::install {
      package { "nagios3":
        ensure => present,
      }
    }

    class nagios::server::config {
       # content pending 
    }

    class nagios::server::service {
      service { "nagios3":
        ensure     => running,
        hasrestart => true,
        enable     => true,
        hasstatus  => true,
        restart    => "/etc/init.d/nagios3 reload",
        require    => Class["nagios::server::install"]
      }
    }


In a final step we supplement the node definition in 
`/etc/puppet/manifests/site.pp` with

    node 'nagios.fritz.box' {
      include ::nagios::server
    }

When we are done with the basic configuration we can run puppet in order
to install Nagios on our Nagios server, that is the Vagrant box. But before we 
do so we update our repository. If we don't it might happen that we get the 
error message that Ubuntu's repository server cannot be found.

    $ sudo apt-get update
    $ sudo apt-get upgrade
    $ sudo puppet agent --test
    Info: Retrieving plugin
    Info: Caching catalog for nagios.fritz.box
    Info: Applying configuration version '1439316179'
    Notice: /Stage[main]/Nagios::Server::Install/Package[nagios3]/ensure: \
    ensure changed 'purged' to 'present'
    Notice: Finished catalog run in 94.92 seconds

We can check that Nagios is installed with

    $ sudo dpkg --get-selections | grep nagios
    nagios-images                         install
    nagios-plugins                        install
    nagios-plugins-basic                  install
    nagios-plugins-common                 install
    nagios-plugins-standard               install
    nagios3                               install
    nagios3-cgi                           install
    nagios3-common                        install
    nagios3-core                          install

Along with Nagis also Apache 2 has been installed. Nagios is providing a web 
interface which is provided over Apache 2. The configuration of the web 
interface is available in the '/etc/nagios3/apache2.conf' file. We will tweak
this file by changing the configuration to provide the website as a virutal 
host. As we are working with Puppet we will manage this file also with Puppet.
At first copy the file to the Puppet server and then on the Puppet server to
'/etc/puppet/modules/files'

    $ scp /etc/nagios3/apache2.conf pierre@uranus:apache2.conf
    $ ssh uranus 
    $ sudo cp apache2.conf /etc/puppet/modules/nagios/files/

Note: If the directory '/etc/puppet/modules/nagios/files/' doesn't exist you 
have to create it first with 'sudo mkdir /etc/puppet/modules/nagios/files/'

Next we put the content into a virtual host directive
    
    NameVirtualHost *:80
    <VirtualHost *:80>
      ServerName nagios.localhost
      ScriptAlias /cgi-bin/nagios3 /usr/lib/cgi-bin/nagios3
      ScriptAlias /nagios3/cgi-bin /usr/lib/cgi-bin/nagios3
      Alias /nagios3/stylesheets /etc/nagios3/stylesheets
      Alias /nagios3 /usr/share/nagios3/htdocs
      <DirectoryMatch (/usr/share/nagios3/htdocs|\
      /usr/lib/cgi-bin/nagios3|/etc/nagio
        Options FollowSymLinks
        DirectoryIndex index.php index.html
        AllowOverride AuthConfig
        Order Allow,Deny
        Allow From All
        AuthName "Nagios Access"
        AuthType Basic
        AuthUserFile /etc/nagios3/htpasswd.users
        require valid-user
      </DirectoryMatch>

      <Directory /usr/share/nagios3/htdocs>
        Options +ExecCGI
      </Directory>
    </VirtualHost>

In order to access the Nagios interface we need a login and password. The
credentials (login and password) have to be created with `htpasswd` which is a
Apache 2 tool. On our Nagios server we create the credentials file with

    $ sudo -cmb /etc/nagios3/htpasswd.users nagiosadmin nagios

We copy the file to the Puppet server uranus with

    $ scp /etc/nagios3/htpasswd.users pierre@uranus:htpasswd.users

and copy it to the files directory of our Puppet nagios module

    $ ssh uranus
    $ sudo mv ~/htpasswd.users /etc/puppet/modules/nagios/files/

Now we have all files in place and we are ready to fill in the content to our 
'/etc/puppet/modules/nagios/manifests/config.pp' file.

    class nagios::server::config {
      file { "/etc/nagios3/apache2.conf":
        source => "puppet:///modules/nagios/apache2.conf",
        owner  => root,
        group  => root,
        mode   => 644,
        notify => Class["apache::service"],
      }
      file { "/etc/nagios3/htpasswd.users":
        source => "puppet:///modules/nagios/htpasswd.users",
        owner  => www-data,
        group  => nagios,
        mode   => 640,
        require => Class["nagios::server::install"],
      }
    }

Even though Nagios is taking care of installing Apache 2 we still have to
manage Apache 2 separately with Puppet because we need the _apache::service_
directive when we load the file `/etc/nagios3/apache2.conf` with the above
_nagios::server::config_ directive.

On our Puppet server we create an Apache 2 module in `/etc/puppet/modules/`

    $ sudo puppet module generate sugaryourcoffee-apache
    $ sudo mv sugaryourcoffee-apache apache

We open `/etc/puppet/modules/apache/manifests/init.pp` and add

    class apache {
      class { '::apache::install': } ->
      class { '::apache::service': } ->
      Class["apache"]
    }

Then for each of _install_ and _service_ we create a pp-file in 
`/etc/puppet/modules/apache/config/install.pp`

    class apache::install {
      package { [ 'apache2' ]:
        ensure => present,
      }
    }

and in `/etc/puppet/modules/apache/manifests/service.pp`

    class apache::service {
      service { "apache2":
        ensure     => running,
        hasstatus  => true,
        hasrestart => true,
        enable     => true,
        require    => Class['apache::install'],
      }
    }

As a final step we have to add _apache_ to our `/etc/puppet/manifests/site.pp`

    node 'nagios.fritz.box' {
      include ::nagios::server
      include ::apache
    }

Back on our host machine where the Nagios server lives we call

    $sudo puppet agent --test

and we should see the updated file `/etc/nagios/apache2.conf` and the file
`/etc/nagios/htpasswd.users`.

To access Apache 2 we have to forward a port from our host to the VirtualBox. 
On the host we then add following to the Vagrantfile

    $ vi Vagrantfile
    config.vm.network "forwarded_port", guest: 80, host: 4567

In order that the changes in the Vagrantfile are recognized by VirtualBox we
have to reload the box

    $ vagrant reload

From a browser you should see the default Apache 2 website with 
`localhost:4567` and to access the nagios interface we add the URL
`localhost:4567/nagios3`. We are prompted for login and password where we
provide _nagiosadmin_ and _nagios_ as defined when created the _htpasswd_ file.

If you are using Firefox and you get on the top the message 
_Firefox prevents page from autorefresh_ then in the address field type 
`about:config`. Click the button where you agree that you will be carefull and 
search for _accessibility.blockautorefresh_ double click that row so the value 
show _false_. Now go back to the Nagios interface and press the button _allow_ 
to allow autorefresh.

Configure Nagios
================
Nagios configuration takes place in the `/etc/nagios3/nagios.cfg` file. We will
manage that file with Puppet. To do so we first copy the file into the
`/etc/puppet/modules/nagios/files/` directory.

    $ scp /etc/nagios3/nagios.cfg pierre@uranus:nagios.cfg
    $ ssh uranus
    $ mv nagios.cfg /etc/puppet/modules/nagios/files/

To manage `nagios.cfg` we add following to 
`/etc/puppet/modules/manifests/config.pp`

    class nagios::server::config {
      file { "/etc/nagios3/nagios.cfg":
        source  => "puppet:///modules/nagios/nagios.cfg",
        owner   => nagios
        group   => nagios
        mode    => 644,
        require => Class["nagios::server::install"],
        notify  => [Class["apache::service"], Class["nagios::server::service"]]
      }
    }

In order to rescedule a service check from the Nagios web interface we have to
configure Nagios respectively. This is done in the `nagios.cfg` file. We have
to change `check_external_commands` from 0 to 1.

    check_external_commands=1

When we rescedule a service check, that is we manually start the check, Nagios
uses the file `/var/nagios3/rw/nagios.cmd`. In order Nagios can change that
file we need to set the permission to execute for user _www-data_ who has to be
in the group _nagios_. This we do in an additional file resource and an user
resource. We add these resources to 
`/etc/puppet/modules/nagios/manifests/server/config.pp`

    file { "/var/lib/nagios3/rw":
      ensure  => directory,
      owner   => nagios,
      group   => www-data,
      mode    => 710,
      require => Class["nagios::server::install"],
    }
    user { "www-data":
      groups  => "nagios",
      notify  => Class["apache::service"],
      require => Class["nagios::server::install"],
    }

Now back on the nagios server we issue

    $ sudo puppet agent --test

And the file permissions should be set as requested and the user _www-data_
should be in the group _nagios_. We can check that it works by rescheduling a
service in the Nagios web interface.

The Nagios configuration files live in `/etc/nagios3/conf.d/`. We will manage
these with puppet and copy them to our Puppet server. 

    $ scp /etc/nagios3/conf.d/localhost_nagios2.cfg \
    pierre@uranus:localhost_nagios.cfg

We create a directory where we want to manage all configuration files

    $ ssh uranus
    $ cd /etc/puppet
    $ sudo mkdir -p modules/nagios/files/conf.d/hosts
    $ sudo mv ~/*.cfg /etc/puppet/modules/files/conf.d/hosts/

We add additonal resources to `/etc/puppet/modules/nagios/manifests/config.pp`
to manage the configuration files.

    file { "/etc/nagios3/conf.d":
      source  => "puppet:///modules/nagios/conf.d/",
      ensure  => directory,
      owner   => nagios,
      group   => nagios,
      mode    => 0644,
      recurse => true,
      notify  => Class["nagios::server::service"],
      require => Class["nagios::server::install"],
    }
    file { "/etc/nagios3/conf.d/localhost_nagios2.cfg":
      ensure => absent,
    }

Planning for monitoring
-----------------------
Now we have setup Nagios and are ready for planning which hosts to monitor. We
have a prodcution server _mercury_, and a staging server _uranus_. We also have
a dynamic IP address that is managed over dyndns. In the following table the 
applications are shown that we want to monitor.

Server/URL     | Application           | Hosts file
-------------- | --------------------- | -----------
mercury        | Secondhand production | mercury.cfg
uranus         | Secondhand staging    | uranus.cfg
uranus         | Apptrack              | uranus.cfg
syc.dyndns.org | mercury and uranus    | dyndns.cfg

For each of the servers we need a configuration file that we save on our Puppet
server uranus in `/etc/puppet/modules/nagios/files/conf.d/hosts`

The mercury.cfg looks like this

     define host {
       use       generic-host
       host_name mercury
       alias     mercury
       address   192.168.178.61
     }    
     define service {
       use                 generic-service
       host_name           mercury
       service_description SSH
       check_command       check_ssh
     }

The uranus.cfg has the same content except for the host

    define host {
      use       generic-host
      host_name uranus
      alias     uranus
      address   192.168.178.66
    }
    define service {
      use                 generic-service
      host_name           uranus
      service_description SSH
      check_command       check_ssh
    }

Finally the dyndns.cfg

    define host {
      use       generic-host
      host_name syc.dyndns.org
      alias     syc.dyndns.org
      address   syc.dyndns.org
    }
    define service {
      use                 generic-service
      host_name           syc.dyndns.org
      service-description PING
      check_command       check-host-alive
    }

The servers _uranus_, _mercury_ and _syc.dyndns.org_ are so called remote hosts.
We can check on remote hosts only services that are accessible from outside.
The services we check here is _SSH_ and _PING_. But we also need to check
internal services like processes, users and disk space, just to name a few. In
order to also monitor these internal services we need to use a service called
_NRPE_ (Nagios Remote Plugins Executor). NRPE runs the checks on the remote 
host and returns the results to our Nagios server. To get this up we have to
install the NRPE plugin on our Nagios server and on our remote hosts.

On our Puppet server we extend 
`/etc/puppet/modules/nagios/manifests/server/install.cfg` with 
_nagios-nrpe-plugin_

    class nagios::server::install {
      package { ["nagios3", "nagios-nrpe-plugin"]:
        ensure => present,
      }
    }

For our remote hosts _uranus_ and _mercury_ we create Puppet manifests to 
install NRPE. We create a file `/etc/puppet/modules/nagios/manifests/client.pp`
and add following content

    class nagios::client {
      class { '::nagios::client::install': } ->
      Class['nagios::client']
    }

and in the directory `/etc/puppet/modules/nagios/manifests/client/` we add the
_install.pp_ manifest

    class nagios::client::install {
      package { ["nagios-nrpe-server", "nagios-plugins"]:
        ensure => present,
      }
    }

In order the clients get recognized we have to add them to 
`/etc/puppet/manifests/site.pp`

    node 'uranus.fritz.box' {
      include ::nagios::client
    }

Now we install NRPE on the Nagios server with

    $ sudo puppet agent --test

The same we have to do on the remote host, that is _uranus_ which happens 
to be the same machine as our Puppet server. In this case we will use
`puppet apply` instead using `sudo puppet agent --test`

    $ sudo puppet apply /etc/puppet/manifests/site.pp
    Notice: Compiled catalog for uranus.fritz.box in environment production in 
    0.08 seconds
    Info: Applying configuration version '1439810753'
    Notice: /Stage[main]/Nagios::Client::Install/Package[nagios-plugins]/\
    ensure: ensure changed 'purged' to 'present'
    Notice: /Stage[main]/Nagios::Client::Install/Package[nagios-nrpe-server]/\
    ensure: ensure changed 'purged' to 'present'
    Notice: Finished catalog run in 123.44 seconds

If we run `dpkg --get-selections | grep nagios` we will see that the packages
have been installed

    $ dpkg --get-selections | grep nagios
    nagios-nrpe-server                              install
    nagios-plugins                                  install
    nagios-plugins-basic                            install
    nagios-plugins-common                           install
    nagios-plugins-standard                         install

Now that we have NRPE installed we will find a configuration file `nrpe.cfg`in 
`/etc/nagios/nrpe.cfg`. We copy that file to our Puppet files folder

    $ sudo cp /etc/nagios/nrpe.cfg /etc/puppet/modules/nagios/files/

In that file we can tell NRPE which hosts are allowed to access the services.
Make following change to `nrpe.cfg`

    allowed_hosts=192.168.178.81

This is the IP address of our host machine. Even though we are connecting from
the nagios server, that is the Vagrantbox, the hosts IP address is forwarded. In
order to make changes available we have to add a _config_ class to 
`/etc/puppet/modules/nagios/manifests/client/config.pp

    class nagios::client::config {
      file { "/etc/nagios/nrpe.cfg":
        source => "puppet:///modules/nagios/nrpe.cfg"
        owner  => root,
        group  => root,
        mode   => 644,
      }
      service { "nagios-nrpe-server":
        ensure    => true,
        enable    => true,
        subscribe => File["/etc/nagios/nrpe.cfg"]
      }
    }

We also have to supplement `/etc/puppet/modules/nagios/manifests/client.pp`

    class nagios::client {
      class { '::nagios::client::install': } ->
      class { '::nagios::client::config':  } ->
      Class['nagios::client']
    }

To get everything in place we run

    $ sudo puppet apply --verbose /etc/puppet/manifests/site.pp

Now _uranus_ is listening for requests from our Nagios server. To see whether
we can retrieve information from _uranus_ we issue following command

    nagios$ /usr/lib/nagios/plugins/check_nrpe -H uranus
    NRPE v2.15

The string _NRPE v2.15_ indicates that it is working. Now we are ready to add
additional services to our 
`/etc/puppet/modules/nagios/files/conf.d/hosts/uranus.cfg`. We want to monitor
services shown in the table below.

Service          | Description                    | Command
---------------- | ------------------------------ | ------------------
Current users    | Check count of users           | check_users
Current load     | Check system load              | check_load
Disk space       | Check disk space               | check_all_disks
SSH              | Check SSH connection           | check_ssh
Zombie processes | Check count zombie processes   | check_zombie_procs
Total processes  | Check count of total processes | check_total_procs

These checks are hard coded to `/etc/ngios/nrpe.cfg`. We will use all of these
checks except _Disk Space_ which we want to tweak to check all disks. Change
following line in '/etc/puppet/modules/nagios/files/nrpe.cfg`

    command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% \
    -p /dev/hda1

to

    command[check_all_disks]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -e

We now add these to `uranus.cfg`. Following we show how to use the 
`check_nrpe_1arg` command

    define service {
      use                 generic-service
      host_name           uranus
      service_description Disk Space
      check_command       check_nrpe_1arg!check_all_disks
    }

In order to activate the changes we have to run Puppet on the Nagios server 
*nagios* and on the remote host *uranus*.

    nagios$ sudo puppet agent --test
    uranus$ sudo puppet apply --verbose /etc/puppet/manifests/site.pp

Check up Phusion Passenger
--------------------------
Next we want to check up _Phusion Passenger_. For that to do we write a Nagios 
plugin as a Bash script that is using *passenger_status* that provides process 
information. We put the script into `/usr/lib/nagios/plugins/check_passenger`.

The usage of passenger is

    $ check_passenger [options]

The options are explained in the table below.

Flag |             | Parameter | Description
---- | ----------- | --------- | ------------------------------
     |             |           | Print passenger_status
-r   | --requests  | APP       | Requests in queue for APP
-l   | --load      | APP       | CPU load for APP
-m   | --memory    | APP       | Memory usage for APP
-a   | --access    | APP       | Accesses of APP during uptime
-u   | --uptime    | APP       | Uptime of APP
-f   | --frequency | APP       | Access frequency within uptime
-s   | --sessions  | APP       | Sessions of APP
-w   | --warning   | N         | Warning threashold
-c   | --critical  | N         | Critical theashold
-h   | --help      |           | Print help

Example of invoking `check\_passenger`

    $ ./check_passenger -r secondhand -w 50 -c 100

The script can be found [check_passenger](https://github.com/sugaryourcoffee/monitoring/blob/master/scripts/check_passenger). 

The next step is to use the script in the NRPE what we will do now. The steps
we follow are

* Allow user nagios to invoke plugins with sudo
* Put check\_passenger in a new Puppet directory 
  `/etc/puppet/modules/nagios/files/plugins`
* Add the file to a file resource in 
  `/etc/puppet/modules/nagios/manifests/client/config.pp`
* Create a Nagios command for check\_passenger in 
  `/etc/puppet/modules/nagios/files/conf.d/commands.cfg`
* Enable the new command in `/etc/puppet/modules/nagios/files/nrpe.cfg`
* Add the command definition to 
  `/etc/puppet/modules/nagios/files/conf.d/hosts/uranus.cfg`
* Run sudo puppet agent --test on the Nagios server and 
  puppet apply /etc/puppet/manifests/site.pp

We will now go through each of theses steps.

### Add user nagios to /etc/sudoers
This is an important step. As we are using in our script `passenger-status`, 
which in turn needs to be run with rvmsudo, we have to add user nagios to the
`/etc/sudoers` file with the _NOPASSWD_ directive. We don't add this to 
`/etc/sudoers` directly but rather we put it in 
`/etc/sudoers.d/nagios-permissions`. For editing _sudoers_ files it is 
recommended to use _visudo_.

    $ sudo visudo -f /etc/sudoers.d/nagios-permissions

This will open the _nano_ editor with `nagios.tmp`. Then we add following 
content

    nagios ALL=(ALL) NOPASSWD:/usr/lib/nagios/plugins/,\
    /home/pierre/.rvm/gems/ruby-2.0.0-p643@rails401/bin/passenger-status

To save your changes press _CTRL-X_ and confirm with `Y` that you want to save
changes. Then hit `RETURN` confirming that you want to write to `nagios.tmp`.
If there are any syntax errors you will be put back to nano.

Note: To find the path to _passenger-status_ you can 
call `rvmsudo which passenger-status`

Note: If you mess up your sudoers file you can recover with `pkexec visudo`

To get this file managed with Puppet copy it to 
`/etc/puppet/modules/nagios/files/` and change the file permissions so we can
add them to our Git repository.

    $ sudo cp /etc/sudoers.d/nagios-permissions \
              /etc/puppet/modules/nagios/files/
    $ sudo chgrp pierre /etc/puppet/modules/nagios/files/nagios-permissons

and add a file source to `/etc/puppet/modules/nagios/manifests/client/config.pp`

    file { "/etc/sudoers.d/nagios":
      source => "puppet:///modules/nagios/nagios",
      owner  => root,
      group  => root,
      mode   => 440,
    }

Next open up `/etc/puppet/nagios/files/nrpe.cfg` (`/etc/nagios/nrpe.cfg`) 
and uncomment `command_prefix=/usr/bin/sudo`

In order to make the changes available we have to restart the 
_nagios-nrpe-server_ with

    $ sudo service nagios-nrpe-server restart

But this will be done by Puppet after our last step. So keep patient.

### Manage check\_passenger by Puppet
We create a new directory `plugins`where we put check\_passenger to

    $ cd /etc/puppet/modules/nagios
    $ mkdir files/plugins
    $ cp /usr/lib/nagios/plugins/check_passenger files/plugins/
   
### Add check\_passenger File Resource to client/config.pp
In order to get *check_passenger* in place we create a file resource in
`/etc/puppet/modules/nagios/manifests/client/config.pp`

    File { "/usr/lib/nagios/plugins/check_passenger":
      source => "puppet:///modules/nagios/plugins/check_passenger",
      owner  => nagios,
      group  => nagios,
      mode   => 755,
    }

### Create a Nagios Command for check\_passenger
We define a new command that Nagios can use to invoke our check\_passenger
script. We put all the *check_passenger* commands in 
`/etc/puppet/modules/nagios/files/conf.d/commands.cfg`

    define command {
      command_name check_passenger
      command_line /usr/lib/nagios/plugins/check_passenger
    }

    define command {
      command_name check_passenger_requests
      command_line /usr/lib/nagios/plugins/check_passenger \
        -r $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_load
      command_line /usr/lib/nagios/plugins/check_passenger \
        -l $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_memory
      command_line /usr/lib/nagios/plugins/check_passenger \
        -m $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_accesses
      command_line /usr/lib/nagios/plugins/check_passenger \
        -a $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_uptime
      command_line /usr/lib/nagios/plugins/check_passenger \
        -u $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_frequency
      command_line /usr/lib/nagios/plugins/check_passenger \
        -f $ARG1$ -w $ARG2$ -c $ARG3$
    }

    define command {
      command_name check_passenger_sessions
      command_line /usr/lib/nagios/plugins/check_passenger \
        -s $ARG1$ -w $ARG2$ -c $ARG3$
    }

### Add check\_passenger Commands to nrpe.cfg
To make check_passenger commands available we have to add them to nrpe.cfg. We
add all commands to nrpe.cfg so we can later decide which we want to use. We put
them to `/etc/puppet/modules/nagios/files/nrpe.cfg`.

    command[check_passenger_memory]=/usr/lib/nagios/plugins/check_passenger \
      -m secondhand -w 100 -c 150

### Add Service for check\_passenger
In order to make Nagios run the command we have to add an additonal service to
`/etc/puppet/nagios/files/conf.d/hosts/uranus.pp`

    define service {
      use                 generic-service
      host_name           uranus
      service_description Passenger Memory
      check_command       check_nrpe_1arg!check_passenger_memory
    } 

### Run Puppet
Now that we have all the configuration files organized in Puppet we need to run
so they get into place. We have made changes to configuration files of the
Nagios server *nagios* and on the *uranus* server, which from Nagios' point of 
view is the remote host. So we have to run puppet on *nagios* and on *uranus*.

On *nagios* we run

    $ sudo puppet agent --test

and on *uranus* we run

    $ sudo puppet apply --verbose /etc/puppet/manifests/site.pp

When we look at the Nagios web interface we should see the new service. We can
also check on our Nagios server whether we can invoke our new plugin with

    $ /usr/lib/nagios/plugins/check_nrpe -H uranus -c check_passenger_memory
    Passenger apptrack memory OK - 72M used

Note: If you get an error saying 
_sudo: no tty present and no askpass programm specified_ then go back to 
step 1 and double check your settings.

### Overview of Configuration Files
It's quite easy to loose track with all these configuration files and what goes
where. Therefore here is an overview. *uranus* is the remote host where the 
NRPE server runs and *nagios* is the Nagios server that calls the plugin on the
remote host over NRPE.

Server | Content                                | File
------ | -------------------------------------- | ------------------------------------
uranus | Plugin called from nagios on uranus    | /usr/lib/nagios/plugins/
uranus | Enable plugin to be called from nagios | /etc/nagios/nrpe.cfg
nagios | Command definition of remote plugin    | /etc/nagios3/conf.d/commands.cfg
nagios | Service definition to call plugin      | /etc/nagios3/conf.d/hosts/uranus.cfg

### Enable Nagios to Run Plugins with sudo
In cases we use commands in our plugins that need to be run with sudo we have
to do configure the remote host as shown in the table below.

File                 | Configuration
-------------------- | -------------------------------------------------------------------------------
/etc/nagios/nrpe.cfg | uncomment `# command_prefix=/usr/bin/sudo`
/etc/sudoers         | add `nagios ALL=(ALL) NOPASSWD:/path/to/plugin,/path/to/command/that/needs/sudo`

Note: Be aware that it is recommended to edit `/etc/sudoers` with `visudo` 
otherwise you risk to mess up your /etc/sudoers file. In case you do so you can
recover with `pkexec visudo` 

Using NRPE with Parameter Passing
---------------------------------
Up to now we used NRPE with fixed parameters. In case we need to change the 
plugin name we we would have to do that on the Nagios server and on the remote
host. In our current example we have used `check_passenger` to check up the
application *apptrack*. 

    command[check_passenger_memory]=/usr/lib/nagios/plugins/check_passenger \
    -m apptrack -w 150 -c 200

We also want to check up *secondhand* to do this we have to add another command 
to `/etc/nagios/nrpe.cfg`

    command[check_passenger_secondhand_memory]=/usr/lib/nagios/plugins/\
    check_passenger -m secondhand -w 150 -c 200

On Nagios we would add a second service definition to 
`/etc/nagios3/conf.d/hosts/uranus.pp`
  
    define service {
      use                generic-service
      host_name          uranus
      service_descripton Passenger memory
      check_command      check_nrpe_1arg!check_passenger_memory
    }

    define service {
      use                generic-service
      host_name          uranus
      service_descripton Passenger secondhand memory
      check_command      check_nrpe_1arg!check_passenger_secondhand_memory
    }

If someone else reads this it looks like the first service is checking the
total memory and the second is checking the secondhand specific memory. This is
not a real issue but in order to make it more clear what we are checking we
should rename our first service according to what it is really checking 
`Passenger apptrack memory`. 

The `/etc/nagios3/conf.d/hosts/uranus.pp` looks now like this

    define service {
      use                generic-service
      host_name          uranus
      service_descripton Passenger apptrack memory
      check_command      check_nrpe_1arg!check_passenger_apptrack_memory
    }

    define service {
      use                generic-service
      host_name          uranus
      service_descripton Passenger secondhand memory
      check_command      check_nrpe_1arg!check_passenger_secondhand_memory
    }

Along with this change we also have to change our command in 
`/etc/nagios/nrpe.cfg` to

    command[check_passenger_apptrack_memory]=/usr/lib/nagios/plugins/\
    check_passenger -m apptrack -w 150 -c 200

But we can do better but be warned with a security risk.

To enable parameter passing with NRPE we have to follow these steps

* Set `dont_blame_me=1` in /etc/nagios/nrpe.cfg on the remote host *uranus*
* Add the command `command[check_passenger]=/usr/lib/nagios/plugins/\
  check_passenger -m $ARG1$ -w $ARG2$ -c $ARG3$
* Check that the command can be invoked from the Nagios host *nagios*
* Copy `/etc/nagios/nrpe.cfg` to `/etc/puppet/modules/nagios/files/nrpe.cfg`
* Add a command definition to 
  `/etc/puppet/modules/nagios/files/conf.d/commands.cfg` on the Puppet server
* Add a service definition to 
  `/etc/puppet/modules/nagios/files/conf.d/hosts/uranus.cfg`
* Run puppet on the remote host *uranus* and on the Nagios server *nagios*

Again we describe all of these steps in detail.

### Enable Parameter with NRPE
To enable parameter passing to NRPE we have to set the `dont_blame_me` parameter
to 1 in `/etc/nagios/nrpe.cfg`

    dont_blame_me=1

### Add a Command with Parameters to nrpe.cfg
In order to call a command with parameters enabled we have to add the command
to `/etc/nagios/nrpe.cfg`

    command[check_passenger_memory]=/usr/lib/nagios/plugins/check_passenger \
    -m $ARG1$ -w $ARG2$ -c $ARG3$

### Check the Command from the Nagios Server
Before we do further configuration we first check that the command can be 
invoked with parameters. From the Nagios server *nagios* we issue following 
command

    /usr/lib/nagios/plugins/check_nrpe -H uranus -c check_passenger_memory \
    -a apptrack 150 200

As you can see in the invocation above we don't use the flags (-m, -w, -c) but
rather use -a which expects the parameter values in the right sequence as 
defined in `command[check_passenger_memory]`. 

We do another check for *secondhand* with

    /usr/lib/nagios/plugins/check_nrpe -H uranus -c check_passenger_memory \
    -a secondhand 150 200

### Copy nrpe to Puppet
If the command can be invoked we copy nrpe.cfg to the Puppet directory in order
it gets managed by Puppet.

    uranus$ sudo cp /etc/nagios/nrpe.cfg \
                    /etc/puppet/modules/nagios/files/nrpe.cfg

### Add a Command Definition
Next we have to add a command definition to `/etc/puppet/modules/nagios/files/conf.d/commands.cfg`

    define command {
      command_name      check_passenger_memory
      command_line      /usr/lib/nagios/plugins/check_passenger \
      -H "$HOSTADDRESS$" -c "check_passenger" -a $ARG1$ $ARG2$ $ARG3$
    }

### Add a Service Definition
Finally we add the actual invocation of the command by defining a respective
service in `/etc/puppet/modules/nagios/files/conf.d/hosts/uranus.cfg`

    define service {
      use                generic-service
      host_name          uranus
      service_description Passenger apptrack memory
      check_command       check_passenger_memory!apptrack!150!200
    }

    define service {
      use                 generic-service
      host_name           uranus
      service_description Passenger secondhand memory
      check_command       check_passenger_memory!secondhand!150!200
    }

### Run Puppet
The final step to get our Nagios checks to work we have to call Puppet to get
the files in place

    nagios$ sudo puppet agent --test
    uranus$ sudo puppet apply --verbose /etc/puppet/manifests/site.pp

To check everything is working head over to your browser and look at the 
Nagios web interface at 
[http://localhost:4567/nagios3/](http://localhost:4567/nagios3/)

Mapping of Nagios Files to Puppet Files
---------------------------------------
After having a lot of files to manage the table that follows is which Nagios
file maps to which Puppet file. Here the *Server* column indicates on which
server the Nagios file resides.

Server | Nagios | Puppet
------ | ------ | ------
nagios | /etc/nagios3/apache2.conf | nagios/files/apache2.conf
nagios | /etc/nagios3/htpasswd.users | nagios/files/htpasswd.users
nagios | /etc/nagios3/nagios.cfg | nagios/files/nagios.cfg
uranus | /etc/sudoers.d/nagios-permissions | nagios/files/nagios-permissions
uranus | /etc/nagios/nrpe.cfg | nagios/files/nrpe.cfg
nagios | /etc/nagios3/conf.d/commands.cfg | nagios/files/conf.d/commands.cfg
nagios | /etc/nagios3/conf.d/hosts/dyndns.cfg | nagios/files/conf.d/hosts/sycdyndns.cfg
nagios | /etc/nagios3/conf.d/hosts/localhost_nagios.cfg | nagios/files/conf.d/hosts/localhost_nagios.cfg
nagios | /etc/nagios3/conf.d/hosts/mercury.cfg | nagios/files/conf.d/hosts/mercury.cfg
nagios | /etc/nagios3/conf.d/hosts/uranus.cfg | nagios/files/conf.d/hosts/uranus.cfg
nagios | /usr/lib/nagios/plugins/check_passenger | nagios/files/plugins/check_passenger

Directory Structure
-------------------
Our Puppet directory structure looks like this now

    nagios 
    ├── files
    │   ├── apache2.conf
    │   ├── conf.d
    │   │   ├── commands.cfg
    │   │   └── hosts
    │   │       ├── dyndns.cfg
    │   │       ├── localhost_nagios.cfg
    │   │       ├── mercury.cfg
    │   │       └── uranus.cfg
    │   ├── htpasswd.users
    │   ├── nagios.cfg
    │   ├── nagios-permissions
    │   ├── nrpe.cfg
    │   └── plugins
    │       └── check_passenger
    ├── manifests
    │   ├── client
    │   │   ├── config.pp
    │   │   └── install.pp
    │   ├── client.pp
    │   ├── server
    │   │   ├── config.pp
    │   │   ├── install.pp
    │   │   └── service.pp
    │   └── server.pp
    ├── Modulefile
    ├── README
    ├── spec
    │   └── spec_helper.rb
    └── tests
        └── init.pp

