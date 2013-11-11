## Caveat

I know very little about Ruby; however, this is an attempt to port Graphiti to jruby, and to remove pieces which are dependant on a specific OS or filesystem.

## Pre-requisites not covered here

A functioning installation of Graphite

## Redis (can run on a separate server if needed)
	Please refer to http://redis.io for the distribution for your operating system.

	
## Install Graphiti

	Install the various gems:
	jruby -S gem install <gem>
	bundle install
	

### Populate redis with list of metrics from graphite

* Before you run this, make sure your redis is running and you've updated graphiti's `config/settings.yml`

	1. if necessary to update the redis server (the `:6379:1/graphiti` bit is standard, just update the hostname)

			redis_url: my-redis-server:6379:1/graphiti
	2. For the graphite server and graphiti server  

			graphiti_base_url: http://my-graphiti-server
			graphite_base_url: http://my-graphite-server
	3. Make sure the metrics prefix is set correctly for the metrics that you have. If you want to see all metrics, set it to blank
	
			metric_prefix: ""

	
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

Run Puma: 

		cd ~/graphiti
		bundle exec puma -b tcp://0.0.0.0:81

	Graphiti should be available on http://localhost:81/


## Other notes:

	The originally Graphiti used the Jim gem to perform compression. The has been replaced by Wro4j 'https://code.google.com/p/wro4j/wiki/wro4jRunner'

	java -jar wro4j-runner-1.4.5-jar-with-dependencies.jar -m

	wro.xml file:
	
		<groups xmlns="public/js">
			<group name="default">
				<js>public/js/libs/jquery-1.6.4.js</js>
				<js>public/js/libs/keymaster.js</js>
				<js>public/js/libs/sammy-0.7.0.js</js>
				<js>public/js/libs/sammy.nested_params-0.7.0.js</js>
				<js>public/js/libs/sammy.storage-0.7.1pre.js</js>
				<js>public/js/libs/jscolor.js</js>
				<js>public/js/extensions.js</js>
				<js>public/js/graph.js</js>
				<js>public/js/app.js</js>
				<js>public/js/refresh.js</js>
				<js>public/js/time-frame.js</js>
			</group>
		</groups>

