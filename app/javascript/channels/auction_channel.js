
import consumer from "../channels/consumer"

export function subscribeAuction(auctionId, onUpdate) {
  const channel = consumer.subscriptions.create(
    { channel: "AuctionChannel", auction_id: auctionId },
    {
      received(data) { onUpdate?.(data) },
      connected() {},
      disconnected() {}
    }
  )
  return channel
}
