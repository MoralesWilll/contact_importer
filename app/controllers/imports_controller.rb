require "csv"
require "parallel"

class CsvProcessingService
  def initialize(contact_import)
    @contact_import = contact_import
    @user = contact_import.user
    @successful_count = 0
    @failed_count = 0
    @contacts_to_import = []
    @errors_to_log = []
  end

  def extract_headers
    return [] unless @contact_import.csv_file.attached?

    csv = open_csv
    headers = csv.first.to_h.keys.map(&:strip) # Extract headers correctly
    headers.reject(&:blank?)
  end

  def process!
    @contact_import.start_processing!

    csv = open_csv
    headers = extract_headers

    raise "CSV file appears to be empty or invalid" if headers.empty?

    column_mapping = @contact_import.column_mapping || {}
    mapped_columns = map_columns(headers, column_mapping)

    total_rows = csv.size - 1 # Exclude header
    @contact_import.update!(total_rows: total_rows)

    # Process each row using parallel execution
    Parallel.each(csv.each_with_index, in_threads: 4) do |(row), index|
      next if index.zero? # Skip header row
      process_row(row.to_h, mapped_columns, index + 1)
    end

    # Batch insert contacts and errors
    Contact.import!(@contacts_to_import) if @contacts_to_import.any?
    ContactImportError.import!(@errors_to_log) if @errors_to_log.any?

    finalize_import_status
  end

  private

  def open_csv
    return @csv if @csv

    unless @contact_import.csv_file.attached?
      raise "No CSV file attached"
    end

    # Download and parse CSV
    csv_content = @contact_import.csv_file.blob.download
    @csv = CSV.parse(csv_content, headers: true)
  end

  def map_columns(headers, user_mapping)
    return user_mapping.symbolize_keys.transform_values do |column_name|
      headers.index(column_name.to_s) || headers.index(column_name.to_s.downcase)
    end.compact if user_mapping.present?

    headers.each_with_index.each_with_object({}) do |(header, index), auto_mapping|
      normalized_header = header.downcase.strip
      case normalized_header
      when /name/ then auto_mapping[:name] = index
      when /birth|dob|date.*birth/ then auto_mapping[:date_of_birth] = index
      when /phone|telephone/ then auto_mapping[:phone] = index
      when /address/ then auto_mapping[:address] = index
      when /email/ then auto_mapping[:email] = index
      when /card|credit/ then auto_mapping[:credit_card_number] = index
      end
    end
  end

  def process_row(row, mapped_columns, row_number)
    begin
      contact_data = extract_contact_data(row, mapped_columns)
      create_contact(contact_data, row_number)
    rescue ActiveRecord::RecordInvalid => e
      log_error(row_number, "Validation failed: #{e.message}", row, mapped_columns)
    rescue StandardError => e
      log_error(row_number, "Unexpected error: #{e.message}", row, mapped_columns)
    end
  end

  def create_contact(contact_data, row_number)
    contact = @user.contacts.new(contact_data.merge(contact_import: @contact_import))
    if contact.valid?
      @contacts_to_import << contact
      @successful_count += 1
    else
      log_error(row_number, contact.errors.full_messages.join(", "), contact_data)
    end
  end

  def extract_contact_data(row, mapped_columns)
    card_number = row[mapped_columns[:credit_card_number]]

    {
      name: validate_name(row[mapped_columns[:name]]),
      date_of_birth: validate_date_of_birth(row[mapped_columns[:date_of_birth]]),
      phone: validate_phone(row[mapped_columns[:phone]]),
      address: validate_address(row[mapped_columns[:address]]),
      email: validate_email(row[mapped_columns[:email]]),
      encrypted_card_number: CreditCardService.encrypt_card(card_number),
      card_network: CreditCardService.identify_network(card_number),
      credit_card_last_four: card_number&.to_s&.last(4)
    }
  end

  def validate_name(name)
    name&.strip&.match?(/\A[a-zA-Z\-\s]+\z/) ? name : nil
  end

  def validate_date_of_birth(date)
    return nil if date.blank?
    date = date.to_s.strip
    return nil unless date.match(/\A\d{8}\z|\A\d{4}-\d{2}-\d{2}\z/)

    Date.strptime(date, date.match(/\A\d{8}\z/) ? "%Y%m%d" : "%Y-%m-%d") rescue nil
  end

  def validate_phone(phone)
    phone&.strip&.match?(/\A\(\+\d{2}\) \d{3}-\d{3}-\d{2}-\d{2}\z/) ? phone : nil
  end

  def validate_address(address)
    address.presence&.strip
  end

  def validate_email(email)
    email&.strip&.downcase&.match?(URI::MailTo::EMAIL_REGEXP) ? email : nil
  end

  def log_error(row_number, error_message, row_data, mapped_columns)
    @failed_count += 1
    @errors_to_log << { contact_import_id: @contact_import.id, row_number: row_number, error_message: error_message, row_data: build_row_data_hash(row_data, mapped_columns) }
    Rails.logger.error("Failed to import row #{row_number}: #{error_message}")
  end

  def build_row_data_hash(row_data, mapped_columns)
    mapped_columns.transform_values { |index| row_data[index] if index }
  end

  def finalize_import_status
    if @successful_count.positive?
      @contact_import.mark_as_finished!
    elsif @failed_count.positive? && @successful_count.zero?
      @contact_import.mark_as_failed!("No contacts could be imported")
    end

    @contact_import.update!(successful_imports: @successful_count, failed_imports: @failed_count)
  end
end
