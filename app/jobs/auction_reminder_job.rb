
class AuctionReminderJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find(auction_id)
    return unless auction.running?

    AuctionChannel.broadcast_to(auction, {
      type: "reminder",
      auction_id: auction.id,
      minutes_left: AuctionConfig::REMINDER_MINUTES_BEFORE_END.to_i / 60
    })
  end
end
