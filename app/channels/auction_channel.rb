
class AuctionChannel < ApplicationCable::Channel
  def subscribed
    @auction = Auction.find(params[:auction_id])
    reject unless current_user&.community_id == @auction.community_id
    stream_for @auction
    transmit snapshot_payload(@auction)
  end

  def place_bid(data)
    Auction.transaction do
      auction = Auction.lock.find(data["auction_id"]) # server authority
      return transmit(error: "Auction closed") unless auction.running?

      bid = auction.bids.build(user: current_user, amount_cents: data["amount_cents"])
      if bid.save
        broadcast_snapshot!(auction)
      else
        transmit(error: bid.errors.full_messages.to_sentence)
      end
    end
  end

  private

  def snapshot_payload(auction)
    {
      type: "snapshot",
      auction_id: auction.id,
      highest_bid_cents: auction.bids.maximum(:amount_cents) || 0,
      ends_at_iso: auction.ends_at.iso8601,
      status: auction.status
    }
  end

  def broadcast_snapshot!(auction)
    AuctionChannel.broadcast_to(auction, snapshot_payload(auction))
  end
end
