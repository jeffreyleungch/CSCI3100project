class CreateCommunities < ActiveRecord::Migration[7.0]
  def change
    create_table :communities, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
      t.string :name, null: false, limit: 255, comment: "Community name (e.g., College name, Hostel)"

      t.timestamps
    end

    add_index :communities, :name, unique: true, name: 'index_communities_on_name_unique'
  end
end
