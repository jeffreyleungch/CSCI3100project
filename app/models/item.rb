class Item < ApplicationRecord
  has_many :bids, dependent: :destroy

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

  scope :filter_by_price_range, ->(min_price, max_price) {
    where(price: min_price..max_price) if min_price.present? && max_price.present?
  }

  scope :sorted_by, ->(sort_param = 'created_at') {
    order(sort_param) 
  }

  def highest_bid
    bids.order(amount: :desc, created_at: :asc).first
  end
end
