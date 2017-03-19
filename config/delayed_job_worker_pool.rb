
workers Integer(ENV.fetch('NUM_WORKERS', 2))
queues ENV.fetch('QUEUES', '').split(',')
sleep_delay ENV['WORKER_SLEEP_DELAY']

preload_app

# This runs in the master process after preloading the app but 
# before starting any workers
after_preload_app do
  puts "Master #{Process.pid} preloaded application"

  # Disconnect any connections that won't be inherited
  ActiveRecord::Base.connection_pool.disconnect!
end

# This runs in the worker processes after it has been forked
on_worker_boot do
  puts "Worker #{Process.pid} started"

  # Re-establish any connections
  ActiveRecord::Base.establish_connection
end

# This runs in the master process after a worker starts
after_worker_boot do |worker_info|
  puts "Master #{Process.pid} booted worker #{worker_info.process_id}"
end

# This runs in the master process after a worker shuts down
after_worker_shutdown do |worker_info|
  puts "Master #{Process.pid} detected dead worker #{worker_info.process_id}"
end