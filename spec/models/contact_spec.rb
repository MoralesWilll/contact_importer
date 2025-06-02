require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:contact_import) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:date_of_birth) }
    it { should validate_presence_of(:phone) }
    it { should validate_presence_of(:address) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:credit_card_number) }
    it { should validate_presence_of(:card_network) }

    describe 'name format validation' do
      it 'allows valid names' do
        expect(build(:contact, name: 'John Doe')).to be_valid
        expect(build(:contact, name: 'Mary-Jane Smith')).to be_valid
        expect(build(:contact, name: 'O\'Connor')).to be_invalid # Contains apostrophe
      end

      it 'rejects invalid names' do
        expect(build(:contact, name: 'John123')).to be_invalid
        expect(build(:contact, name: 'John@Doe')).to be_invalid
      end
    end

    describe 'phone format validation' do
      it 'allows valid phone numbers' do
        expect(build(:contact, phone: '1234567890')).to be_valid
        expect(build(:contact, phone: '123456789012345')).to be_valid
      end

      it 'rejects invalid phone numbers' do
        expect(build(:contact, phone: '123456789')).to be_invalid # Too short
        expect(build(:contact, phone: '1234567890123456')).to be_invalid # Too long
        expect(build(:contact, phone: '123-456-7890')).to be_invalid # Contains dashes
      end
    end

    describe 'email format validation' do
      it 'allows valid emails' do
        expect(build(:contact, email: 'test@example.com')).to be_valid
      end

      it 'rejects invalid emails' do
        expect(build(:contact, email: 'invalid-email')).to be_invalid
      end
    end

    describe 'email uniqueness validation' do
      let(:user) { create(:user) }
      let(:contact_import) { create(:contact_import, user: user) }

      it 'allows same email for different users' do
        create(:contact, email: 'test@example.com', user: user, contact_import: contact_import)
        other_user = create(:user)
        other_import = create(:contact_import, user: other_user)

        expect(build(:contact, email: 'test@example.com', user: other_user, contact_import: other_import)).to be_valid
      end

      it 'rejects duplicate email for same user' do
        create(:contact, email: 'test@example.com', user: user, contact_import: contact_import)

        expect(build(:contact, email: 'test@example.com', user: user, contact_import: contact_import)).to be_invalid
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:contact_import) { create(:contact_import, user: user) }
    let!(:old_contact) { create(:contact, user: user, contact_import: contact_import, created_at: 1.day.ago) }
    let!(:new_contact) { create(:contact, user: user, contact_import: contact_import, created_at: 1.hour.ago) }

    describe '.recent_first' do
      it 'orders by created_at descending' do
        expect(Contact.recent_first).to eq([ new_contact, old_contact ])
      end
    end
  end
end
