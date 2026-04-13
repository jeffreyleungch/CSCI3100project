require 'sinatra'
require 'active_record'
require 'stripe'
require 'rack/utils'
require 'json'

Stripe.api_key = ENV['STRIPE_SECRET_KEY'] if ENV['STRIPE_SECRET_KEY']

environment_name = ENV.fetch('RACK_ENV', 'development')
database_path = ENV.fetch('APP_DB_PATH', File.expand_path("db/#{environment_name}.sqlite3", __dir__))

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: database_path
)

unless ActiveRecord::Base.connection.data_source_exists?('items')
  ActiveRecord::Schema.define do
    create_table :items do |t|
      t.string :name
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.string :category
      t.boolean :available, default: true
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('bids')
  ActiveRecord::Schema.define do
    create_table :bids do |t|
      t.references :item, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :bidder_name, null: false
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('payment_records')
  ActiveRecord::Schema.define do
    create_table :payment_records do |t|
      t.references :item, null: false
      t.integer :amount_cents, null: false
      t.string :currency, default: 'usd', null: false
      t.integer :status, default: 0, null: false
      t.string :stripe_payment_intent_id, null: false
      t.string :payer_email
      t.timestamps
    end
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

require_relative 'app/models/item'
require_relative 'app/models/bid'
require_relative 'app/models/payment_record'

