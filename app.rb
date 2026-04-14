require 'sinatra'
require 'active_record'
require 'stripe'
require 'bcrypt'
require 'digest'
require 'fileutils'
require 'rack/utils'
require 'json'
require 'securerandom'

Stripe.api_key = ENV['STRIPE_SECRET_KEY'] if ENV['STRIPE_SECRET_KEY']

CATEGORY_OPTIONS = [
  'Electronics',
  'Home & Furniture',
  'Clothing & Accessories',
  'Books & Media',
  'Sports & Outdoors',
  'Beauty & Personal Care',
  'Toys & Hobbies',
  'Vehicles & Parts',
  'Tickets & Vouchers',
  'Others'
].freeze

COLLEGE_OPTIONS = [
  'Chung Chi College',
  'New Asia College',
  'United College',
  'Shaw College',
  'Morningside College',
  'S.H. Ho College',
  'C.W. Chu College',
  'Wu Yee Sun College',
  'Lee Woo Sing College',
  'Graduate School',
  'Others'
].freeze

environment_name = ENV.fetch('RACK_ENV', 'development')
database_path = ENV.fetch('APP_DB_PATH', File.expand_path("db/#{environment_name}.sqlite3", __dir__))

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: database_path
)

unless ActiveRecord::Base.connection.data_source_exists?('items')
  ActiveRecord::Schema.define do
    create_table :items do |t|
      t.references :user, null: true
      t.string :name
      t.text :description
      t.decimal :price, precision: 10, scale: 2
      t.string :category
      t.string :college
      t.boolean :available, default: true
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.column_exists?(:items, :college)
  ActiveRecord::Schema.define do
    add_column :items, :college, :string
  end
end

unless ActiveRecord::Base.connection.column_exists?(:items, :user_id)
  ActiveRecord::Schema.define do
    add_column :items, :user_id, :integer
    add_index :items, :user_id
  end
end

unless ActiveRecord::Base.connection.column_exists?(:items, :image_path)
  ActiveRecord::Schema.define do
    add_column :items, :image_path, :string
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('communities')
  ActiveRecord::Schema.define do
    create_table :communities do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_index :communities, :name, unique: true
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('users')
  ActiveRecord::Schema.define do
    create_table :users do |t|
      t.references :community, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: 'student'
      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

unless ActiveRecord::Base.connection.column_exists?(:users, :name)
  ActiveRecord::Schema.define do
    add_column :users, :name, :string
  end
end

unless ActiveRecord::Base.connection.column_exists?(:users, :password_digest)
  ActiveRecord::Schema.define do
    add_column :users, :password_digest, :string
  end
end

unless ActiveRecord::Base.connection.column_exists?(:users, :role)
  ActiveRecord::Schema.define do
    add_column :users, :role, :string, default: 'student', null: false
  end
end

unless ActiveRecord::Base.connection.column_exists?(:users, :community_id)
  ActiveRecord::Schema.define do
    add_column :users, :community_id, :integer
    add_index :users, :community_id
  end
end

if ActiveRecord::Base.connection.column_exists?(:users, :password)
  UserMigrationClass = Class.new(ActiveRecord::Base) do
    self.table_name = 'users'
  end

  UserMigrationClass.where(password_digest: [nil, '']).find_each do |legacy_user|
    next if legacy_user[:password].to_s == ''

    legacy_user.update_columns(password_digest: BCrypt::Password.create(legacy_user[:password]))
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('bids')
  ActiveRecord::Schema.define do
    create_table :bids do |t|
      t.references :item, null: false
      t.references :user, null: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :bidder_name, null: false
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.column_exists?(:bids, :user_id)
  ActiveRecord::Schema.define do
    add_column :bids, :user_id, :integer
    add_index :bids, :user_id
  end
end

unless ActiveRecord::Base.connection.data_source_exists?('payment_records')
  ActiveRecord::Schema.define do
    create_table :payment_records do |t|
      t.references :item, null: false
      t.references :user, null: true
      t.integer :amount_cents, null: false
      t.string :currency, default: 'usd', null: false
      t.integer :status, default: 0, null: false
      t.string :stripe_payment_intent_id, null: false
      t.string :payer_email
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.column_exists?(:payment_records, :user_id)
  ActiveRecord::Schema.define do
    add_column :payment_records, :user_id, :integer
    add_index :payment_records, :user_id
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

require_relative 'app/models/item'
require_relative 'app/models/bid'
require_relative 'app/models/payment_record'
require_relative 'app/models/community'
require_relative 'app/models/user'

COLLEGE_OPTIONS.each do |community_name|
  Community.find_or_create_by!(name: community_name)
end

