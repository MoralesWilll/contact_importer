require 'rails_helper'

RSpec.describe ContactImport, type: :model do
  let(:user) { create(:user) }
  let(:contact_import) { create(:contact_import, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:contacts).dependent(:destroy) }
    it { should have_many(:contact_import_errors).dependent(:destroy) }
    it { should have_one_attached(:csv_file) }
  end

  describe 'validations' do
    it { should validate_presence_of(:filename) }
    it { should validate_inclusion_of(:status).in_array(%w[on_hold processing failed finished]) }
  end

  describe 'scopes' do
    let!(:old_import) { create(:contact_import, user: user, created_at: 1.day.ago) }
    let!(:new_import) { create(:contact_import, user: user, created_at: 1.hour.ago) }
    let!(:other_user_import) { create(:contact_import, created_at: 2.hours.ago) }

    describe '.recent_first' do
      it 'orders by created_at descending' do
        expect(ContactImport.recent_first).to eq([ new_import, other_user_import, old_import ])
      end
    end

    describe '.for_user' do
      it 'returns imports for specific user' do
        expect(ContactImport.for_user(user)).to contain_exactly(old_import, new_import)
      end
    end
  end

  describe '#status_display' do
    it 'returns formatted status' do
      expect(build(:contact_import, status: 'on_hold').status_display).to eq('On Hold')
      expect(build(:contact_import, status: 'processing').status_display).to eq('Processing')
      expect(build(:contact_import, status: 'failed').status_display).to eq('Failed')
      expect(build(:contact_import, status: 'finished').status_display).to eq('Finished')
    end
  end

  describe '#success_rate' do
    context 'when total_rows is zero' do
      it 'returns 0' do
        contact_import = build(:contact_import, total_rows: 0)
        expect(contact_import.success_rate).to eq(0)
      end
    end

    context 'when total_rows is positive' do
      it 'calculates success rate percentage' do
        contact_import = build(:contact_import, total_rows: 100, successful_imports: 75)
        expect(contact_import.success_rate).to eq(75.0)
      end

      it 'rounds to 1 decimal place' do
        contact_import = build(:contact_import, total_rows: 3, successful_imports: 2)
        expect(contact_import.success_rate).to eq(66.7)
      end
    end
  end

  describe '#mark_as_failed!' do
    it 'updates status to failed and sets completed_at' do
      Timecop.freeze do
        contact_import.mark_as_failed!('Error message')

        expect(contact_import.reload.status).to eq('failed')
        expect(contact_import.completed_at).to eq(Time.current)
      end
    end
  end

  describe '#start_processing!' do
    it 'updates status to processing and sets started_at' do
      Timecop.freeze do
        contact_import.start_processing!

        expect(contact_import.reload.status).to eq('processing')
        expect(contact_import.started_at).to eq(Time.current)
      end
    end
  end
end
