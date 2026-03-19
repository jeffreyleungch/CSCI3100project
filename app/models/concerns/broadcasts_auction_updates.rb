
module BroadcastsAuctionUpdates
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_update, on: :create
    validate :amount_must_exceed_highest
  end

  private

  def amount_must_exceed_highest
    return unless auction
    max = auction.bids.maximum(:amount_cents).to_i
    errors.add(:amount_cents, 'must exceed current highest') if amount_cents.to_i <= max
  end

  def broadcast_update
    AuctionChannel.broadcast_to(auction, {
      type: 'snapshot',
      auction_id: auction.id,
      highest_bid_cents: auction.bids.maximum(:amount_cents),
      ends_at_iso: auction.ends_at.iso8601,
      status: auction.status
    })
  end
end
