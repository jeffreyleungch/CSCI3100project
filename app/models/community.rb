class Community < ApplicationRecord
  has_many :users
  has_many :auctions

  validates :name, presence: true
end
