class CreateContactImports < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :status, default: 'on_hold', null: false
      t.integer :total_rows, default: 0
      t.integer :successful_imports, default: 0
      t.integer :failed_imports, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.json :column_mapping
      t.text :error_summary

      t.timestamps
    end

    add_index :contact_imports, [ :user_id, :created_at ]
    add_index :contact_imports, :status
    add_index :contact_imports, :created_at
  end
end
