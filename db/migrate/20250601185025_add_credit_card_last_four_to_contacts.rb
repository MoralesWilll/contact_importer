class AddCreditCardLastFourToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :credit_card_last_four, :string
  end
end
