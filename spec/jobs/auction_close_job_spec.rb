
require 'spec_helper'
require 'rails_helper'

RSpec.describe AuctionCloseJob, type: :job do
  describe "successful auction closure" do
    it 'closes auction and creates payment record' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      create(:bid, auction: auction, amount_cents: 5000)

      expect {
        described_class.perform_now(auction.id)
      }.to change { auction.reload.status }.from('running').to('closed')
       .and change(PaymentRecord, :count).by(1)
    end

    it 'selects highest bid as winner' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      user1 = create(:user)
      user2 = create(:user)
      
      create(:bid, auction: auction, user: user1, amount_cents: 5000)
      create(:bid, auction: auction, user: user2, amount_cents: 7500)

      described_class.perform_now(auction.id)

      payment = PaymentRecord.last
      expect(payment.user).to eq(user2)
      expect(payment.amount_cents).to eq(7500)
    end

    it 'handles tie-breaking by first bidder on same amount' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      user1 = create(:user)
      user2 = create(:user)
      
      bid1 = create(:bid, auction: auction, user: user1, amount_cents: 5000)
      create(:bid, auction: auction, user: user2, amount_cents: 5000)

      described_class.perform_now(auction.id)

      payment = PaymentRecord.last
      expect(payment.user).to eq(user1)  # First bidder with same amount wins
    end

    it 'broadcasts auction closure' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      user = create(:user)
      create(:bid, auction: auction, user: user, amount_cents: 5000)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "closed",
          auction_id: auction.id,
          winner_user_id: user.id,
          highest_bid_cents: 5000
        )
      )

      described_class.perform_now(auction.id)
    end

    it 'triggers PaymentPromptJob for winner' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      create(:bid, auction: auction, amount_cents: 5000)

      expect(PaymentPromptJob).to receive(:perform_later)

      described_class.perform_now(auction.id)
    end
  end

  describe "edge cases" do
    it 'auction with no bids still closes' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)

      expect {
        described_class.perform_now(auction.id)
      }.to change { auction.reload.status }.from('running').to('closed')
    end

    it 'auction with no bids creates no payment record' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)

      expect {
        described_class.perform_now(auction.id)
      }.not_to change(PaymentRecord, :count)
    end

    it 'does not close auction if time has not reached ends_at' do
      auction = create(:auction, ends_at: 1.hour.from_now, status: :running)
      create(:bid, auction: auction, amount_cents: 5000)

      expect {
        described_class.perform_now(auction.id)
      }.not_to change { auction.reload.status }
    end

    it 'does not close already closed auction (idempotent)' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :closed)
      create(:bid, auction: auction, amount_cents: 5000)

      expect {
        described_class.perform_now(auction.id)
      }.not_to change(PaymentRecord, :count)

      expect(auction.reload.status).to eq('closed')
    end

    it 'handles non-existent auction gracefully' do
      expect {
        described_class.perform_now(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'logs auction closure with details' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      user = create(:user)
      create(:bid, auction: auction, user: user, amount_cents: 5000)

      expect(Rails.logger).to receive(:info).with("Auction closed successfully", hash_including(
        auction_id: auction.id,
        winner_user_id: user.id,
        highest_bid_cents: 5000,
        no_bids: false
      ))

      described_class.perform_now(auction.id)
    end

    it 'logs when auction already closed (idempotency)' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :closed)

      expect(Rails.logger).to receive(:info).with("Auction already closed", hash_including(
        auction_id: auction.id
      ))

      described_class.perform_now(auction.id)
    end

    it 'logs when close time not yet reached' do
      auction = create(:auction, ends_at: 1.hour.from_now, status: :running)

      expect(Rails.logger).to receive(:info).with(
        "Auction close time not yet reached",
        hash_including(auction_id: auction.id)
      )

      described_class.perform_now(auction.id)
    end

    it 'handles PaymentPromptJob enqueue failure gracefully' do
      auction = create(:auction, ends_at: 1.minute.ago, status: :running)
      create(:bid, auction: auction, amount_cents: 5000)

      allow(PaymentPromptJob).to receive(:perform_later).and_raise(StandardError.new("Enqueue failed"))

      expect(Rails.logger).to receive(:error).with(
        "Failed to enqueue PaymentPromptJob",
        hash_including(auction_id: auction.id)
      )

      # Should not raise - auction is already closed
      expect {
        described_class.perform_now(auction.id)
      }.not_to raise_error

      # But auction should still be closed
      expect(auction.reload.status).to eq('closed')
    end
  end
end
