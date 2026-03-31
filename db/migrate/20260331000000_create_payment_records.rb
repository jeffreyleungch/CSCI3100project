class CreatePaymentRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_records, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
      t.bigint :auction_id, null: false, index: true
      t.bigint :user_id, null: false, index: true
      t.bigint :amount_cents, null: false, comment: "Amount in cents (integer)"
      t.integer :status, default: 0, null: false, comment: "0=pending, 1=confirmed, 2=completed, 3=failed, 4=cancelled"

      t.timestamps
    end

    add_index :payment_records, [:auction_id, :status], name: 'index_payment_records_on_auction_and_status'
    add_foreign_key :payment_records, :auctions, column: :auction_id
    add_foreign_key :payment_records, :users, column: :user_id
  end
end
