class AddSellerToAuctions < ActiveRecord::Migration[7.0]
  def change
    add_column :auctions, :seller_id, :bigint, comment: "User who created the auction"
    add_index :auctions, :seller_id
    add_foreign_key :auctions, :users, column: :seller_id, optional: true
  end
end
