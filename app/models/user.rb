class User < ApplicationRecord
  belongs_to :community
  has_many :bids
  has_many :payment_records

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true
end
