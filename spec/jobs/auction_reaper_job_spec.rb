require 'spec_helper'
require 'rails_helper'

RSpec.describe AuctionReaperJob, type: :job do
  it 'closes missed running auctions' do
    # Auction that ended 1 hour ago but is still running
    missed_auction = create(:auction, ends_at: 1.hour.ago, status: :running)
    create(:bid, auction: missed_auction, amount_cents: 5000)

    expect {
      described_class.perform_now
    }.to change { missed_auction.reload.status }.from('running').to('closed')
  end

  it 'creates payment record for missed auction with winning bid' do
    missed_auction = create(:auction, ends_at: 1.hour.ago, status: :running)
    create(:bid, auction: missed_auction, amount_cents: 5000)

    expect {
      described_class.perform_now
    }.to change(PaymentRecord, :count).by(1)
  end

  it 'ignores already closed auctions' do
    closed_auction = create(:auction, ends_at: 1.hour.ago, status: :closed)
    create(:bid, auction: closed_auction, amount_cents: 5000)

    expect {
      described_class.perform_now
    }.not_to change(PaymentRecord, :count)
  end

  it 'handles multiple missed auctions' do
    missed_auction_1 = create(:auction, ends_at: 2.hours.ago, status: :running)
    missed_auction_2 = create(:auction, ends_at: 1.hour.ago, status: :running)
    create(:bid, auction: missed_auction_1, amount_cents: 5000)
    create(:bid, auction: missed_auction_2, amount_cents: 3000)

    expect {
      described_class.perform_now
    }.to change(PaymentRecord, :count).by(2)
     .and change { missed_auction_1.reload.status }.to('closed')
     .and change { missed_auction_2.reload.status }.to('closed')
  end

  it 'ignores running auctions that have not ended' do
    future_auction = create(:auction, ends_at: 30.minutes.from_now, status: :running)
    create(:bid, auction: future_auction, amount_cents: 5000)

    expect {
      described_class.perform_now
    }.not_to change(PaymentRecord, :count)
  end

  it 'closes auction without bids' do
    missed_auction = create(:auction, ends_at: 1.hour.ago, status: :running)

    expect {
      described_class.perform_now
    }.to change { missed_auction.reload.status }.from('running').to('closed')
  end

  it 'broadcasts auction closure to channel' do
    missed_auction = create(:auction, ends_at: 1.hour.ago, status: :running)
    create(:bid, auction: missed_auction, amount_cents: 5000)

    expect(AuctionChannel).to receive(:broadcast_to).with(
      missed_auction,
      hash_including(
        type: "closed",
        auction_id: missed_auction.id,
        reason: "reaped_from_downtime"
      )
    )

    described_class.perform_now
  end

  it 'schedules payment prompt for winner' do
    missed_auction = create(:auction, ends_at: 1.hour.ago, status: :running)
    winner = create(:user)
    create(:bid, auction: missed_auction, user: winner, amount_cents: 5000)

    expect(PaymentPromptJob).to receive(:perform_later).with(kind_of(Integer))

    described_class.perform_now
  end
end
