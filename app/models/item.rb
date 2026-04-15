class Item < ApplicationRecord
  STATUS_AVAILABLE = 'available'
  STATUS_RESERVED = 'reserved'
  STATUS_SOLD = 'sold'
  STATUSES = [STATUS_AVAILABLE, STATUS_RESERVED, STATUS_SOLD].freeze

  belongs_to :user, optional: true
  has_many :bids, dependent: :destroy
  has_many :payment_records, dependent: :destroy

  validates :image_path, length: { maximum: 255 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }, allow_blank: true

  scope :search_by_fulltext, ->(query) {
    next all if query.blank?

    adapter_name = connection_db_config.adapter.to_s.downcase
    if adapter_name.include?('sqlite')
      escaped_query = ActiveRecord::Base.sanitize_sql_like(query.to_s)
      where('name LIKE :query OR description LIKE :query', query: "%#{escaped_query}%")
    else
      where('MATCH(name, description) AGAINST(?)', query)
    end
  }

  scope :filter_by_category, ->(category) {
    where(category: category) if category.present?
  }

  scope :filter_by_college, ->(college) {
    where(college: college) if college.present?
  }

  scope :filter_by_price_range, ->(min_price, max_price) {
    where(price: min_price..max_price) if min_price.present? && max_price.present?
  }

  scope :sorted_by, ->(sort_param = 'created_at') {
    order(sort_param) 
  }

  def highest_bid
    bids.order(amount: :desc, created_at: :asc).first
  end

  def available_status?
    status.to_s == STATUS_AVAILABLE
  end

  def reserved?
    status.to_s == STATUS_RESERVED
  end

  def sold?
    status.to_s == STATUS_SOLD
  end

  def status_label
    status.to_s.strip == '' ? 'Unknown' : status.to_s.capitalize
  end

  def has_image?
    image_path.to_s != ''
  end

  def image_url
    return nil unless has_image?

    "/#{image_path}"
  end
end
