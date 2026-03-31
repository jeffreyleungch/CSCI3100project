# Auction Reminder Jobs
# Sends three timed reminders before auction closes: 24h, 1h, 15min
# Each job calculates actual time remaining and broadcasts to participants

module AuctionReminderJobs
  # Shared helper to broadcast and log reminders
  def self.send_reminder(auction, reminder_type, highlight_value = nil)
    minutes_left = ((auction.ends_at - Time.current) / 60).to_i

    payload = {
      type: "reminder",
      auction_id: auction.id,
      minutes_left: minutes_left,
      reminder_type: reminder_type
    }

    # Add human-readable time value if provided
    payload.merge!(highlight_value) if highlight_value

    AuctionChannel.broadcast_to(auction, payload)

    Rails.logger.info("Auction reminder sent", {
      auction_id: auction.id,
      reminder_type: reminder_type,
      minutes_left: minutes_left,
      timestamp: Time.current.iso8601
    })
  end
end

# Sends 24-hour reminder before auction closes
class Auction24HourReminderJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find(auction_id)
    return unless auction.running?

    AuctionReminderJobs.send_reminder(auction, "24_hour", hours_left: 24)
  end
end

# Sends 1-hour reminder before auction closes
class Auction1HourReminderJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find(auction_id)
    return unless auction.running?

    AuctionReminderJobs.send_reminder(auction, "1_hour")
  end
end

# Sends 15-minute reminder before auction closes
class AuctionReminderJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find(auction_id)
    return unless auction.running?

    AuctionReminderJobs.send_reminder(auction, "15_minute")
  end
end
 