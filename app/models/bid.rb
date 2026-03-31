class Bid < ApplicationRecord
  belongs_to :auction
  belongs_to :user
  belongs_to :item, optional: true

  include BroadcastsAuctionUpdates

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :user_id, presence: true
end
