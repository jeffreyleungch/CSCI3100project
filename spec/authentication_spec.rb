require 'spec_helper'

ENV['RACK_ENV'] = 'test'
ENV['APP_DB_PATH'] = File.expand_path('../db/test.sqlite3', __dir__)

require_relative '../app'
require 'rack/mock'

RSpec.describe 'Authentication and roles' do
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

  it 'registers a student account and signs the user in' do
    community = Community.find_by!(name: 'New Asia College')

    response = request.post('/register', params: {
      name: 'Aaron',
      email: 'aaron@example.com',
      password: 'securepass',
      community_id: community.id
    })

    expect(response.status).to eq(303)
    expect(response['Location']).to include('/items?notice=Account+created+successfully')

    follow_up = request.get('/items', 'HTTP_COOKIE' => response_cookie(response))
    expect(follow_up.body).to include('Signed in as')
    expect(follow_up.body).to include('Aaron')
    expect(User.find_by(email: 'aaron@example.com')&.role).to eq('student')
  end

  it 'allows any visitor to access dashboard' do
    community = Community.find_by!(name: 'Chung Chi College')
    student = User.new(name: 'Student', email: 'student@example.com', role: 'student', community: community)
    student.password = 'password123'
    student.save!

    response = request.get('/dashboard')

    expect(response.status).to eq(200)
    expect(response.body).to include('Marketplace analytics dashboard')
  end

  it 'allows a moderator to access dashboard and remove items' do
    community = Community.find_by!(name: 'United College')
    moderator = User.new(name: 'Mod', email: 'mod@example.com', role: 'moderator', community: community)
    moderator.password = 'password123'
    moderator.save!

    item = Item.create!(name: 'Old Desk', description: 'Needs pickup', price: 30, category: 'Home & Furniture', college: 'United College', available: true)

    login_response = request.post('/login', params: { email: 'mod@example.com', password: 'password123' })

    dashboard = request.get('/dashboard', 'HTTP_COOKIE' => response_cookie(login_response))
    expect(dashboard.status).to eq(200)

    delete_response = request.post("/items/#{item.id}/delete", 'HTTP_COOKIE' => response_cookie(login_response))
    expect(delete_response.status).to eq(303)
    expect(Item.find_by(id: item.id)).to be_nil
  end

  it 'requires login before creating an item' do
    response = request.post('/items', params: {
      item: {
        name: 'Camera',
        description: 'Mirrorless camera',
        price: '800',
        category: 'Electronics',
        available: '1'
      }
    })

    expect(response.status).to eq(303)
    expect(response['Location']).to include('/login?notice=Please+sign+in+first')
  end

  it 'allows a logged-in user to browse items from other colleges' do
    buyer_community = Community.find_by!(name: 'New Asia College')
    seller_community = Community.find_by!(name: 'United College')

    buyer = User.new(name: 'Buyer', email: 'buyer@example.com', role: 'student', community: buyer_community)
    buyer.password = 'password123'
    buyer.save!

    seller = User.new(name: 'Seller', email: 'seller@example.com', role: 'student', community: seller_community)
    seller.password = 'password123'
    seller.save!

    Item.create!(
      user: seller,
      name: 'Gaming Monitor',
      description: '27 inch display',
      price: 180,
      category: 'Electronics',
      college: 'United College',
      available: true
    )

    login_response = request.post('/login', params: { email: 'buyer@example.com', password: 'password123' })
    response = request.get('/items', 'HTTP_COOKIE' => response_cookie(login_response))

    expect(response.status).to eq(200)
    expect(response.body).to include('Gaming Monitor')
    expect(response.body).to include('United College')
  end
end