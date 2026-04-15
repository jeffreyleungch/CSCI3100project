# All Intended Auction Functionalities

This document outlines all intended functionalities associated with auctions based on the codebase structure, PR description, and implementation.

---

## 1. **Real-Time Auction Updates (ActionCable)**

### 1.1 Auction Channel (`AuctionChannel`)
**File:** [marketplace/app/channels/auction_channel.rb](marketplace/app/channels/auction_channel.rb)

**Functionalities:**
- **Subscription Management**
  - Users can subscribe to auction updates for a specific auction
  - Community-scoped authorization: Only users from the same community as the auction can subscribe
  - On subscription, receive a snapshot of current auction state

- **Server-Authoritative Snapshots**
  - Upon connection, client receives initial snapshot with:
    - `highest_bid_cents`: Current highest bid amount (in cents)
    - `ends_at_iso`: ISO8601 format auction end time
    - `status`: Current auction status (e.g., "running", "closed")
    - `auction_id`: ID of the auction
  
- **Real-Time Bid Placement** (`place_bid` action)
  - Allows authenticated users to place bids on running auctions
  - Server-authoritative validation using row locking (`Auction.lock`)
  - Validates auction is still running before accepting bid
  - Creates new `Bid` record with user and amount
  - Broadcasts updated snapshot to all subscribers on success
  - Returns error message if bid cannot be saved (e.g., validation failure)

- **Real-Time Broadcasting**
  - Automatically broadcasts snapshot updates to all connected subscribers when bids are placed
  - Broadcasts closure message when auction closes
  - Transmits reminder notifications 15 minutes before auction ends
  - Tenant-safe: Only broadcasts within the community

### 1.2 Client-Side Implementation

**JavaScript Channel Helper** [app/javascript/channels/auction_channel.js](app/javascript/channels/auction_channel.js)
- `subscribeAuction(auctionId, onUpdate)` function
- Creates WebSocket subscription to AuctionChannel
- Handles incoming data with callback function
- Manages connection lifecycle

**Stimulus Controller** [app/javascript/controllers/auction_controller.js](app/javascript/controllers/auction_controller.js)
- Automatically subscribes to auction updates on element connection
- Unsubscribes on element disconnection (cleanup)
- Handles message types:
  - `snapshot`: Updates displayed highest bid
  - `closed`: Changes status display to "Closed"
  - `reminder`: Receives 15-minute warning
- **Live Countdown Timer**
  - Displays real-time countdown (MM:SS format)
  - Updates every 250ms
  - Stops when time reaches zero

---

## 2. **Background Jobs (Sidekiq)**

### 2.1 Auction Close Job
**File:** [marketplace/app/jobs/auction_close_job.rb](marketplace/app/jobs/auction_close_job.rb)

**Queue:** `critical` (high priority)

**Functionalities:**
- **Idempotent Auction Closure**
  - Uses database row locking to prevent race conditions
  - Checks if auction is already closed to ensure idempotency
  - Verifies current time is >= `ends_at` before closing

- **Winner Determination**
  - Selects highest bidder by amount (descending) and creation time (ascending)
  - Creates payment record for winning bid with status: `pending`
  - Handles case where no bids were placed (no winner)

- **Payment Record Creation**
  - Creates `PaymentRecord` with:
    - Associated auction
    - Winning user
    - Winning bid amount (in cents)
    - Initial status: `pending` (awaiting payment)
  - All in a database transaction for consistency

- **Broadcast Closure Notification**
  - Broadcasts to all auction subscribers:
    - `type: "closed"` message
    - `winner_user_id`: ID of winning user (null if no bids)
    - `highest_bid_cents`: Winning bid amount

- **Winner Notification Email** (if `WinnerMailer` defined)
  - Sends payment prompt email to winning bidder
  - Scheduled for asynchronous delivery

### 2.2 Auction Reminder Job
**File:** [marketplace/app/jobs/auction_reminder_job.rb](marketplace/app/jobs/auction_reminder_job.rb)

**Queue:** `default`

**Functionalities:**
- **15-Minute Warning Reminder**
  - Only broadcasts if auction is still in `running` status
  - Sends reminder notification to all active subscribers:
    - `type: "reminder"`
    - `minutes_left: 15`
    - `auction_id`: Target auction ID

---

## 3. **Auction Lifecycle Management**

### 3.1 Auction Scheduler (Concern Module)
**Module:** [app/models/concerns/auction_scheduler.rb](app/models/concerns/auction_scheduler.rb)

**Integrated into:** `Auction` model via `include AuctionScheduler`

**Functionalities:**
- **Automatic Job Scheduling**
  - On auction creation: Schedules both close and reminder jobs
  - On `ends_at` update: Reschedules close job with new time

- **Close Job Scheduling**
  - Triggered: After commit when `ends_at` changes
  - Action: `AuctionCloseJob.set(wait_until: ends_at).perform_later(id)`
  - Ensures job runs precisely at auction end time

- **Reminder Job Scheduling**
  - Triggered: After commit on auction creation
  - Time: 15 minutes before `ends_at`
  - Only schedules if reminder time is in the future
  - Action: `AuctionReminderJob.set(wait_until: t).perform_later(id)`

### 3.2 Auction Status Enum
**States:** `scheduled`, `running`, `closed`
- `scheduled` (0): Auction created but not yet active
- `running` (1): Auction actively accepting bids
- `closed` (2): Auction ended, winner determined

---

## 4. **Bid Management**

