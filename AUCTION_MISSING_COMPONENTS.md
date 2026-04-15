# Auction Missing Components

This file contains ready-to-copy Rails code for the auction functionality that is currently missing from the branch.

Use these snippets later by copying them into the appropriate files in your Rails app.

---

## 1. `app/models/bid.rb`

```ruby
class Bid < ApplicationRecord
  belongs_to :auction
  belongs_to :user

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :amount_must_exceed_current_highest

  private

  def amount_must_exceed_current_highest
    return unless auction

    current_highest = auction.bids.maximum(:amount_cents).to_i
    if amount_cents.to_i <= current_highest
      errors.add(:amount_cents, 'must exceed current highest')
    end
  end
end
```

---

## 2. `app/models/payment_record.rb`

```ruby
class PaymentRecord < ApplicationRecord
  belongs_to :auction
  belongs_to :user

  enum status: { pending: 0, paid: 1, failed: 2 }

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
```

---

## 3. `app/models/user.rb` (if not already present)

```ruby
class User < ApplicationRecord
  belongs_to :community, optional: true
  has_many :bids
  has_many :payment_records
end
```

---

## 4. `app/models/community.rb` (if not already present)

```ruby
class Community < ApplicationRecord
  has_many :users
  has_many :auctions
end
```

---

## 5. `app/mailers/winner_mailer.rb`

```ruby
class WinnerMailer < ApplicationMailer
  def payment_prompt
    @bid = params[:bid]
    mail(
      to: @bid.user.email,
      subject: "Your auction win: payment required"
    )
  end
end
```

---

## 6. `db/migrate/XXXX_create_bids.rb`

```ruby
class CreateBids < ActiveRecord::Migration[7.0]
  def change
    create_table :bids do |t|
      t.references :auction, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents, null: false

      t.timestamps
    end

    add_index :bids, [:auction_id, :amount_cents]
  end
end
```

---

## 7. `db/migrate/XXXX_create_payment_records.rb`

```ruby
class CreatePaymentRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_records do |t|
      t.references :auction, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
```

---

## 8. Optional `db/migrate` templates for User and Community

If you need them, copy these templates as well.

### `db/migrate/XXXX_create_communities.rb`

```ruby
class CreateCommunities < ActiveRecord::Migration[7.0]
  def change
    create_table :communities do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
```

### `db/migrate/XXXX_create_users.rb`

```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.references :community, foreign_key: true

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
```

---

## Notes

- The auction code already expects:
  - `Auction` model with `enum status: { scheduled: 0, running: 1, closed: 2 }`
  - `Bid` model broadcasting updates
  - `PaymentRecord` model for close job payments
  - `WinnerMailer` mailer for payment prompt emails
- Copy these snippets into your app only when you want to integrate the missing components.
- No existing files were modified by creating this reference file.
