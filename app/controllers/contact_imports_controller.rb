class ContactImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contact_import, only: [ :show, :edit, :update, :destroy, :errors ]

  def index
    @contact_imports = current_user.contact_imports.recent_first.page(params[:page]).per(10)
  end

  def show
    @contacts = @contact_import.contacts.recent_first.page(params[:page]).per(20)
  end

  def new
    @contact_import = ContactImport.new
  end

  def create
    @contact_import = current_user.contact_imports.build(contact_import_params)

    if @contact_import.save
      if params[:commit] == "now"
        process_import_now
      else
        ProcessContactImportJob.perform_later(@contact_import)
        redirect_to contact_imports_path, notice: "File uploaded successfully and queued for background processing."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    if @contact_import.csv_file.attached?
      @csv_headers = CsvProcessingService.new(@contact_import).extract_headers
      @required_fields = %w[name date_of_birth phone address email credit_card_number]
    else
      redirect_to contact_imports_path, alert: "No CSV file found."
    end
  end

  def update
    if @contact_import.update(column_mapping: params[:column_mapping])
      ProcessContactImportJob.perform_later(@contact_import)
      redirect_to contact_imports_path, notice: "Column mapping saved. Processing started."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact_import.destroy
    redirect_to contact_imports_path, notice: "Import deleted successfully."
  end

  def errors
    @errors = @contact_import.contact_import_errors.by_row.page(params[:page]).per(20)
  end

  private

  def set_contact_import
    @contact_import = current_user.contact_imports.find(params[:id])
  end

  def contact_import_params
    # First permit all the parameters we need
    permitted_params = params.require(:contact_import).permit(
      :csv_file,
      :column_mapping_name,
      :column_mapping_date_of_birth,
      :column_mapping_phone,
      :column_mapping_address,
      :column_mapping_email,
      :column_mapping_credit_card_number
    )

    # Build the final params hash with only what we need
    result = {
      csv_file: permitted_params[:csv_file],
      column_mapping: {
        name: permitted_params[:column_mapping_name],
        date_of_birth: permitted_params[:column_mapping_date_of_birth],
        phone: permitted_params[:column_mapping_phone],
        address: permitted_params[:column_mapping_address],
        email: permitted_params[:column_mapping_email],
        credit_card_number: permitted_params[:column_mapping_credit_card_number]
      }
    }

    # Set filename from uploaded file if present
    if permitted_params[:csv_file].present?
      result[:filename] = permitted_params[:csv_file].original_filename
    end

    # Set default status if not set
    result[:status] = "on_hold" unless result[:status].present?

    result
  end

  def process_import_now
    begin
      CsvProcessingService.new(@contact_import).process!
      redirect_to contact_import_path(@contact_import), notice: "Import processed successfully!"
    rescue => e
      @contact_import.mark_as_failed!(e.message)
      redirect_to contact_imports_path, alert: "Import failed: #{e.message}"
    end
  end
end
