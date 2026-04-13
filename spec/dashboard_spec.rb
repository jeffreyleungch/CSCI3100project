require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['APP_DB_PATH'] = File.expand_path('../db/test.sqlite3', __dir__)

require_relative '../app'
require 'rack/mock'

RSpec.describe 'Dashboard' do
  let(:request) { Rack::MockRequest.new(MyApp.new) }

  before do
    Bid.delete_all
    PaymentRecord.delete_all
    Item.delete_all
  end

  it 'renders KPI metrics and chart sections' do
    item_one = Item.create!(name: 'Laptop', description: 'M2 MacBook', price: 900, category: 'Electronics', available: true, created_at: Time.utc(2026, 4, 10, 10))
    item_two = Item.create!(name: 'Chair', description: 'Desk chair', price: 120, category: 'Furniture', available: false, created_at: Time.utc(2026, 4, 11, 9))

    Bid.create!(item: item_one, bidder_name: 'Aaron', amount: 950, created_at: Time.utc(2026, 4, 10, 12))
    Bid.create!(item: item_one, bidder_name: 'Chris', amount: 980, created_at: Time.utc(2026, 4, 11, 12))

    PaymentRecord.create!(item: item_one, amount_cents: 98000, currency: 'usd', status: :completed, stripe_payment_intent_id: 'pi_complete', created_at: Time.utc(2026, 4, 11, 15))
    PaymentRecord.create!(item: item_two, amount_cents: 12000, currency: 'usd', status: :failed, stripe_payment_intent_id: 'pi_failed', created_at: Time.utc(2026, 4, 12, 15))

    response = request.get('/dashboard')

    expect(response.status).to eq(200)
    expect(response.body).to include('Marketplace analytics dashboard')
    expect(response.body).to include('Total listings')
    expect(response.body).to include('$980.00')
    expect(response.body).to include('Completion rate 50.0%')
    expect(response.body).to include('Listings by category')
    expect(response.body).to include('cdn.jsdelivr.net/npm/chart.js')
  end
end