# Safety job that closes auctions missed due to downtime or failures
#
# Responsibilities:
# - Finds all running auctions past their end_time
# - Closes each missed auction with atomic transaction
# - Creates PaymentRecord for highest bid if one exists
# - Broadcasts closure with reason: "reaped_from_downtime"
# - Triggers PaymentPromptJob for winners
#
# Usage:
# - Run periodically via cron or Sidekiq scheduler
# - Recommended frequency: every 5 minutes
# - Complements AuctionCloseJob for downtime resilience
#
# Idempotency: Checks if auction already closed before processing
# Status: :critical queue (high priority)
#
# Setup with Sidekiq Cron (gem 'sidekiq-cron'):
#   :schedule:
#     auction_reaper:
#       cron: '*/5 * * * *'  # Every 5 minutes
#       class: AuctionReaperJob
#
class AuctionReaperJob < ApplicationJob
  queue_as :critical

  # This job should be scheduled to run periodically (e.g., every 5 minutes)
  # to catch auctions that were missed due to downtime or failures

  def perform
    # Find all auctions that should have been closed but are still running
    missed_auctions = Auction
      .where(status: :running)
      .where('ends_at < ?', Time.current)

    missed_auctions.each do |auction|
      close_auction(auction)
    end
  end

  private

  def close_auction(auction)
    return if auction.closed?

    # Find the highest bid
    winner_bid = auction.bids
      .order(amount_cents: :desc, created_at: :asc)
      .first

    # Atomically close the auction and create payment record
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

    # Broadcast closure
    AuctionChannel.broadcast_to(auction, {
      type: "closed",
      auction_id: auction.id,
      winner_user_id: winner_bid&.user_id,
      highest_bid_cents: winner_bid&.amount_cents,
      reason: "reaped_from_downtime"
    })

    # Trigger payment prompt for the winner if there was a bid
    if winner_bid
      PaymentPromptJob.perform_later(auction.payment_records.first.id)
    end
  end
end
