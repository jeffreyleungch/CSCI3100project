
module AuctionScheduler
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_close_job, if: :saved_change_to_ends_at?
    after_commit :schedule_reminders, on: :create
  end

  def schedule_close_job
    AuctionCloseJob.set(wait_until: ends_at).perform_later(id)
  end

  def schedule_reminders
    t = ends_at - AuctionConfig::REMINDER_MINUTES_BEFORE_END
    AuctionReminderJob.set(wait_until: t).perform_later(id) if t > Time.current
  end
end
