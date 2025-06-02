class AddErrorMessageToContactImports < ActiveRecord::Migration[8.0]
  def change
    add_column :contact_imports, :error_message, :text
  end
end
