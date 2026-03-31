# Mailer for auction winners - sends payment prompts and receipts
#
# Methods:
# - payment_prompt: Sent after auction closes (from PaymentPromptJob)
#   Subject: "Action Required: Complete Your Payment for #<auction_id>"
#   Content: Winner congratulations, amount due, payment deadline, link to pay
#
# - receipt: Sent after payment confirmed (from PaymentReceiptEmailJob)
#   Subject: "Payment Confirmed - Receipt for Auction #<auction_id>"
#   Content: Order confirmation, amount paid, date, next steps
#
# Templates:
# - app/views/winner_mailer/payment_prompt.html.erb
# - app/views/winner_mailer/payment_prompt.text.erb
# - app/views/winner_mailer/receipt.html.erb
# - app/views/winner_mailer/receipt.text.erb
#
# Configuration:
# - From: configured in application_mailer (env: MAIL_FROM)
# - Delivery: deliver_later (async via Sidekiq)
#
class WinnerMailer < ApplicationMailer
  default from: 'noreply@auction.example.com'

  # Sends payment prompt to auction winner after auction closes
  def payment_prompt
    @payment_record = params[:payment_record]
    @auction = @payment_record.auction
    @user = @payment_record.user
    @amount_cents = @payment_record.amount_cents
    @amount_dollars = @amount_cents / 100.0

    mail(
      to: @user.email,
      subject: "Action Required: Complete Your Payment for #{@auction.id}"
    )
  end

  # Sends receipt confirmation to winner after payment completed
  def receipt
    @payment_record = params[:payment_record]
    @auction = @payment_record.auction
    @user = @payment_record.user
    @amount_cents = @payment_record.amount_cents
    @amount_dollars = @amount_cents / 100.0

    mail(
      to: @user.email,
      subject: "Payment Confirmed - Receipt for Auction #{@auction.id}"
    )
  end
end
