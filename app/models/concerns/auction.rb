class Auction < ApplicationRecord
  include AuctionScheduler

  belongs_to :community
  belongs_to :seller, class_name: 'User', optional: true
  has_many :bids, dependent: :destroy
  has_many :payment_records, dependent: :destroy

  enum :status, { scheduled: 0, running: 1, closed: 2 }

  scope :missed, -> { where(status: :running).where('ends_at < ?', Time.current) }

  def closed?
    status == 'closed'
  end

  def running?
    status == 'running'
  end
end