# Getting Graphiti working on Ubuntu 12.10

[https://github.com/paperlesspost/graphiti](https://github.com/paperlesspost/graphiti)

## Caveat

I know nothing about Ruby etc, so the below was done with sheer ignorance, brute force and Google.

## Pre-requisites not covered here

A functioning installation of Graphite

## Redis (can run on a separate server if needed)
	wget http://redis.googlecode.com/files/redis-2.6.10.tar.gz
	tar xzf redis-2.6.10.tar.gz
	cd redis-2.6.10
	make
	./src/redis-server

## Install Ruby with RVM

	\curl -L https://get.rvm.io | bash -s stable --ruby
(This can take a while to run)

Run:

	source ~/.rvm/scripts/rvm
	rvm use ruby-2.0.0
	
	rvm pkg install zlib --verify-downloads 1
	rvm pkg install openssl
	
	gem install bundler unicorn

For info: 

	$ rvm list
		
		rvm rubies
		
		=> ruby-2.0.0-p0 [ x86_64 ]	
		
## Install Graphiti

Install git and some other bits: 

	sudo apt-get install -y git build-essential g++

Clone Graphiti repo: 

	git clone https://github.com/paperlesspost/graphiti.git
	cd graphiti/
	cp config/settings.yml.example config/settings.yml
	
Frig the Gemfile, comment out `  gem 'ruby-debug19'` in `Gemfile`.   
If you don't, there's a build error on the gem using ruby 2.0.0.

Now run the install: 

	gem install linecache19 -v '0.5.12' -- --with-ruby-include=/home/rmoff/.rvm/src/ruby-2.0.0-p0/
	bundle install

*The seperate gem install of linecache19 is necessary to avoid*

	[...]
    /home/rmoff/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/gems/2.0.0/gems/ruby_core_source-0.1.5/lib/contrib/uri_ext.rb:268:in `block (2 levels) in read': Looking for http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-2.0.0-p0.tar.gz and all I got was a 404! (URI::NotFoundError)
	[...]

	
### Unicorn

Unicorn is a HTTP server, through which Graphiti can be accessed.

Install unicorn: 

	gem install unicorn

Set up some folders and permissions that are required 

	sudo mkdir -p  /var/sites/graphiti/shared/pids/
	sudo mkdir -p  /var/sites/graphiti/shared/log/
	sudo chmod -R 777 /var/sites

Set up graphiti in unicorn

	bundle exec unicorn -c config/unicorn.rb -E production -D

*Folders and permissions are required to resolve:*

	/home/rmoff/.rvm/gems/ruby-2.0.0-p0/gems/unicorn-4.3.1/lib/unicorn/configurator.rb:90:in `block in reload': directory for pid=/var/sites/graphiti/shared/pids/unicorn.pid not writable (ArgumentError)

### Populate redis with list of metrics from graphite

* Before you run this, make sure your redis is running and you've updated graphiti's `config/settings.yml`

	1. if necessary to update the redis server (the `:6379:1/graphiti` bit is standard, just update the hostname)

			redis_url: my-redis-server:6379:1/graphiti
	2. For the graphite server and graphiti server  

			graphiti_base_url: http://my-graphiti-server
			graphite_base_url: http://my-graphite-server
	3. Make sure the metrics prefix is set correctly for the metrics that you have. If you want to see all metrics, set it to blank
	
			metric_prefix: ""

* Install libcurl: 

		sudo apt-get install -y libcurl4-openssl-dev

	*libcurl4-openssl-dev is necessary to resolve:*

		rake aborted!
		Could not open library 'libcurl': libcurl: cannot open shared object file: No such file or directory.
		Could not open library 'libcurl.so': libcurl.so: cannot open shared object file: No such file or directory

* Run the metrics get: 
	
		cd ~/graphiti
		bundle exec rake graphiti:metrics

	You should get something like this: 
	
		$ bundle exec rake graphiti:metrics
		The source :rubygems is deprecated because HTTP requests are insecure.
		Please change your source to 'https://rubygems.org' if possible, or 'http://rubygems.org' if not.
		Getting http://my-graphite-server/metrics/index.json
		Got 1960 metrics

	This will need rerunning whenever you add new metrics into carbon

## Go!

Run unicorn: 

	unicorn
	
It should bind to port 8080

	$ unicorn
	I, [2013-02-26T18:29:29.652092 #9031]  INFO -- : listening on addr=0.0.0.0:8080 fd=11
	I, [2013-02-26T18:29:29.652271 #9031]  INFO -- : worker=0 spawning...
	I, [2013-02-26T18:29:29.653406 #9031]  INFO -- : master process ready
	I, [2013-02-26T18:29:29.653914 #9033]  INFO -- : worker=0 spawned pid=9033
	I, [2013-02-26T18:29:29.654079 #9033]  INFO -- : Refreshing Gem list
	I, [2013-02-26T18:29:30.364918 #9033]  INFO -- : worker=0 ready
	
You should be able to access graphiti now on http://server:8080/

## Starting back up after a reboot

	rvm use ruby-2.0.0
	cd ~/graphiti
	unicorn

## [Optional] Alternative to unicorn : Getting it working in Apache with Passenger

This wasn't done under RVM but an apt-get installed ruby. It almost certainly won't work unmodified work with the above instructions

	sudo apt-get install -y libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libaprutil1-dev 
	sudo gem install passenger
	sudo passenger-install-apache2-module

Create `/etc/apache2/mods-enabled/passenger.load`

	LoadModule passenger_module /var/lib/gems/1.9.1/gems/passenger-3.0.19/ext/apache2/mod_passenger.so
	PassengerRoot /var/lib/gems/1.9.1/gems/passenger-3.0.19
	PassengerRuby /usr/bin/ruby1.9.1
	
Create `/etc/apache2/sites-enabled/001-graphiti`

	<VirtualHost *:81>
	   ServerName localhost
	   # !!! Be sure to point DocumentRoot to 'public'!
	   DocumentRoot /home/rmoff/graphiti/public
	   <Directory /home/rmoff/graphiti/public>
	      # This relaxes Apache security settings.
	      AllowOverride all
	      # MultiViews must be turned off.
	      Options -MultiViews
	   </Directory>
	</VirtualHost>

Restart apache2

	sudo service apache2 restart   

Graphiti should be available on [http://localhost:81/](http://localhost:81/)