class MyApp < Sinatra::Base
  set :views, File.expand_path('app/views', __dir__)
  set :host_authorization, { permitted_hosts: [] }

  helpers do
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def percentage(value)
      format('%.1f%%', value.to_f * 100)
    end

    def number_to_currency(value)
      return '$0.00' if value.nil?

      format('$%.2f', value.to_f)
    end

    def format_datetime(value)
      return '-' if value.nil?

      value.strftime('%Y-%m-%d %H:%M:%S')
    end

    def parse_json_request
      request.body.rewind
      JSON.parse(request.body.read || '{}') rescue {}
    end

    def send_payment_receipt(payment_record)
      if defined?(PaymentReceiptEmailJob)
        begin
          PaymentReceiptEmailJob.perform_later(payment_record.id)
        rescue StandardError => e
          puts "Receipt job failed: #{e.message}"
        end
      else
        puts "Receipt ready for #{payment_record.payer_email}: payment_record=#{payment_record.id}"
      end
    end

    def count_records_by_day(records)
      counts = Hash.new(0)

      records.each do |record|
        counts[record.created_at.strftime('%Y-%m-%d')] += 1
      end

      counts.sort.to_h
    end

    def sum_records_by_day(records, value_method)
      sums = Hash.new(0)

      records.each do |record|
        sums[record.created_at.strftime('%Y-%m-%d')] += record.public_send(value_method).to_i
      end

      sums.sort.to_h
    end
  end

  get '/' do
    redirect '/items'
  end

  get '/items' do
    @items = Item.order(created_at: :desc)
    erb :'items/index'
  end

  post '/items' do
    item_params = params.fetch('item', {})
    available = item_params['available'] == '1'

    item = Item.new(
      name: item_params['name'],
      description: item_params['description'],
      price: item_params['price'],
      category: item_params['category'],
      available: available
    )

    if item.save
      redirect '/items?notice=Item+created+successfully'
    else
      @items = Item.order(created_at: :desc)
      @error_messages = item.errors.full_messages
      erb :'items/index'
    end
  end

  get '/items/search' do
    @items = Item.search_by_fulltext(params['query']).order(created_at: :desc)
    erb :'items/index'
  end

  get '/dashboard' do
    listings = Item.order(:created_at).to_a
    bids = Bid.order(:created_at).to_a
    payments = PaymentRecord.order(:created_at).to_a
    completed_payments = payments.select(&:completed?)
    items_with_bids = bids.map(&:item_id).uniq.count
    total_listings = listings.count
    total_bids = bids.count
    total_payments = payments.count
    completed_payment_count = completed_payments.count
    total_gmv_cents = completed_payments.sum { |payment| payment.amount_cents.to_i }

    @kpis = {
      total_listings: total_listings,
      available_listings: listings.count(&:available),
      total_bids: total_bids,
      completed_payments: completed_payment_count,
      total_gmv: total_gmv_cents / 100.0,
      average_sale_value: completed_payment_count.zero? ? 0 : (total_gmv_cents / 100.0) / completed_payment_count,
      average_bids_per_item: total_listings.zero? ? 0 : total_bids.to_f / total_listings,
      bid_coverage_rate: total_listings.zero? ? 0 : items_with_bids.to_f / total_listings,
      payment_completion_rate: total_payments.zero? ? 0 : completed_payment_count.to_f / total_payments
    }

    @chart_data = {
      listings_by_day: count_records_by_day(listings),
      bids_by_day: count_records_by_day(bids),
      gmv_by_day: sum_records_by_day(completed_payments, :amount_cents).transform_values { |amount| amount / 100.0 },
      categories: listings.each_with_object(Hash.new(0)) do |item, counts|
        key = item.category.to_s.strip.empty? ? 'Uncategorized' : item.category
        counts[key] += 1
      end.sort.to_h,
      payment_statuses: PaymentRecord.statuses.keys.each_with_object({}) do |status_name, counts|
        counts[status_name.capitalize] = payments.count { |payment| payment.status == status_name }
      end
    }

    erb :dashboard
  end

  get '/items/:id' do
    @item = Item.find(params['id'])
    @bids = @item.bids.order(amount: :desc, created_at: :asc)
    @highest_bid = @bids.first
    erb :'items/show'
  end

  get '/payments/:id' do
    @item = Item.find(params['id'])
    @stripe_publishable_key = ENV.fetch('STRIPE_PUBLISHABLE_KEY', '')
    @stripe_enabled = @stripe_publishable_key.to_s != '' && Stripe.api_key.to_s != ''
    erb :'payments/checkout'
  end

  get '/payments/:id/success' do
    @item = Item.find(params['id'])
    @payment_intent_id = params['payment_intent_id']
    @payment_record = PaymentRecord.find_by(stripe_payment_intent_id: @payment_intent_id)
    erb :'payments/success'
  end

  post '/payments/:id/create_payment_intent' do
    content_type :json
    @item = Item.find(params['id'])
    payload = parse_json_request
    payment_method_id = payload['payment_method_id']
    payer_email = payload['payer_email'] || payload['payerEmail']

    if payment_method_id.to_s.empty?
      status 400
      return({ error: 'Missing payment_method_id' }.to_json)
    end

    unless Stripe.api_key.to_s != ''
      status 500
      return({ error: 'Stripe secret key is not configured' }.to_json)
    end

    begin
      payment_intent = Stripe::PaymentIntent.create(
        amount: (@item.price.to_f * 100).to_i,
        currency: 'usd',
        payment_method: payment_method_id,
        confirmation_method: 'manual',
        confirm: true,
        metadata: {
          item_id: @item.id,
          item_name: @item.name
        }
      )
    rescue Stripe::StripeError => e
      status 402
      return({ error: e.message }.to_json)
    end

    payment_record = PaymentRecord.create!(
      item: @item,
      amount_cents: (@item.price.to_f * 100).to_i,
      currency: 'usd',
      status: payment_intent.status == 'succeeded' ? :completed : :pending,
      stripe_payment_intent_id: payment_intent.id,
      payer_email: payer_email
    )

    send_payment_receipt(payment_record) if payment_record.completed?

    {
      client_secret: payment_intent.client_secret,
      payment_intent_id: payment_intent.id,
      requires_action: payment_intent.status == 'requires_action'
    }.to_json
  end

  post '/payments/:id/complete_payment' do
    content_type :json
    payload = parse_json_request
    payment_intent_id = payload['payment_intent_id']

    if payment_intent_id.to_s.empty?
      status 400
      return({ error: 'Missing payment_intent_id' }.to_json)
    end

    begin
      payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
    rescue Stripe::StripeError => e
      status 402
      return({ error: e.message }.to_json)
    end

    payment_record = PaymentRecord.find_by!(stripe_payment_intent_id: payment_intent.id)
    previous_status = payment_record.status

    new_status = case payment_intent.status
                 when 'succeeded'
                   :completed
                 when 'requires_action'
                   :pending
                 when 'requires_payment_method', 'canceled'
                   :failed
                 else
                   :pending
                 end

    payment_record.update!(status: new_status)
    send_payment_receipt(payment_record) if new_status == :completed && previous_status != 'completed'

    { success: true, status: payment_record.status }.to_json
  end

  post '/items/:id/bids' do
    @item = Item.find(params['id'])
    bid_params = params.fetch('bid', {})

    bid = @item.bids.build(
      amount: bid_params['amount'],
      bidder_name: bid_params['bidder_name']
    )

    current_highest = @item.bids.maximum(:amount).to_f
    if bid.amount.to_f <= current_highest
      bid.errors.add(:amount, 'must be greater than current highest bid')
    end

    if bid.errors.empty? && bid.save
      redirect "/items/#{@item.id}?notice=Bid+placed+successfully"
    else
      @bids = @item.bids.order(amount: :desc, created_at: :asc)
      @highest_bid = @bids.first
      @bid_errors = bid.errors.full_messages
      erb :'items/show'
    end
  end
end