class MyApp < Sinatra::Base
  enable :sessions
  set :views, File.expand_path('app/views', __dir__)
  set :public_folder, File.expand_path('public', __dir__)
  set :host_authorization, { permitted_hosts: [] }

  raw_session_secret = ENV['SESSION_SECRET'].to_s
  normalized_session_secret = if raw_session_secret.length >= 64
                                raw_session_secret
                              elsif raw_session_secret != ''
                                Digest::SHA256.hexdigest(raw_session_secret)
                              else
                                SecureRandom.hex(64)
                              end

  set :session_secret, normalized_session_secret

  helpers do
    def h(text)
      Rack::Utils.escape_html(text.to_s)
    end

    def category_options
      CATEGORY_OPTIONS
    end

    def college_options
      COLLEGE_OPTIONS
    end

    def normalize_category(category)
      value = category.to_s.strip
      return 'Others' if value.empty?

      CATEGORY_OPTIONS.include?(value) ? value : 'Others'
    end

    def normalize_college(college)
      value = college.to_s.strip
      return 'Others' if value.empty?

      COLLEGE_OPTIONS.include?(value) ? value : 'Others'
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

    def item_upload_dir
      File.expand_path('public/uploads/items', __dir__)
    end

    def store_item_image(uploaded_file)
      return [nil, nil] unless uploaded_file.is_a?(Hash)

      tempfile = uploaded_file[:tempfile] || uploaded_file['tempfile']
      original_filename = uploaded_file[:filename] || uploaded_file['filename']
      return [nil, nil] if tempfile.nil? || original_filename.to_s.strip == ''

      extension = File.extname(original_filename.to_s).downcase
      allowed_extensions = %w[.jpg .jpeg .png .gif .webp]
      unless allowed_extensions.include?(extension)
        return [nil, 'Photo must be a JPG, PNG, GIF, or WEBP image.']
      end

      FileUtils.mkdir_p(item_upload_dir)
      stored_filename = "#{SecureRandom.hex(16)}#{extension}"
      stored_path = File.join(item_upload_dir, stored_filename)
      FileUtils.copy(tempfile.path, stored_path)

      [File.join('uploads/items', stored_filename), nil]
    end

    def remove_stored_item_image(relative_path)
      return if relative_path.to_s.strip == ''

      absolute_path = File.expand_path(File.join('public', relative_path), __dir__)
      return unless absolute_path.start_with?(File.expand_path('public/uploads/items', __dir__))
      return unless File.exist?(absolute_path)

      File.delete(absolute_path)
    rescue StandardError
      nil
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

    def filtered_items_scope(query:, category:, college:)
      Item.order(created_at: :desc)
          .search_by_fulltext(query)
          .filter_by_category(category)
          .filter_by_college(college)
          .order(created_at: :desc)
    end

    def communities
      Community.order(:name)
    end

    def current_user
      return @current_user if defined?(@current_user)

      @current_user = User.find_by(id: session[:user_id])
    end

    def logged_in?
      !current_user.nil?
    end

    def moderator?
      current_user&.moderator?
    end

    def admin?
      current_user&.admin?
    end

    def current_role_label
      return 'Guest' unless logged_in?

      current_user.role.capitalize
    end

    def community_name_for(user)
      user&.community&.name.to_s
    end

    def require_login!
      return if logged_in?

      redirect '/login?notice=Please+sign+in+first'
    end

    def require_moderator!
      return if moderator?

      halt 403, 'Moderator access required'
    end
  end

  get '/' do
    redirect '/items'
  end

  get '/register' do
    @user = User.new
    erb :'auth/register'
  end

  post '/register' do
    community = Community.find_by(id: params['community_id'])
    @user = User.new(
      name: params['name'].to_s.strip,
      email: params['email'].to_s.strip.downcase,
      role: 'student',
      community: community
    )
    @user.password = params['password']

    if community.nil?
      @error_message = 'Please select your college/community.'
      return erb :'auth/register'
    end

    if params['password'].to_s.length < 8
      @error_message = 'Password must be at least 8 characters.'
      return erb :'auth/register'
    end

    if @user.save
      session[:user_id] = @user.id
      redirect '/items?notice=Account+created+successfully'
    else
      @error_message = @user.errors.full_messages.join(', ')
      erb :'auth/register'
    end
  end

  get '/login' do
    erb :'auth/login'
  end

  post '/login' do
    user = User.find_by(email: params['email'].to_s.strip.downcase)

    if user&.authenticate(params['password'])
      session[:user_id] = user.id
      redirect '/items?notice=Signed+in+successfully'
    else
      @error_message = 'Invalid email or password.'
      erb :'auth/login'
    end
  end

  post '/logout' do
    session.clear
    redirect '/items?notice=Signed+out+successfully'
  end

  get '/items' do
    @items = Item.order(created_at: :desc)
    erb :'items/index'
  end

  post '/items' do
    require_login!

    item_params = params.fetch('item', {})
    available = item_params['available'] == '1'
    image_path, image_error = store_item_image(item_params['photo'])

    item = Item.new(
      user: current_user,
      name: item_params['name'],
      description: item_params['description'],
      price: item_params['price'],
      category: normalize_category(item_params['category']),
      college: normalize_college(community_name_for(current_user)),
      available: available,
      image_path: image_path
    )

    item.errors.add(:image_path, image_error) if image_error

    if item.save
      redirect '/items?notice=Item+created+successfully'
    else
      remove_stored_item_image(image_path)
      @items = Item.order(created_at: :desc)
      @error_messages = item.errors.full_messages
      erb :'items/index'
    end
  end

  get '/items/search' do
    @items = filtered_items_scope(
      query: params['query'],
      category: params['category'],
      college: params['college']
    )
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
      categories: listings.each_with_object(CATEGORY_OPTIONS.index_with(0)) do |item, counts|
        counts[normalize_category(item.category)] += 1
      end,
      colleges: listings.each_with_object(COLLEGE_OPTIONS.index_with(0)) do |item, counts|
        counts[normalize_college(item.college)] += 1
      end,
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
    require_login!

    @item = Item.find(params['id'])
    bid_params = params.fetch('bid', {})

    bid = @item.bids.build(
      user: current_user,
      amount: bid_params['amount'],
      bidder_name: current_user.name.to_s == '' ? current_user.email : current_user.name
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

  post '/items/:id/delete' do
    require_moderator!

    item = Item.find(params['id'])
    remove_stored_item_image(item.image_path)
    item.destroy
    redirect '/items?notice=Item+removed+by+moderator'
  end
end