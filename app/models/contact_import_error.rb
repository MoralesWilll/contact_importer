class ContactImportError < ApplicationRecord
  belongs_to :contact_import

  scope :by_row, -> { order(:row_number) }
end
