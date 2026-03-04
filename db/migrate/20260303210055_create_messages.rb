class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :session_id, null: false
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :messages, :session_id
  end
end
