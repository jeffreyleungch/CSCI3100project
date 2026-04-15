
# Rails App Patch (Codespaces friendly)

Run this **inside your Codespaces terminal** (repo root):

```bash
bash scripts/setup_marketplace.sh marketplace
```

This will:
1. Install `bundler` & `rails` if missing
2. Create a Rails 7 app in `./marketplace`
3. Add required gems: `sidekiq`, `redis`, `rspec-rails`, `simplecov`, and **BDD stack** (`cucumber-rails`, `capybara`, `database_cleaner-active_record`)
4. Copy all provided app/ config/ spec/ CI files into the Rails app
5. Generate Cucumber config and a sample `features/bidding.feature` (steps are `pending` placeholders for you to implement)

## After script
```bash
cd marketplace
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec --format documentation
bundle exec cucumber
```

## Open PR
```bash
git checkout -b feature/rt-bids-sidekiq-garrick
git add marketplace .github
git commit -m "Rails app + ActionCable + Sidekiq + CI coverage + BDD skeleton"
git push -u origin feature/rt-bids-sidekiq-garrick
```

CI (GitHub Actions) will run RSpec (coverage ≥85%) + Cucumber.
