class CreateIngestions < ActiveRecord::Migration[8.1]
  def change
    create_table :ingestions do |t|
      t.string :status, null: false, default: "pending"
      t.string :filename, null: false
      t.string :file_path, null: false
      t.integer :chunks_count
      t.text :error_message

      t.timestamps
    end

    add_index :ingestions, :status
  end
end
