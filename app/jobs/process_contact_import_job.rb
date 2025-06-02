class ProcessContactImportJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(contact_import)
    Rails.logger.info("Starting processing of ContactImport ID: #{contact_import.id}")

    begin
      CsvProcessingService.new(contact_import).process!
      Rails.logger.info("Successfully processed ContactImport ID: #{contact_import.id}")
    rescue => e
      Rails.logger.error("Failed to process ContactImport ID: #{contact_import.id} - #{e.message}")
      contact_import.mark_as_failed!(e.message)
      raise e # Re-raise to trigger retry mechanism
    end
  end
end
