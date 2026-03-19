
class AuctionCloseJob < ApplicationJob
  queue_as :critical

  def perform(auction_id)
    auction = Auction.lock.find(auction_id)
    return if auction.closed? || Time.current < auction.ends_at

    winner_bid = auction.bids.order(amount_cents: :desc, created_at: :asc).first

    Auction.transaction do
      auction.update!(status: :closed)
      if winner_bid
        PaymentRecord.create!(
          auction: auction,
          user: winner_bid.user,
          amount_cents: winner_bid.amount_cents,
          status: :pending
        )
      end
    end

    AuctionChannel.broadcast_to(auction, {
      type: "closed",
      auction_id: auction.id,
      winner_user_id: winner_bid&.user_id,
      highest_bid_cents: winner_bid&.amount_cents
    })

    if winner_bid && defined?(WinnerMailer)
      WinnerMailer.with(bid: winner_bid).payment_prompt.deliver_later
    end
  end
end
