class Bid < ApplicationRecord
  belongs_to :item

  validates :amount, numericality: { greater_than: 0 }
  validates :bidder_name, presence: true
end
