# Sends payment prompt email to auction winner after auction closes
#
# Responsibilities:
# - Validates payment_record is in pending status
# - Validates winner has email address (prevents silent failures)
# - Sends payment prompt email via WinnerMailer
# - Broadcasts payment_prompt notification to auction participants
# - Handles mailer failures with error logging and re-raise
#
# Idempotency: Only processes pending records; skips confirmed/completed
# Status: :default queue
# Triggered by: AuctionCloseJob (after auction closes)
#
# Email Template:
# - Subject: "Action Required: Complete Your Payment for #<auction_id>"
# - Content: Amount, deadline, payment link, CTAssistant
#
# Error Handling:
# - Missing email: Logged as warning, email skipped
# - Mailer error: Logged as error, job re-raises for Sidekiq retry
#
# Example:
#   payment_record = PaymentRecord.find(id)
#   PaymentPromptJob.perform_later(payment_record.id)
#
class PaymentPromptJob < ApplicationJob
  queue_as :default

  def perform(payment_record_id)
    payment_record = PaymentRecord.find(payment_record_id)
    
    # Only process pending payment records
    unless payment_record.pending?
      Rails.logger.info("Payment record not pending, skipping", {
        payment_record_id: payment_record.id,
        status: payment_record.status
      })
      return
    end

    user = payment_record.user
    
    # Validate email before sending
    unless user.email.present?
      Rails.logger.warn("User missing email address", {
        payment_record_id: payment_record.id,
        user_id: user.id,
        auction_id: payment_record.auction_id
      })
      return
    end

    # Send payment prompt to winner
    begin
      WinnerMailer.with(payment_record: payment_record).payment_prompt.deliver_later
      Rails.logger.info("Payment prompt email queued", {
        payment_record_id: payment_record.id,
        user_id: user.id,
        user_email: user.email
      })
    rescue StandardError => e
      Rails.logger.error("Failed to queue payment prompt email", {
        payment_record_id: payment_record.id,
        user_id: user.id,
        error: e.message
      })
      raise e
    end

    # Broadcast payment reminder to the auction's participants
    AuctionChannel.broadcast_to(payment_record.auction, {
      type: "payment_prompt",
      auction_id: payment_record.auction_id,
      user_id: payment_record.user_id,
      amount_cents: payment_record.amount_cents
    })
  end
end
