require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['APP_DB_PATH'] = File.expand_path('../db/test.sqlite3', __dir__)

require_relative '../app'
require 'rack/mock'

RSpec.describe 'Item search' do
  let(:request) { Rack::MockRequest.new(MyApp.new) }

  before do
    Bid.delete_all
    PaymentRecord.delete_all
    Item.delete_all
  end

  it 'filters items by keyword, category, and college' do
    Item.create!(
      name: 'iPad Air',
      description: 'Tablet in great condition',
      price: 400,
      category: 'Electronics',
      college: 'New Asia College',
      available: true
    )

    Item.create!(
      name: 'Desk Lamp',
      description: 'Warm reading light',
      price: 30,
      category: 'Home & Furniture',
      college: 'Shaw College',
      available: true
    )

    response = request.get('/items/search?query=ipad&category=Electronics&college=New+Asia+College')

    expect(response.status).to eq(200)
    expect(response.body).to include('iPad Air')
    expect(response.body).not_to include('Desk Lamp')
    expect(response.body).to include('All categories')
    expect(response.body).to include('All colleges')
  end
end