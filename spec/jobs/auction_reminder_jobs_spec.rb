require 'spec_helper'
require 'rails_helper'

RSpec.describe "Auction Reminder Jobs", type: :job do
  describe Auction24HourReminderJob do
    it 'broadcasts 24-hour reminder to auction channel' do
      auction = create(:auction, ends_at: 24.hours.from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "reminder",
          auction_id: auction.id,
          reminder_type: "24_hour",
          hours_left: 24
        )
      )

      described_class.perform_now(auction.id)
    end

    it 'does not send reminder if auction is not running' do
      auction = create(:auction, ends_at: 24.hours.from_now, status: :closed)

      expect(AuctionChannel).not_to receive(:broadcast_to)
      described_class.perform_now(auction.id)
    end

    it 'calculates actual minutes remaining' do
      auction = create(:auction, ends_at: (23.hours + 30.minutes).from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(minutes_left: (23.5 * 60).to_i)
      )

      described_class.perform_now(auction.id)
    end
  end

  describe Auction1HourReminderJob do
    it 'broadcasts 1-hour reminder to auction channel' do
      auction = create(:auction, ends_at: 1.hour.from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "reminder",
          auction_id: auction.id,
          reminder_type: "1_hour"
        )
      )

      described_class.perform_now(auction.id)
    end

    it 'does not send reminder if auction is not running' do
      auction = create(:auction, ends_at: 1.hour.from_now, status: :closed)

      expect(AuctionChannel).not_to receive(:broadcast_to)
      described_class.perform_now(auction.id)
    end

    it 'calculates actual minutes remaining' do
      auction = create(:auction, ends_at: 59.minutes.from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(minutes_left: 59)
      )

      described_class.perform_now(auction.id)
    end
  end

  describe AuctionReminderJob do
    it 'broadcasts 15-minute reminder to auction channel' do
      auction = create(:auction, ends_at: 15.minutes.from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(
          type: "reminder",
          auction_id: auction.id,
          reminder_type: "15_minute"
        )
      )

      described_class.perform_now(auction.id)
    end

    it 'does not send reminder if auction is not running' do
      auction = create(:auction, ends_at: 15.minutes.from_now, status: :closed)

      expect(AuctionChannel).not_to receive(:broadcast_to)
      described_class.perform_now(auction.id)
    end

    it 'calculates actual minutes remaining' do
      auction = create(:auction, ends_at: 14.minutes.from_now, status: :running)

      expect(AuctionChannel).to receive(:broadcast_to).with(
        auction,
        hash_including(minutes_left: 14)
      )

      described_class.perform_now(auction.id)
    end
  end
end
