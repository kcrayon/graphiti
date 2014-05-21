listen 5000 # by default Unicorn listens on port 8080
worker_processes 2 # this should be >= nr_cpus
pid "/var/run/graphiti/graphiti.pid"
stderr_path "/var/log/graphiti/stderr.log"
stdout_path "/var/log/graphiti/stdout.log"
