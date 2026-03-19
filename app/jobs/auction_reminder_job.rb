
class AuctionReminderJob < ApplicationJob
  queue_as :default

  def perform(auction_id)
    auction = Auction.find(auction_id)
    return unless auction.running?

    AuctionChannel.broadcast_to(auction, {
      type: "reminder",
      auction_id: auction.id,
      minutes_left: 15
    })
  end
end
