class AddEncryptedCardNumberToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :encrypted_card_number, :string
  end
end
