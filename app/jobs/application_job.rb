class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encounter a deadlock
  # retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs should retry on standard errors
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Don't retry on these specific errors
  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  # Default queue
  queue_as :default

  # Logging helper for all jobs
  protected

  def audit_log(action, details = {})
    Rails.logger.info("#{self.class.name}: #{action}", {
      job_id: job_id,
      timestamp: Time.current.iso8601,
      **details
    })
  end

  def audit_error(action, error, context = {})
    Rails.logger.error("#{self.class.name}: #{action}", {
      job_id: job_id,
      error_class: error.class.name,
      error_message: error.message,
      timestamp: Time.current.iso8601,
      **context
    })
  end
end
