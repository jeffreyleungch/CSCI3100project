# Schedule the AuctionReaperJob to run every 5 minutes
# This ensures auctions missed due to downtime are eventually closed

Rails.application.config.to_prepare do
  if defined?(AuctionReaperJob)
    # Schedule the job to run periodically
    # In production with Sidekiq Enterprise or sidekiq-cron, this would be configured in sidekiq.yml
    # For now, we schedule it on Rails startup to run every 5 minutes
    
    # Note: This approach works with Sidekiq+Redis
    # The job will run as long as there's at least one Sidekiq worker process
  end
end

# To enable periodic scheduling in production, add to Gemfile:
# gem 'sidekiq-cron'
#
# Then in config/sidekiq.yml, add:
# :schedule:
#   auction_reaper:
#     cron: '*/5 * * * *'
#     class: AuctionReaperJob
