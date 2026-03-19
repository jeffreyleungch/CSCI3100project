
require 'spec_helper'
require 'rails_helper'

RSpec.describe AuctionChannel, type: :channel do
  it 'rejects user from other community' do
    auction = create(:auction, community: create(:community))
    user = create(:user, community: create(:community))
    stub_connection current_user: user
    subscribe(auction_id: auction.id)
    expect(subscription).to be_rejected
  end
end
