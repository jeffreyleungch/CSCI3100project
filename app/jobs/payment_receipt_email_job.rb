# Sends payment receipt and confirmation emails after payment confirmed
#
# Responsibilities:
# - Validates payment_record is confirmed or completed
# - Validates winner has email address
# - Sends receipt email to auction winner
# - Sends payment_received email to auction seller (if seller exists with email)
# - Broadcasts payment_received notification to auction participants
# - Gracefully handles seller email failures (logs but doesn't block)
#
# Idempotency: Only processes confirmed/completed records; skips pending
# Status: :default queue
# Triggered by: PaymentRecord status change or manual call
# Alternative: Can be auto-triggered by after_update callback on PaymentRecord
#
# Email Templates:
# - Winner: "Payment Confirmed - Receipt for Auction #<auction_id>"
#   Content: Order details, amount paid, next steps
# - Seller: "Payment Received - Order Confirmation"
#   Content: Buyer info, sale amount, request to prepare item
#
# Error Handling:
# - Missing winner email: Logged as warning, skipped
# - Missing seller: No email sent, logged
# - Missing seller email: No email sent, logged
# - Seller mailer error: Logged as error, gracefully degraded (doesn't block)
# - Winner mailer error: Logged as error, re-raised for Sidekiq retry
#
# Example:
#   payment_record = PaymentRecord.find(id)
#   PaymentReceiptEmailJob.perform_later(payment_record.id)
#
class PaymentReceiptEmailJob < ApplicationJob
  queue_as :default

  def perform(payment_record_id)
    payment_record = PaymentRecord.find(payment_record_id)
    
    # Only process confirmed or completed payment records
    unless payment_record.confirmed? || payment_record.completed?
      Rails.logger.info("Payment record not ready for receipt, skipping", {
        payment_record_id: payment_record.id,
        status: payment_record.status
      })
      return
    end

    auction = payment_record.auction
    winner = payment_record.user

    # Validate winner email before sending
    unless winner.email.present?
      Rails.logger.warn("Winner missing email address", {
        payment_record_id: payment_record.id,
        user_id: winner.id,
        auction_id: auction.id
      })
      return
    end

    # Send receipt to winner
    begin
      WinnerMailer.with(payment_record: payment_record).receipt.deliver_later
      Rails.logger.info("Receipt email queued for winner", {
        payment_record_id: payment_record.id,
        user_id: winner.id,
        user_email: winner.email
      })
    rescue StandardError => e
      Rails.logger.error("Failed to queue receipt email for winner", {
        payment_record_id: payment_record.id,
        user_id: winner.id,
        error: e.message
      })
      raise e
    end

    # Send seller notification if seller mailer exists and seller has email
    if auction.seller&.email.present?
      begin
        SellerMailer.with(auction: auction, payment_record: payment_record).payment_received.deliver_later
        Rails.logger.info("Receipt email queued for seller", {
          payment_record_id: payment_record.id,
          seller_id: auction.seller.id,
          seller_email: auction.seller.email
        })
      rescue StandardError => e
        Rails.logger.error("Failed to queue receipt email for seller", {
          payment_record_id: payment_record.id,
          seller_id: auction.seller&.id,
          error: e.message
        })
        # Don't raise - winner receipt is more important
      end
    end

    # Broadcast payment completion to auction participants
    AuctionChannel.broadcast_to(auction, {
      type: "payment_received",
      auction_id: auction.id,
      user_id: winner.id,
      amount_cents: payment_record.amount_cents
    })
  end
end
