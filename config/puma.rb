worker_count = Integer(ENV.fetch('WEB_CONCURRENCY', 0))
workers worker_count if worker_count.positive?
threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads threads_count, threads_count

port ENV.fetch('PORT', 9292)
environment ENV.fetch('RACK_ENV', 'development')

if worker_count.positive?
  preload_app!

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
end

plugin :tmp_restart
