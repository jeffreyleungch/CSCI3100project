
require 'spec_helper'
require 'rails_helper'

RSpec.describe Bid, type: :model do
  it 'broadcasts snapshot on create' do
    auction = create(:auction, status: :running)
    expect {
      create(:bid, auction: auction, amount_cents: 1000)
    }.to have_broadcasted_to(auction).from_channel(AuctionChannel)
  end
end
