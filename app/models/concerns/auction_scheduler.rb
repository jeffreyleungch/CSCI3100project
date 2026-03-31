
module AuctionScheduler
  extend ActiveSupport::Concern

  included do
    after_commit :schedule_close_job, if: :saved_change_to_ends_at?
    after_commit :schedule_reminders, on: :create
    after_commit :reschedule_reminders, if: :saved_change_to_ends_at?
  end

  def schedule_close_job
    AuctionCloseJob.set(wait_until: ends_at).perform_later(id)
  end

  def schedule_reminders
    schedule_24_hour_reminder
    schedule_1_hour_reminder
    schedule_15_minute_reminder
  end

  def reschedule_reminders
    # Previous reminders will harmlessly execute and find auction not running
    # Schedule new ones with updated times
    schedule_24_hour_reminder
    schedule_1_hour_reminder
    schedule_15_minute_reminder
  end

  private

  def schedule_24_hour_reminder
    t = ends_at - 24.hours
    if t > Time.current
      Auction24HourReminderJob.set(wait_until: t).perform_later(id)
      Rails.logger.info("Scheduled 24-hour reminder", { auction_id: id, scheduled_for: t.iso8601 })
    end
  end

  def schedule_1_hour_reminder
    t = ends_at - 1.hour
    if t > Time.current
      Auction1HourReminderJob.set(wait_until: t).perform_later(id)
      Rails.logger.info("Scheduled 1-hour reminder", { auction_id: id, scheduled_for: t.iso8601 })
    end
  end

  def schedule_15_minute_reminder
    t = ends_at - 15.minutes
    if t > Time.current
      AuctionReminderJob.set(wait_until: t).perform_later(id)
      Rails.logger.info("Scheduled 15-minute reminder", { auction_id: id, scheduled_for: t.iso8601 })
    end
  end
end
