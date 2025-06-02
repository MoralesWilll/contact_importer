class CreditCardService
  CARD_NETWORKS = {
    "American Express" => { prefixes: [ "34", "37" ], length: 15 },
    "Diners Club" => { prefixes: [ "30", "36", "38" ], length: 14 },
    "Discover" => { prefixes: [ "60", "65" ], length: 16 },
    "JCB" => { prefixes: [ "35" ], length: 16 },
    "MasterCard" => { prefixes: [ "51", "52", "53", "54", "55" ], length: 16 },
    "Visa" => { prefixes: [ "4" ], length: 16 }
  }.freeze

  def self.identify_network(card_number)
    return nil if card_number.blank?

    card_number = card_number.to_s.gsub(/\D/, "") # Remove non-digits
    return nil if card_number.length < 2

    CARD_NETWORKS.each do |network, config|
      config[:prefixes].each do |prefix|
        if card_number.start_with?(prefix)
          # Validate length
          return network if card_number.length == config[:length]
        end
      end
    end

    nil # Return nil if no network matches or length is invalid
  end

  def self.encrypt_card(card_number)
    return nil if card_number.blank?

    # Clean the card number
    clean_number = card_number.to_s.gsub(/\D/, "")
    return nil if clean_number.blank?

    # Validate the card number
    network = identify_network(clean_number)
    return nil if network.nil?

    # Encrypt using SHA256
    Digest::SHA256.hexdigest(clean_number)
  end

  def self.valid_card?(card_number)
    return false if card_number.blank?

    clean_number = card_number.to_s.gsub(/\D/, "")
    network = identify_network(clean_number)

    return false if network.nil?

    # Additional validation: check if length matches network requirements
    expected_length = CARD_NETWORKS[network][:length]
    clean_number.length == expected_length
  end

  def self.mask_card_number(last_four)
    return nil if last_four.blank?
    "**** **** **** #{last_four}"
  end

  # For testing - generate valid test card numbers
  def self.test_cards
    {
      "American Express" => "371449635398431",
      "Diners Club" => "30569309025904",
      "Discover" => "6011111111111117",
      "JCB" => "3530111333300000",
      "MasterCard" => "5555555555554444",
      "Visa" => "4111111111111111"
    }
  end
end