### 4.1 Real-Time Bid Broadcasting (Concern Module)
**Module:** [app/models/concerns/broadcasts_auction_updates.rb](app/models/concerns/broadcasts_auction_updates.rb)

**Integrated into:** `Bid` model via dynamic inclusion in initializer

**Functionalities:**
- **Automatic Update Broadcasting**
  - Triggered: After commit when new bid is created
  - Broadcasts latest snapshot to all auction subscribers:
    - Updated `highest_bid_cents`
    - Current `ends_at_iso`
    - Current `status`

- **Bid Validation**
  - `amount_must_exceed_highest` validation
  - Ensures new bid amount exceeds all previous bids
  - Prevents equal or lower bids
  - Provides error message: "must exceed current highest"

- **Monetary Precision**
  - All amounts stored in cents (e.g., $10.50 = 1050 cents)
  - Ensures integer-based monetary calculations

---

## 5. **Community & Security**

### 5.1 Multi-Tenant Safety
- **Community Scoping**
  - All auction subscriptions verified against subscriber's community
  - Prevents users from accessing auctions outside their community
  - Enforced at channel level: `reject unless current_user&.community_id == @auction.community_id`

- **Server-Authoritative Validation**
  - All bid placement validated on server using row-level locks
  - Prevents client-side tampering or race conditions

---

## 6. **Configuration**

### 6.1 Redis Configuration
**File:** [marketplace/config/cable.yml](marketplace/config/cable.yml)
- **Production:** Uses `REDIS_URL` environment variable
- **Development:** Defaults to `redis://localhost:6379/1`
- **Test:** Uses in-memory test adapter

### 6.2 Sidekiq Configuration
**File:** [marketplace/config/sidekiq.yml](marketplace/config/sidekiq.yml)
- **Concurrency:** 5 workers
- **Queues:** 
  - `default` (for reminder jobs)
  - `mailers` (for email jobs)
  - `critical` (for close jobs - highest priority)

---

## 7. **Testing Coverage**

### 7.1 Channel Specs
**File:** [spec/channels/auction_channel_spec.rb](spec/channels/auction_channel_spec.rb)
- Tests community-scoped authorization
- Verifies rejection of users from different communities

### 7.2 Job Specs
**File:** [spec/jobs/auction_close_job_spec.rb](spec/jobs/auction_close_job_spec.rb)
- Tests auction closure functionality
- Verifies payment record creation
- Validates status transition from `running` to `closed`

### 7.3 Test Factories
- **Auction Factory** [spec/factories/auctions.rb](spec/factories/auctions.rb)
  - Default status: `running`
  - Ends at: 30 minutes from now
  - Associated with community

- **Bid Factory** [spec/factories/bids.rb](spec/factories/bids.rb)
  - Default amount: 1000 cents ($10.00)
  - Associated with auction and user

- **Payment Record Factory** [spec/factories/payment_records.rb](spec/factories/payment_records.rb)
  - Default status: `pending`
  - Default amount: 1000 cents

### 7.4 Coverage Requirements
- **Minimum Coverage:** ≥85% (branch coverage enabled)
- **Enforced via:** SimpleCov configuration
- **CI Integration:** GitHub Actions workflow

---

## 8. **CI/CD Integration**

### 8.1 Automated Checks
- **RuboCop:** Code style and lint checks
- **RSpec:** Unit and channel specs
- **SimpleCov:** Code coverage enforcement
- **GitHub Actions:** All checks required before merge to `main`

### 8.2 Redis Service
- Provided in CI environment for ActionCable and Sidekiq tests

---

## 9. **Essential Dependencies**

```ruby
gem 'redis', '~> 5.0'          # ActionCable & Sidekiq support
gem 'sidekiq', '~> 7.2'        # Background jobs
gem 'rspec-rails', '~> 6.1'    # Testing framework
gem 'simplecov'                # Code coverage
```

---

## 10. **Network & API Configuration**

### 10.1 ActionCable Configuration
- **Allowed Origins:** Must include staging/production domains
- **Adapter:** Redis (for supporting multiple server instances)

### 10.2 Environment Variables
- `REDIS_URL`: Production Redis connection string
- Defaults to `redis://localhost:6379/1` in development

---

## 11. **Data Model Relationships**

```
Auction
├── Community (belongs_to)
├── Bids (has_many)
│   ├── User (belongs_to)
│   └── BroadcastsAuctionUpdates (concern)
├── PaymentRecords (has_many)
│   ├── User (belongs_to)
│   └── Status: pending > completed/failed
└── Scheduler (concern)
    ├── Schedules AuctionCloseJob
    └── Schedules AuctionReminderJob
```

---

## Summary Table

| Feature | Implementation | Real-Time | Status |
|---------|-----------------|-----------|--------|
| Live bid updates | ActionCable + Stimulus | ✓ | Implemented |
| Live countdown timer | JS Stimulus controller | ✓ | Implemented |
| Bid validation | Server-side with locking | ✓ | Implemented |
| Auction closing | Sidekiq background job | ✗ (async) | Implemented |
| Winner notification | Sidekiq + Mailer job | ✗ (async) | Implemented |
| 15-min reminder | Sidekiq background job | ✗ (async) | Implemented |
| Community security | ActionCable authorization | ✓ | Implemented |
| Payment records | AuctionCloseJob callback | ✗ (on close) | Implemented |
| Code coverage check | SimpleCov + GitHub Actions | ✗ (CI only) | Implemented |

