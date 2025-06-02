require "csv"

class CsvProcessingService
  def initialize(contact_import)
    @contact_import = contact_import
    @user = contact_import.user
    @successful_count = 0
    @failed_count = 0
  end

  def process!
    # Use the model's built-in method instead of directly updating status
    @contact_import.start_processing!  # This sets status to "processing" and started_at

    csv_content = @contact_import.csv_file.blob.download
    csv = CSV.parse(csv_content, headers: true)

    raise "CSV file is empty" if csv.headers.empty?

    # Get column mapping
    column_mapping = get_column_mapping(csv.headers)

    @contact_import.update!(total_rows: csv.count)

    csv.each_with_index do |row, index|
      process_row(row, column_mapping, index + 1)
    end

    finalize_import
  end

  private

  def get_column_mapping(headers)
    Rails.logger.info "Raw column_mapping: #{@contact_import.column_mapping.inspect}"
    Rails.logger.info "CSV headers: #{headers.inspect}"

    # Use provided mapping or auto-detect
    if @contact_import.column_mapping.present?
      Rails.logger.info "Using provided mapping"

      user_mapping = {}
      @contact_import.column_mapping.each do |key, value|
        field_name = key.to_s.gsub(/^column_mapping\[/, "").gsub(/\]$/, "")
        actual_value = value.is_a?(Hash) ? value.values.first : value
        next if actual_value.blank?

        if actual_value.to_s =~ /\A\d+\z/
          user_mapping[field_name.to_sym] = actual_value.to_i
        else
          header_index = headers.find_index { |h| h.to_s.downcase.strip == actual_value.to_s.downcase.strip }
          user_mapping[field_name.to_sym] = header_index if header_index
        end
      end

      Rails.logger.info "Processed user_mapping: #{user_mapping.inspect}"
      return user_mapping unless user_mapping.empty?
    end

    # Auto-detect based on headers
    Rails.logger.info "Auto-detecting columns from headers: #{headers.inspect}"
    mapping = {}
    headers.each_with_index do |header, index|
      case header.to_s.downcase.strip
      when "name" then mapping[:name] = index
      when "date_of_birth" then mapping[:date_of_birth] = index
      when "phone" then mapping[:phone] = index
      when "address" then mapping[:address] = index
      when "email" then mapping[:email] = index
      when "credit_card", "credit_card_number" then mapping[:credit_card_number] = index
      end
    end
    Rails.logger.info "Auto-detected mapping: #{mapping.inspect}"
    mapping
  end

  def process_row(row, column_mapping, row_number)
    Rails.logger.info "Processing row #{row_number} with mapping: #{column_mapping.inspect}"
    Rails.logger.info "Row data: #{row.to_h.inspect}"

    contact_data = {
      name: validate_name(get_column_value(row, column_mapping[:name])),
      date_of_birth: validate_date_of_birth(get_column_value(row, column_mapping[:date_of_birth])),
      phone: validate_phone(get_column_value(row, column_mapping[:phone])),
      address: validate_address(get_column_value(row, column_mapping[:address])),
      email: validate_email(get_column_value(row, column_mapping[:email])),
      contact_import_id: @contact_import.id
    }

    Rails.logger.info "Before credit card - contact_data: #{contact_data.inspect}"

    # Process credit card
    card_value = get_column_value(row, column_mapping[:credit_card_number])
    Rails.logger.info "Credit card raw value: '#{card_value}'"
    card_data = process_credit_card(card_value)
    Rails.logger.info "Credit card processed: #{card_data.inspect}"
    contact_data.merge!(card_data)

    Rails.logger.info "Final contact_data: #{contact_data.inspect}"
    Rails.logger.info "Validation check: #{all_fields_valid?(contact_data)}"

    # Check if all required fields are present
    if all_fields_valid?(contact_data)
      create_contact(contact_data)
    else
      Rails.logger.error "Validation failed for row #{row_number}: #{contact_data.inspect}"
      log_error(row_number, "Missing or invalid required fields", row.to_h)
    end
  rescue StandardError => e
    Rails.logger.error "Exception in row #{row_number}: #{e.message}"
    log_error(row_number, e.message, row.to_h)
  end

  def get_column_value(row, column_index)
    return nil if column_index.nil?

    if row.is_a?(CSV::Row)
      row.fields[column_index]
    else
      row[column_index]
    end
  end

  # FIXED: Name validation to match Contact model exactly
  def validate_name(name)
    return nil if name.blank?
    name = name.strip
    # Contact model: only letters, spaces, and hyphens (NO numbers)
    name.match?(/\A[a-zA-Z\-\s]+\z/) ? name : nil
  end

  def validate_date_of_birth(date)
    return nil if date.blank?
    date = date.to_s.strip

    # Accept YYYYMMDD format
    if date.match(/\A\d{8}\z/)
      Date.strptime(date, "%Y%m%d") rescue nil
    # Accept YYYY-MM-DD format
    elsif date.match(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.strptime(date, "%F") rescue nil
    # Handle 7-digit dates (missing leading zero)
    elsif date.match(/\A\d{7}\z/)
      # Try adding leading zero to day: 1889021 -> 18890201
      fixed_date = date[0..5] + "0" + date[6]
      Date.strptime(fixed_date, "%Y%m%d") rescue nil
    # Handle 9-digit dates (extra digit)
    elsif date.match(/\A\d{9}\z/)
      # Remove middle digit: 200000917 -> 20000917
      fixed_date = date[0..3] + date[5..8]
      Date.strptime(fixed_date, "%Y%m%d") rescue nil
    else
      nil
    end
  end

  # CRITICAL FIX: Phone validation to match Contact model requirements
  def validate_phone(phone)
    return nil if phone.blank?
    phone = phone.strip

    # Business rules: Valid formats are (+XX) XXX XXX XX XX or (+XX) XXX-XXX-XX-XX
    valid_formats = [
      /\A\(\+\d{1,3}\)\s+\d{3}\s+\d{3}\s+\d{2}\s+\d{2}\z/,  # (+57) 304 602 88 93
      /\A\(\+\d{1,3}\)\s+\d{3}-\d{3}-\d{2}-\d{2}\z/         # (+57) 304-602-88-93
    ]

    # Check if format matches business rules
    format_valid = valid_formats.any? { |regex| phone.match?(regex) }
    return nil unless format_valid

    # Extract digits for Contact model validation (must be 10-15 digits)
    digits_only = phone.gsub(/[^\d]/, "")

    # Contact model expects digits only and length between 10-15
    if digits_only.length >= 10 && digits_only.length <= 15
      digits_only  # Return only digits as required by Contact model
    else
      nil
    end
  end

  def validate_address(address)
    return nil if address.blank?
    address.strip.presence
  end

  def validate_email(email)
    return nil if email.blank?
    email = email.strip.downcase

    # Basic email format validation
    return nil unless email.match?(URI::MailTo::EMAIL_REGEXP)

    # Check uniqueness within user's contacts
    existing = @user.contacts.find_by(email: email)
    existing ? nil : email
  end

  def process_credit_card(card_number)
    return { credit_card_number: nil, card_network: nil, credit_card_last_four: nil } if card_number.blank?

    # Clean card number (remove non-digits)
    clean_card = card_number.to_s.gsub(/\D/, "")
    return { credit_card_number: nil, card_network: nil, credit_card_last_four: nil } if clean_card.length < 13

    # Identify network
    network = identify_card_network(clean_card)
    return { credit_card_number: nil, card_network: nil, credit_card_last_four: nil } unless network

    # Validate length for network
    return { credit_card_number: nil, card_network: nil, credit_card_last_four: nil } unless valid_card_length?(clean_card, network)

    # Return with proper field names matching Contact model
    {
      credit_card_number: clean_card,  # Should be encrypted in production
      card_network: network,
      credit_card_last_four: clean_card.last(4)
    }
  end

  def identify_card_network(card_number)
    case card_number
    when /\A4/                    # Visa
      "Visa"
    when /\A5[1-5]/, /\A2[2-7]/  # MasterCard
      "MasterCard"
    when /\A3[47]/               # American Express
      "American Express"
    when /\A30[0-5]/, /\A36/, /\A38/ # Diners Club
      "Diners Club"
    when /\A6011/, /\A65/, /\A64[4-9]/, /\A622/ # Discover
      "Discover"
    when /\A35/                  # JCB
      "JCB"
    else
      nil
    end
  end

  def valid_card_length?(card_number, network)
    length = card_number.length

    case network
    when "Visa"
      [ 13, 16, 19 ].include?(length)
    when "MasterCard"
      length == 16
    when "American Express"
      length == 15
    when "Diners Club"
      [ 14, 16, 17, 18, 19 ].include?(length)
    when "Discover"
      [ 16, 19 ].include?(length)
    when "JCB"
      [ 15, 16 ].include?(length)
    else
      false
    end
  end

  def all_fields_valid?(contact_data)
    contact_data.values_at(
      :name, :date_of_birth, :phone, :address, :email,
      :credit_card_number, :card_network
    ).all?(&:present?)
  end

  def create_contact(contact_data)
    contact_data[:user_id] = @user.id
    contact = Contact.create!(contact_data)
    @successful_count += 1
  rescue ActiveRecord::RecordInvalid => e
    @failed_count += 1
    ContactImportError.create!(
      contact_import_id: @contact_import.id,
      error_message: e.message,
      row_data: contact_data
    )
  end

  def log_error(row_number, error_message, row_data)
    @failed_count += 1
    ContactImportError.create!(
      contact_import_id: @contact_import.id,
      row_number: row_number,
      error_message: error_message,
      row_data: row_data
    )
  end

  def finalize_import
    # Update counts first
    @contact_import.update!(
      successful_imports: @successful_count,
      failed_imports: @failed_count
    )

    # Update status based on results - use "finished" instead of "completed"
    if @successful_count > 0
      @contact_import.update!(status: "finished")  # Changed from "completed" to "finished"
    else
      @contact_import.update!(status: "failed", error_message: "No contacts could be imported")
    end
  end
end
