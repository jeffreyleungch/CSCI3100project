require 'spec_helper'
require 'rails_helper'

RSpec.describe PaymentReceiptEmailJob, type: :job do
  describe "successful receipt sent" do
    it 'sends receipt for confirmed payment record' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      expect(WinnerMailer).to receive_message_chain(:with, :receipt, :deliver_later)

      described_class.perform_now(payment_record.id)
    end

    it 'sends receipt for completed payment record' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :completed)

      expect(WinnerMailer).to receive_message_chain(:with, :receipt, :deliver_later)

      described_class.perform_now(payment_record.id)
    end

    it 'broadcasts payment received to auction channel' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "payment_received",
          auction_id: auction.id,
          user_id: user.id,
          amount_cents: payment_record.amount_cents
        )
      )

      described_class.perform_now(payment_record.id)
    end

    it 'logs receipt email queued' do
      auction = create(:auction, status: :closed)
      user = create(:user, email: 'winner@example.com')
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      expect(Rails.logger).to receive(:info).with("Receipt email queued for winner", hash_including(
        payment_record_id: payment_record.id,
        user_id: user.id,
        user_email: 'winner@example.com'
      ))

      described_class.perform_now(payment_record.id)
    end
  end

  describe "seller notifications" do
    it 'sends seller notification if seller exists with email' do
      seller = create(:user, email: 'seller@example.com')
      auction = create(:auction, status: :closed, seller: seller)
      buyer = create(:user)
      payment_record = create(:payment_record, auction: auction, user: buyer, status: :confirmed)

      expect(SellerMailer).to receive_message_chain(:with, :payment_received, :deliver_later)

      described_class.perform_now(payment_record.id)
    end

    it 'logs seller notification queued' do
      seller = create(:user, email: 'seller@example.com')
      auction = create(:auction, status: :closed, seller: seller)
      buyer = create(:user)
      payment_record = create(:payment_record, auction: auction, user: buyer, status: :confirmed)

      expect(Rails.logger).to receive(:info).with("Receipt email queued for seller", hash_including(
        seller_id: seller.id,
        seller_email: 'seller@example.com'
      ))

      described_class.perform_now(payment_record.id)
    end

    it 'does not send seller notification if seller missing' do
      auction = create(:auction, status: :closed, seller: nil)
      buyer = create(:user)
      payment_record = create(:payment_record, auction: auction, user: buyer, status: :confirmed)

      expect(SellerMailer).not_to receive(:with)

      described_class.perform_now(payment_record.id)
    end

    it 'does not send seller notification if seller email missing' do
      seller = create(:user, email: nil)
      auction = create(:auction, status: :closed, seller: seller)
      buyer = create(:user)
      payment_record = create(:payment_record, auction: auction, user: buyer, status: :confirmed)

      expect(SellerMailer).not_to receive(:with)

      described_class.perform_now(payment_record.id)
    end

    it 'logs and handles seller mailer failures gracefully' do
      seller = create(:user, email: 'seller@example.com')
      auction = create(:auction, status: :closed, seller: seller)
      buyer = create(:user)
      payment_record = create(:payment_record, auction: auction, user: buyer, status: :confirmed)

      allow(SellerMailer).to receive(:with).and_raise(StandardError.new("Seller mail failed"))

      expect(Rails.logger).to receive(:error).with("Failed to queue receipt email for seller", anything)

      # Should not raise - buyer receipt is more important
      expect {
        described_class.perform_now(payment_record.id)
      }.not_to raise_error
    end
  end

  describe "status and validation checks" do
    it 'does not process pending payment records' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(WinnerMailer).not_to receive(:with)

      described_class.perform_now(payment_record.id)
    end

    it 'skips if winner email is missing' do
      auction = create(:auction, status: :closed)
      user = create(:user, email: nil)
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      expect(WinnerMailer).not_to receive(:with)
      expect(Rails.logger).to receive(:warn).with("Winner missing email address", anything)

      described_class.perform_now(payment_record.id)
    end
  end

  describe "error handling" do
    it 'handles missing payment record gracefully' do
      expect {
        described_class.perform_now(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'logs and re-raises winner mailer errors' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      allow(WinnerMailer).to receive(:with).and_raise(StandardError.new("Winner mail failed"))

      expect(Rails.logger).to receive(:error).with("Failed to queue receipt email for winner", anything)

      expect {
        described_class.perform_now(payment_record.id)
      }.to raise_error(StandardError, "Winner mail failed")
    end
  end
end
