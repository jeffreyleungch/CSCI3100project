
require 'spec_helper'
require 'rails_helper'

RSpec.describe AuctionChannel, type: :channel do
  it 'rejects user from other community' do
    auction = create(:auction, community: create(:community))
    user = create(:user, community: create(:community))

    channel = described_class.new(
      params: { auction_id: auction.id },
      current_user: user
    )

    channel.subscribed

    expect(channel.rejected?).to be(true)
  end
end
