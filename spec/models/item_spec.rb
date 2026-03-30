require 'rails_helper'

RSpec.describe Item, type: :model do
  describe '.search_by_fulltext' do
    it 'returns items that match the search query' do
      item1 = Item.create!(name: 'Apple', description: 'Fresh fruit', category: 'Fruit')
      item2 = Item.create!(name: 'Banana', description: 'Yellow fruit', category: 'Fruit')

      expect(Item.search_by_fulltext('Apple')).to include(item1)
      expect(Item.search_by_fulltext('Apple')).not_to include(item2)
    end

    it 'returns an empty relation when no items match the query' do
      expect(Item.search_by_fulltext('NonExistingItem')).to be_empty
    end
  end

  describe '.filter_by_category' do
    it 'returns items that match the given category' do
      item1 = Item.create!(name: 'Apple', category: 'Fruit')
      item2 = Item.create!(name: 'Carrot', category: 'Vegetable')

      expect(Item.filter_by_category('Fruit')).to include(item1)
      expect(Item.filter_by_category('Fruit')).not_to include(item2)
    end

    it 'returns all items when category is blank' do
      item1 = Item.create!(name: 'Apple', category: 'Fruit')
      item2 = Item.create!(name: 'Carrot', category: 'Vegetable')

      expect(Item.filter_by_category('')).to include(item1, item2)
    end
  end

  describe '.filter_by_price_range' do
    it 'returns items within the given price range' do
      item1 = Item.create!(name: 'Apple', price: 0.50)
      item2 = Item.create!(name: 'Banana', price: 5.00)

      expect(Item.filter_by_price_range(0.10, 1.00)).to include(item1)
      expect(Item.filter_by_price_range(0.10, 1.00)).not_to include(item2)
    end
  end

  describe '.sorted_by' do
    it 'sorts items by price in ascending order' do
      item1 = Item.create!(name: 'Banana', price: 1.00)
      item2 = Item.create!(name: 'Apple', price: 0.50)

      expect(Item.sorted_by('price')).to eq([item2, item1])
    end

    it 'sorts items by name in alphabetical order' do
      item1 = Item.create!(name: 'Banana')
      item2 = Item.create!(name: 'Apple')

      expect(Item.sorted_by('name')).to eq([item2, item1])
    end
  end
end
