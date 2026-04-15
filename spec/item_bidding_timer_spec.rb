require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['APP_DB_PATH'] = File.expand_path('../db/test.sqlite3', __dir__)

require_relative '../app'
require 'rack/mock'

RSpec.describe 'Item bidding timer' do
  let(:app) { MyApp.new }
  let(:request) { Rack::MockRequest.new(app) }

  before do
    Bid.delete_all
    PaymentRecord.delete_all
    Item.delete_all
    User.delete_all
    Community.delete_all
    COLLEGE_OPTIONS.each { |name| Community.create!(name: name) }
  end

  def response_cookie(response)
    response['Set-Cookie']&.split(';')&.first
  end

  it 'starts the countdown after the first successful bid' do
    community = Community.find_by!(name: 'New Asia College')
    user = User.new(name: 'Bidder', email: 'bidder@example.com', role: 'student', community: community)
    user.password = 'password123'
    user.save!

    item = Item.create!(
      name: 'Timer Item',
      description: 'Countdown starts on first bid',
      price: 90,
      category: 'Electronics',
      college: 'New Asia College',
      available: true,
      ends_at: nil
    )

    login_response = request.post('/login', params: { email: 'bidder@example.com', password: 'password123' })
    bid_response = request.post(
      "/items/#{item.id}/bids",
      { 'HTTP_COOKIE' => response_cookie(login_response), params: { bid: { amount: '120' } } }
    )

    expect(bid_response.status).to eq(303)
    expect(bid_response['Location']).to include("/items/#{item.id}?notice=Bid+placed+successfully")

    item.reload
    expect(item.status).to eq(Item::STATUS_RESERVED)
    expect(item.available).to eq(false)
    expect(item.ends_at).not_to be_nil

    detail_response = request.get("/items/#{item.id}", 'HTTP_COOKIE' => response_cookie(login_response))

    expect(detail_response.status).to eq(200)
    expect(detail_response.body).to include('Time Left')
    expect(detail_response.body).to include('Reserved')
    expect(detail_response.body).to include('auction-countdown')
    expect(detail_response.body).to include(item.ends_at.iso8601)
  end

  it 'returns a reserved item back to available after the timer expires' do
    item = Item.create!(
      name: 'Expired Reservation',
      description: 'Should reopen after timeout',
      price: 110,
      category: 'Electronics',
      college: 'New Asia College',
      available: false,
      status: Item::STATUS_RESERVED,
      ends_at: Time.now - 60
    )

    detail_response = request.get("/items/#{item.id}")

    expect(detail_response.status).to eq(200)

    item.reload
    expect(item.status).to eq(Item::STATUS_AVAILABLE)
    expect(item.available).to eq(true)
    expect(item.ends_at).to be_nil
    expect(detail_response.body).to include('Available')
    expect(detail_response.body).to include('Starts after the first bid')
  end

  it 'marks the item as sold after successful payment completion' do
    item = Item.create!(
      name: 'Paid Item',
      description: 'Becomes sold after payment',
      price: 140,
      category: 'Electronics',
      college: 'New Asia College',
      available: false,
      status: Item::STATUS_RESERVED,
      ends_at: Time.now + 600
    )

    PaymentRecord.create!(
      item: item,
      amount_cents: 14_000,
      currency: 'usd',
      status: :pending,
      stripe_payment_intent_id: 'pi_complete'
    )

    payment_intent = instance_double('Stripe::PaymentIntent', status: 'succeeded', id: 'pi_complete')
    allow(Stripe::PaymentIntent).to receive(:retrieve).with('pi_complete').and_return(payment_intent)

    complete_response = request.post(
      "/payments/#{item.id}/complete_payment",
      'CONTENT_TYPE' => 'application/json',
      input: { payment_intent_id: 'pi_complete' }.to_json
    )

    expect(complete_response.status).to eq(200)

    item.reload
    expect(item.status).to eq(Item::STATUS_SOLD)
    expect(item.available).to eq(false)
    expect(item.ends_at).to be_nil
  end
end