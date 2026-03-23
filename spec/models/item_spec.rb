require 'rails_helper'

RSpec.describe Item, type: :model do
  describe '.search' do
    it 'returns items that match the search query' do
      item1 = Item.create!(name: 'Apple', category: 'Fruit')
      item2 = Item.create!(name: 'Banana', category: 'Fruit')

      expect(Item.search('Apple')).to include(item1)
      expect(Item.search('Apple')).not_to include(item2)
    end

    it 'returns an empty array when no items match the query' do
      expect(Item.search('NonExistingItem')).to be_empty
    end
  end

  describe '.filter' do
    it 'returns items that match the given category' do
      item1 = Item.create!(name: 'Apple', category: 'Fruit')
      item2 = Item.create!(name: 'Carrot', category: 'Vegetable')

      expect(Item.filter(category: 'Fruit')).to include(item1)
      expect(Item.filter(category: 'Fruit')).not_to include(item2)
    end

    it 'returns items that match multiple filters' do
      item1 = Item.create!(name: 'Apple', category: 'Fruit', available: true)
      item2 = Item.create!(name: 'Banana', category: 'Fruit', available: false)

      expect(Item.filter(category: 'Fruit', available: true)).to include(item1)
      expect(Item.filter(category: 'Fruit', available: true)).not_to include(item2)
    end
  end

  describe '.sort' do
    it 'sorts items by price in ascending order' do
      item1 = Item.create!(name: 'Banana', price: 1.00)
      item2 = Item.create!(name: 'Apple', price: 0.50)

      expect(Item.sort_by_price).to eq([item2, item1])
    end

    it 'sorts items by name in alphabetical order' do
      item1 = Item.create!(name: 'Banana')
      item2 = Item.create!(name: 'Apple')

      expect(Item.sort_by_name).to eq([item2, item1])
    end
  end
end
