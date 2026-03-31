class CreateAuctions < ActiveRecord::Migration[7.0]
  def change
    create_table :auctions, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
      t.bigint :community_id, null: false, index: true, comment: "Multi-tenant scoping"
      t.datetime :ends_at, null: false, comment: "Auction close time"
      t.integer :status, default: 0, null: false, comment: "0=scheduled, 1=running, 2=closed"

      t.timestamps
    end

    add_index :auctions, [:community_id, :status], name: 'index_auctions_on_community_and_status'
    add_index :auctions, :ends_at, name: 'index_auctions_on_ends_at'
    add_foreign_key :auctions, :communities, column: :community_id
  end
end
