class CreateBids < ActiveRecord::Migration[7.0]
  def change
    create_table :bids, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
      t.bigint :auction_id, null: false, index: true
      t.bigint :user_id, null: false, index: true
      t.bigint :item_id, index: true, comment: "Optional: link to item for display"
      t.bigint :amount_cents, null: false, comment: "Bid amount in cents"

      t.timestamps
    end

    add_index :bids, [:auction_id, :amount_cents], name: 'index_bids_on_auction_and_amount_cents'
    add_index :bids, [:user_id, :auction_id], name: 'index_bids_on_user_and_auction'
    add_foreign_key :bids, :auctions, column: :auction_id
    add_foreign_key :bids, :users, column: :user_id
    add_foreign_key :bids, :items, column: :item_id, optional: true
  end
end
