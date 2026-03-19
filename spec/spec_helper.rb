
# SimpleCov must start before Rails loads
begin
  require 'simplecov'
  SimpleCov.start 'rails' do
    enable_coverage :branch
    minimum_coverage 85
  end
rescue LoadError
  warn 'SimpleCov not available; install to enforce coverage'
end

ENV['RAILS_ENV'] ||= 'test'

RSpec.configure do |config|
  # Use the test adapter to run jobs inline in specs where needed
  begin
    require 'active_job'
    ActiveJob::Base.queue_adapter = :test
  rescue LoadError
  end
end
