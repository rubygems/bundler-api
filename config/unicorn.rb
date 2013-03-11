MAX_THREADS = Integer(ENV['MAX_THREADS'] || 2)

worker_processes MAX_THREADS
timeout 15
preload_app false
listen ENV['PORT'], :backlog => MAX_THREADS, :tcp_defer_accept => false

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to sent QUIT'
  end
end
