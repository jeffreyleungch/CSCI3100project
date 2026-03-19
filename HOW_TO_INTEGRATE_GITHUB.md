
# How to integrate this PR into your GitHub repo
3. **Wire the concern into `Auction`:**
   ```ruby
   # app/models/auction.rb
   class Auction < ApplicationRecord
     include AuctionScheduler
     enum status: { scheduled: 0, running: 1, closed: 2 }
   end
   ```

4. **Gemfile updates** (append if missing):
   ```ruby
   gem 'redis', '~> 5.0'
   gem 'sidekiq', '~> 7.2'
   gem 'rspec-rails', '~> 6.1'
   gem 'simplecov', require: false
   ```
   Then run:
   ```bash
   bundle install
   ```

5. **Local test run**:
   ```bash
   redis-server &
   bundle exec sidekiq -C config/sidekiq.yml &
   RAILS_ENV=test bundle exec rails db:prepare
   bundle exec rspec
   ```
   Expect coverage **>=85%**. If not, add/adjust specs before pushing.

6. **Commit & push**:
   ```bash
   git add .
   git commit -m "Real-time bids (ActionCable) + Sidekiq jobs + CI coverage"
   git push -u origin feature/rt-bids-sidekiq-garrick
   ```

7. **Open a Pull Request** on GitHub and paste the content from `PR_DESCRIPTION.md`.

8. **Branch protection (recommended)**: In GitHub → Settings → Branches → Add rule for `main` to require the CI checks before merging.

**Notes:**
- If your `rails_helper.rb` already exists and loads Rails before `spec_helper`, ensure `spec_helper` (with SimpleCov) is required **first** in your specs (as done in the new spec files) so coverage counts all files.
- If your factories are different, update the specs to use your factory names/traits.
- For production, set `REDIS_URL` and `config.action_cable.allowed_request_origins` for your domains.
