
# Closes auctions when their end_time arrives
#
# Responsibilities:
# - Atomically closes auction status from :running to :closed
# - Selects highest bid as the winner (by amount DESC, created_at ASC)
# - Creates PaymentRecord for winning bid with pending status
# - Broadcasts closure to auction participants via ActionCable
# - Triggers PaymentPromptJob to notify winner about payment
#
# Idempotency: Safe to retry multiple times - checks if already closed
# Status: :critical queue (high priority)
# Triggered by: AuctionScheduler (scheduled at auction.ends_at)
#
# Example:
#   AuctionCloseJob.perform_later(auction.id)
#   # or scheduled by:
#   AuctionCloseJob.set(wait_until: auction.ends_at).perform_later(auction.id)
#
class AuctionCloseJob < ApplicationJob
  queue_as :critical

  def perform(auction_id)
    auction = Auction.lock.find(auction_id)
    
    # Idempotency check
    if auction.closed?
      Rails.logger.info("Auction already closed", { auction_id: auction.id })
      return
    end

    # Check if close time has arrived
    if Time.current < auction.ends_at
      Rails.logger.info("Auction close time not yet reached", {
        auction_id: auction.id,
        ends_at: auction.ends_at.iso8601,
        current_time: Time.current.iso8601
      })
      return
    end

    winner_bid = auction.bids.order(amount_cents: :desc, created_at: :asc).first

    payment_record = nil
    begin
      Auction.transaction do
        auction.update!(status: :closed)
        if winner_bid
          payment_record = PaymentRecord.create!(
            auction: auction,
            user: winner_bid.user,
            amount_cents: winner_bid.amount_cents,
            status: :pending
          )
        end
      end

      Rails.logger.info("Auction closed successfully", {
        auction_id: auction.id,
        winner_user_id: winner_bid&.user_id,
        highest_bid_cents: winner_bid&.amount_cents,
        no_bids: winner_bid.nil?,
        timestamp: Time.current.iso8601
      })
    rescue StandardError => e
      Rails.logger.error("Failed to close auction", {
        auction_id: auction.id,
        error: e.message,
        backtrace: e.backtrace.first(5)
      })
      raise e
    end

    AuctionChannel.broadcast_to(auction, {
      type: "closed",
      auction_id: auction.id,
      winner_user_id: winner_bid&.user_id,
      highest_bid_cents: winner_bid&.amount_cents
    })

    # Trigger payment prompt job for the winner
    if payment_record
      begin
        PaymentPromptJob.perform_later(payment_record.id)
      rescue StandardError => e
        Rails.logger.error("Failed to enqueue PaymentPromptJob", {
          auction_id: auction.id,
          payment_record_id: payment_record.id,
          error: e.message
        })
        # Don't raise - auction is already closed
      end
    end
  end
end
