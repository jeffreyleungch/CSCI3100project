class CreateItemsWithFulltextIndex < ActiveRecord::Migration[6.0]
  def change
    create_table :items do |t|
      t.string :title
      t.text :description
      t.references :community, null: false, foreign_key: true
      t.integer :starting_price_cents
      t.string :status

      t.timestamps
    end

    # Add FULLTEXT index on title and description
    execute "CREATE FULLTEXT INDEX index_items_on_title_and_description ON items(title, description)"

    # Add indexes on other fields
    add_index :items, :community_id
    add_index :items, :category
    add_index :items, :starting_price_cents
    add_index :items, :status

    # Add foreign key constraint for auctions table
    add_foreign_key :auctions, :items, column: :item_id
  end
end