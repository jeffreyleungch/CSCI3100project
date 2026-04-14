class Bid < ApplicationRecord
  belongs_to :item
  belongs_to :user, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :bidder_name, presence: true
end
