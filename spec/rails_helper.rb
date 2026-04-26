require 'spec_helper'
require 'active_job'
require 'active_record'
require 'active_support/all'
require 'database_cleaner/active_record'
require 'factory_bot'
require 'active_job/test_helper'

# Connect to in-memory SQLite3 database for testing
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Define ApplicationRecord base class
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class ApplicationJob < ActiveJob::Base
end

module Rails
  def self.application
    @application ||= Struct.new(:config).new(Struct.new(:to_prepare).new(->(&block) { block.call }))
  end
end

module TestBroadcastStore
  class << self
    def add(channel_class, target, payload)
      broadcasts << {
        channel_class: channel_class,
        target: target,
        payload: payload
      }
    end

    def broadcasts
      @broadcasts ||= []
    end

    def clear
      broadcasts.clear
    end
  end
end

module ApplicationCable
  class Channel
    attr_reader :params, :current_user, :transmissions

    def initialize(params: {}, current_user: nil)
      @params = params.with_indifferent_access
      @current_user = current_user
      @rejected = false
      @transmissions = []
      @streams = []
    end

    def self.broadcast_to(target, payload)
      TestBroadcastStore.add(self, target, payload)
    end

    def self.broadcasts
      TestBroadcastStore.broadcasts.select { |entry| entry[:channel_class] == self }
    end

    def stream_for(target)
      @streams << target
    end

    def transmit(payload)
      @transmissions << payload
    end

    def reject
      @rejected = true
    end

    def rejected?
      @rejected
    end
  end
end

# Create test schema
ActiveRecord::Schema.define do
  create_table :items, force: true do |t|
    t.string  :name
    t.string  :category
    t.text    :description
    t.decimal :price, precision: 10, scale: 2
    t.boolean :available, default: true
    t.timestamps
  end

  create_table :communities, force: true do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :email, null: false
    t.string :password
    t.references :community, null: false
    t.timestamps
  end

  create_table :auctions, force: true do |t|
    t.references :community, null: false
    t.integer :status, null: false, default: 0
    t.datetime :ends_at, null: false
    t.timestamps
  end

  create_table :bids, force: true do |t|
    t.references :auction, null: false
    t.references :user, null: false
    t.integer :amount_cents, null: false
    t.timestamps
  end

  create_table :payment_records, force: true do |t|
    t.references :auction, null: false
    t.references :user, null: false
    t.integer :amount_cents, null: false
    t.integer :status, null: false, default: 0
    t.timestamps
  end
end

# Load application classes
require_relative '../app/models/item'
require_relative '../app/models/concerns/auction_scheduler'
require_relative '../app/models/concerns/auction'
require_relative '../app/models/concerns/broadcasts_auction_updates'
Dir[File.expand_path('../app/jobs/*.rb', __dir__)].sort.each do |job_file|
  require job_file
end
require_relative '../app/channels/auction_channel'

Dir[File.expand_path('factories/*.rb', __dir__)].sort.each do |factory_file|
  require factory_file
end

class Community < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :auctions, dependent: :destroy
end

class User < ApplicationRecord
  belongs_to :community
  has_many :bids, dependent: :destroy
  has_many :payment_records, dependent: :destroy
end

class Bid < ApplicationRecord
  include BroadcastsAuctionUpdates

  belongs_to :auction
  belongs_to :user
end

class PaymentRecord < ApplicationRecord
  belongs_to :auction
  belongs_to :user

  enum :status, { pending: 0, paid: 1 }
end

Auction.class_eval do
  belongs_to :community
  has_many :bids, dependent: :destroy
  has_many :payment_records, dependent: :destroy
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
    TestBroadcastStore.clear
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end
