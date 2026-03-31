Sidekiq.configure_server do |config|
  # Error handler - logs all job failures
  config.error_handlers << ->(exception, ctx) {
    Rails.logger.error("Sidekiq job failed", {
      job_class: ctx[:job],
      job_id: ctx[:jobid],
      queue: ctx[:queue],
      error_class: exception.class.name,
      error_message: exception.message,
      backtrace: exception.backtrace.first(5),
      timestamp: Time.current.iso8601,
      context: ctx
    })

    # Could also send to error tracking service here (e.g., Sentry, Rollbar)
    # Raven.capture_exception(exception, extra: ctx) if defined?(Raven)
  }

  # Death handler - logs when job is permanently dead (max retries exceeded)
  config.death_handlers << ->(job, exception) {
    Rails.logger.fatal("Sidekiq job permanently dead (max retries exceeded)", {
      job_class: job['class'],
      job_id: job['jid'],
      queue: job['queue'],
      error_class: exception.class.name,
      error_message: exception.message,
      retry_count: job['retry_count'],
      timestamp: Time.current.iso8601
    })

    # Could send alerts here for critical jobs
    if job['class'].include?('AuctionCloseJob') || job['class'].include?('PaymentPromptJob')
      # Admin notification: alert about auction job failure
      # AdminMailer.critical_job_dead(job, exception).deliver_later if defined?(AdminMailer)
    end
  }

  # Retry handler - logs when job is being retried
  config.server_middleware do |chain|
    chain.add RetryLoggingMiddleware
  end
end

# Custom middleware to log retries
class RetryLoggingMiddleware
  def call(worker, job, queue)
    yield
  rescue StandardError => e
    if job['retry']
      retry_count = job.fetch('retry_count', 0)
      Rails.logger.warn("Sidekiq job will be retried", {
        job_class: job['class'],
        job_id: job['jid'],
        queue: queue,
        retry_count: retry_count,
        error_class: e.class.name,
        error_message: e.message
      })
    end
    raise e
  end
end

Sidekiq.configure_client do |config|
  # Client-side configuration (for enqueueing jobs)
  # Ensure jobs are persisted to Redis
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
end
