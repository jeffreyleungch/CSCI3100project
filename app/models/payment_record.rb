class PaymentRecord < ApplicationRecord
  belongs_to :item

  enum :status, { pending: 0, confirmed: 1, completed: 2, failed: 3, cancelled: 4 }

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :currency, presence: true
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
end
