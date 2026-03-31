class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
      t.bigint :community_id, null: false, index: true, comment: "Multi-tenant scoping by community"
      t.string :email, null: false, limit: 255, comment: "User email address"
      t.string :password, null: false, limit: 255, comment: "Hashed password"

      t.timestamps
    end

    add_index :users, :email, unique: true, name: 'index_users_on_email_unique'
    add_foreign_key :users, :communities, column: :community_id
  end
end
