# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.text :content, null: false
      t.text :source
      t.vector :embedding, limit: 3072

      t.timestamps
    end
  end
end
