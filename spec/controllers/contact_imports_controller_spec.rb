require 'rails_helper'

RSpec.describe ContactImportsController, type: :controller do
  let(:user) { create(:user) }
  let(:contact_import) { create(:contact_import, user: user) }

  before { sign_in user }

  describe 'GET #index' do
    let!(:user_imports) { create_list(:contact_import, 3, user: user) }
    let!(:other_user_import) { create(:contact_import) }

    it 'returns success' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns only current user imports' do
      get :index
      expect(assigns(:contact_imports)).to match_array(user_imports)
    end
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { id: contact_import.id }
      expect(response).to be_successful
    end

    it 'assigns the contact import' do
      get :show, params: { id: contact_import.id }
      expect(assigns(:contact_import)).to eq(contact_import)
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new contact import' do
      get :new
      expect(assigns(:contact_import)).to be_a_new(ContactImport)
    end
  end

  describe 'POST #create' do
    let(:csv_file) { fixture_file_upload('test.csv', 'text/csv') }
    let(:valid_params) do
      {
        contact_import: {
          csv_file: csv_file,
          column_mapping_name: 'name',
          column_mapping_email: 'email'
        }
      }
    end

    context 'with valid params' do
      it 'creates a new contact import' do
        expect {
          post :create, params: valid_params
        }.to change(ContactImport, :count).by(1)
      end

      it 'redirects to index' do
        post :create, params: valid_params
        expect(response).to redirect_to(contact_imports_path)
      end

      it 'sets the filename from uploaded file' do
        post :create, params: valid_params
        expect(ContactImport.last.filename).to eq('test.csv')
      end
    end

    context 'with invalid params' do
      it 'renders new template' do
        post :create, params: { contact_import: { csv_file: nil } }
        expect(response).to render_template(:new)
        expect(response.status).to eq(422)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the contact import' do
      contact_import_to_delete = create(:contact_import, user: user)

      expect {
        delete :destroy, params: { id: contact_import_to_delete.id }
      }.to change(ContactImport, :count).by(-1)
    end

    it 'redirects to index' do
      delete :destroy, params: { id: contact_import.id }
      expect(response).to redirect_to(contact_imports_path)
    end
  end

  describe 'security' do
    it 'prevents access to other users imports' do
      other_user_import = create(:contact_import)

      expect {
        get :show, params: { id: other_user_import.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
