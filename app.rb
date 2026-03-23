require 'sinatra'
require 'active_record'
require 'rack/utils'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: File.expand_path('db/development.sqlite3', __dir__)
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

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

require_relative 'app/models/item'
require_relative 'app/models/bid'

class MyApp < Sinatra::Base
  set :views, File.expand_path('app/views', __dir__)
  set :host_authorization, { permitted_hosts: [] }

  helpers do
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def number_to_currency(value)
      return '$0.00' if value.nil?

      format('$%.2f', value.to_f)
    end

    def format_datetime(value)
      return '-' if value.nil?

      value.strftime('%Y-%m-%d %H:%M:%S')
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

  get '/items/:id' do
    @item = Item.find(params['id'])
    @bids = @item.bids.order(amount: :desc, created_at: :asc)
    @highest_bid = @bids.first
    erb :'items/show'
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