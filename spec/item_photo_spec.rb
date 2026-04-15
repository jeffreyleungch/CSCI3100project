require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['APP_DB_PATH'] = File.expand_path('../db/test.sqlite3', __dir__)

require_relative '../app'
require 'rack/mock'

RSpec.describe 'Item photos' do
  let(:request) { Rack::MockRequest.new(MyApp.new) }

  before do
    Bid.delete_all
    PaymentRecord.delete_all
    Item.delete_all
  end

  it 'renders uploaded image paths in item list and detail pages' do
    item = Item.create!(
      name: 'Camera',
      description: 'Mirrorless body',
      price: 850,
      category: 'Electronics',
      college: 'New Asia College',
      available: true,
      image_path: 'uploads/items/sample-camera.png'
    )

    list_response = request.get('/items')
    detail_response = request.get("/items/#{item.id}")

    expect(list_response.status).to eq(200)
    expect(list_response.body).to include('sample-camera.png')
    expect(list_response.body).to include('<img')

    expect(detail_response.status).to eq(200)
    expect(detail_response.body).to include('sample-camera.png')
    expect(detail_response.body).to include('Camera photo')
  end

  it 'shows timer instructions before the first bid' do
    item = Item.create!(
      name: 'Auction Clock',
      description: 'Has a visible timer',
      price: 120,
      category: 'Electronics',
      college: 'New Asia College',
      available: true
    )

    detail_response = request.get("/items/#{item.id}")

    expect(detail_response.status).to eq(200)
    expect(detail_response.body).to include('Starts after the first bid')
    expect(detail_response.body).not_to include('auction-countdown')
  end
end