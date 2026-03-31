require 'spec_helper'
require 'rails_helper'

RSpec.describe PaymentPromptJob, type: :job do
  describe "successful payment prompt" do
    it 'sends payment prompt for pending payment record' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(WinnerMailer).to receive_message_chain(:with, :payment_prompt, :deliver_later)

      described_class.perform_now(payment_record.id)
    end

    it 'broadcasts payment prompt to auction channel' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "payment_prompt",
          auction_id: auction.id,
          user_id: user.id,
          amount_cents: payment_record.amount_cents
        )
      )

      described_class.perform_now(payment_record.id)
    end

    it 'logs payment prompt email queued' do
      auction = create(:auction, status: :closed)
      user = create(:user, email: 'winner@example.com')
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(Rails.logger).to receive(:info).with("Payment prompt email queued", hash_including(
        payment_record_id: payment_record.id,
        user_id: user.id,
        user_email: 'winner@example.com'
      ))

      described_class.perform_now(payment_record.id)
    end
  end

  describe "status and validation checks" do
    it 'does not process non-pending payment records' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :confirmed)

      expect(WinnerMailer).not_to receive(:with)
      expect(Rails.logger).to receive(:info).with("Payment record not pending, skipping", hash_including(
        status: 'confirmed'
      ))

      described_class.perform_now(payment_record.id)
    end

    it 'skips if user email is missing' do
      auction = create(:auction, status: :closed)
      user = create(:user, email: nil)
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(WinnerMailer).not_to receive(:with)
      expect(Rails.logger).to receive(:warn).with("User missing email address", hash_including(
        payment_record_id: payment_record.id,
        user_id: user.id
      ))

      described_class.perform_now(payment_record.id)
    end

    it 'skips if user email is blank string' do
      auction = create(:auction, status: :closed)
      user = create(:user, email: '')
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      expect(WinnerMailer).not_to receive(:with)
      expect(Rails.logger).to receive(:warn).with("User missing email address", anything)

      described_class.perform_now(payment_record.id)
    end
  end

  describe "error handling" do
    it 'handles missing payment record gracefully' do
      expect {
        described_class.perform_now(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'logs and re-raises mailer errors' do
      auction = create(:auction, status: :closed)
      user = create(:user)
      payment_record = create(:payment_record, auction: auction, user: user, status: :pending)

      allow(WinnerMailer).to receive(:with).and_raise(StandardError.new("Mail service down"))

      expect(Rails.logger).to receive(:error).with("Failed to queue payment prompt email", hash_including(
        payment_record_id: payment_record.id
      ))

      expect {
        described_class.perform_now(payment_record.id)
      }.to raise_error(StandardError, "Mail service down")
    end
  end
end
