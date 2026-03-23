
require 'spec_helper'
require 'rails_helper'

RSpec.describe Bid, type: :model do
  it 'broadcasts snapshot on create' do
    auction = create(:auction, status: :running)
    create(:bid, auction: auction, amount_cents: 1000)

    broadcast = AuctionChannel.broadcasts.last
    expect(broadcast).not_to be_nil
    expect(broadcast[:target]).to eq(auction)
    expect(broadcast[:payload]).to include(
      type: 'snapshot',
      auction_id: auction.id,
      highest_bid_cents: 1000,
      status: 'running'
    )
  end
end
