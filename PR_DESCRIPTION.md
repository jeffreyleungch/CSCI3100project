
# Real-time Bidding (ActionCable) + Background Jobs (Sidekiq) + CI Coverage

**Owner:** Garrick Lai (Real-time primary, Background Jobs secondary)

## Summary
This PR implements the real-time auction updates using ActionCable and the background job pipeline using Sidekiq. It also adds unit/channel/job specs and configures SimpleCov to enforce **>=85%** coverage (branch coverage enabled). A GitHub Actions workflow is included to run RuboCop, RSpec, and Cucumber, with Redis service for ActionCable/Sidekiq tests.

## Changes
- **ActionCable**: `AuctionChannel` with community-scoped authorization and server-authoritative snapshots.
- **Background Jobs**: `AuctionCloseJob` (idempotent) and `AuctionReminderJob` (T−15m broadcast).
- **Model hooks**: Scheduling callbacks in `Auction`.
- **Client JS**: subscription helper and Stimulus controller for countdown and live updates.
- **Specs**: channel, model, and job specs to ensure behavior and boost coverage.
- **Coverage**: SimpleCov setup with **minimum_coverage 85** (+branch coverage); ActiveJob test adapter in specs.
- **CI**: `.github/workflows/ci.yml` running lint + tests using Redis service.

## Rationale
- Meets feature ownership: real-time bid updates and auction close/reminder jobs.
- Ensures reliability via DB row locking and job idempotency.
- Enforces test quality through coverage threshold and CI.

## Implementation notes
- **Server-authoritative**: new subscribers receive a snapshot of the auction state (highest bid, ends_at, status).
- **Idempotent close**: `AuctionCloseJob` uses a row lock and status guard; safe to retry.
- **Monetary safety**: all amounts in cents.
- **Tenant safety**: only users in the same `community_id` can subscribe.

## Config/ENV
- `REDIS_URL` must be set in production. Dev defaults to `redis://localhost:6379/1`.
- ActionCable allowed origins should include your staging/prod domains.

## Test plan
1. Start dev services (`redis-server`, `bundle exec sidekiq`, `bin/rails s`).
2. Create a running auction ending within ~10 minutes; open two sessions as users in the same community.
3. Place bids; both sessions should update highest bid instantly; countdown should tick.
4. Wait for close or run `AuctionCloseJob.perform_now(auction.id)`; auction closes and broadcasts `closed`.
5. Run `bundle exec rspec`; verify coverage >=85%.

## Screenshots / GIFs
_(Attach once verified locally)_

## Risks & mitigations
- **Merge conflicts on models**: callbacks added to `Auction`; if your model differs, adjust method names/enum.
- **Spec loader order**: Specs `require 'spec_helper'` first to start SimpleCov early.

## Checklist
- [ ] CI green (RuboCop, RSpec, Cucumber)
- [ ] Coverage >= 85%
- [ ] Staging tested with multiple clients
- [ ] README updated with Redis/Sidekiq instructions
