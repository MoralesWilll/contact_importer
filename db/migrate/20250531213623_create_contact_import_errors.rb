class CreateContactImportErrors < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_import_errors do |t|
      t.references :contact_import, null: false, foreign_key: true
      t.integer :row_number
      t.text :error_message
      t.json :row_data

      t.timestamps
    end
  end
end
