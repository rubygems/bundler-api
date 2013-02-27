worker_processes ENV['MAX_THREADS'].to_i
timeout 30
preload_app false

before_fork do |server, worker|
end

after_fork do |server, worker|
end
