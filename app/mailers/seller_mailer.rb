# Mailer for auction sellers - notifies when payment received
#
# Methods:
# - payment_received: Sent after buyer payment confirmed (from PaymentReceiptEmailJob)
#   Subject: "Payment Received - Order Confirmation"
#   Content: Buyer info, sale amount, timestamp, request to prepare item
#
# Templates:
# - app/views/seller_mailer/payment_received.html.erb
# - app/views/seller_mailer/payment_received.text.erb
#
# Configuration:
# - From: configured in application_mailer (env: MAIL_FROM)
# - Recipient: auction.seller.email (if seller exists with email)
# - Delivery: deliver_later (async via Sidekiq)
#
# Note: Seller is optional on Auction model (added via migration 20260331000005)
#
class SellerMailer < ApplicationMailer
  default from: 'noreply@auction.example.com'

  # Notifies seller that payment was received from winner
  def payment_received
    @auction = params[:auction]
    @payment_record = params[:payment_record]
    @user = @payment_record.user
    @amount_cents = @payment_record.amount_cents
    @amount_dollars = @amount_cents / 100.0

    # Note: This assumes Auction has a seller association
    # If not implemented, add: belongs_to :seller, class_name: 'User'
    seller_email = @auction.seller&.email || Rails.application.config.admin_email
    
    mail(
      to: seller_email,
      subject: "Payment Received - Auction #{@auction.id} Completed"
    )
  end
end
