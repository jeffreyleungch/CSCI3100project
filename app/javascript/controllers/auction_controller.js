
import { Controller } from "@hotwired/stimulus"
import { subscribeAuction } from "../channels/auction_channel"

export default class extends Controller {
  static values = { auctionId: Number, endsAt: String }

  connect() {
    this.subscription = subscribeAuction(this.auctionIdValue, (data) => {
      if (data.type === "snapshot") this.renderState(data)
      if (data.type === "closed") this.showClosed(data)
    })
    this.startCountdown()
  }

  disconnect() { this.subscription?.unsubscribe() }

  startCountdown() {
    const el = this.element.querySelector("[data-target='countdown']")
    const endsAt = new Date(this.endsAtValue)
    const tick = () => {
      const delta = Math.max(0, endsAt - new Date())
      const s = Math.floor(delta / 1000)
      const m = Math.floor(s / 60), ss = s % 60
      if (el) el.textContent = `${m}:${ss.toString().padStart(2,'0')}`
      if (delta > 0) this._timer = setTimeout(tick, 250)
    }
    tick()
  }

  renderState(data) {
    const el = this.element.querySelector("[data-target='highest']")
    if (el) el.textContent = (data.highest_bid_cents/100.0).toFixed(2)
  }

  showClosed() {
    const s = this.element.querySelector("[data-target='status']")
    if (s) s.textContent = "Closed"
  }
}
