class Item < ApplicationRecord
  # Assuming a fulltext index is created on :name and :description fields
  scope :search_by_fulltext, ->(query) {
    where("MATCH(name, description) AGAINST(?)", query)
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
end
