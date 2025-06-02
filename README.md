# Contact Importer 📇

A Ruby on Rails application for importing and managing contact data from CSV files with comprehensive validation, error handling, and background processing.

## Features

- **CSV Contact Import**: Upload and process CSV files with contact information
- **Field Validation**: Comprehensive validation for names, emails, phone numbers, dates, and credit cards
- **Background Processing**: Asynchronous CSV processing using Sidekiq and Redis
- **Error Tracking**: Detailed error reporting with row-level failure information
- **User Management**: Multi-user support with isolated contact data
- **Import Status Tracking**: Real-time status updates (on_hold, processing, failed, finished)
- **Data Integrity**: Duplicate email detection and credit card network identification

## Supported Data Fields

- **Name**: Letters, spaces, and hyphens only
- **Date of Birth**: YYYYMMDD or YYYY-MM-DD formats
- **Phone**: Colombian format `(+XX) XXX XXX XX XX` or `(+XX) XXX-XXX-XX-XX`
- **Email**: Standard email validation with uniqueness check
- **Address**: Free text
- **Credit Card**: Support for Visa, MasterCard, American Express, Diners Club, Discover, and JCB

## Prerequisites

- Ruby 3.0+
- Rails 7.0+
- MySQL/PostgreSQL
- Redis
- Node.js (for asset compilation)

## Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/MoralesWilll/contact_importer
cd contact-importer
```

### 2. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies
npm install
# or
yarn install
```

### 3. Database Setup

```bash
# Create and configure your database.yml
cp config/database.yml.example config/database.yml

# Edit database.yml with your database credentials
# Then run:
rails db:create
rails db:migrate
rails db:seed
```

### 4. Environment Configuration

```bash
# Copy environment file
cp .env.erb .env

# Edit .env file with your configuration:
# - Database credentials
# - Redis URL
# - Secret keys
```

### 5. Redis Installation & Setup

#### macOS (using Homebrew)
```bash
brew install redis
brew services start redis
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

#### Docker (Alternative)
```bash
docker run -d -p 6379:6379 --name redis redis:alpine
```

### 6. Sidekiq Configuration

Sidekiq is used for background job processing. Make sure Redis is running, then:

```bash
# In a separate terminal, start Sidekiq
bundle exec sidekiq

# Or with specific configuration
bundle exec sidekiq -C config/sidekiq.yml
```

### 7. Start the Application

```bash
# Start Rails server
rails server

# Or with specific environment
rails server -e production
```

Visit `http://localhost:3000` to access the application.

## Usage

### Basic Workflow

1. **Create Account**: Register a new user account
2. **Upload CSV**: Navigate to imports section and upload a CSV file
3. **Map Columns**: Configure field mapping (auto-detection available)
4. **Process Import**: Submit for background processing
5. **Monitor Progress**: Track import status and view results
6. **Review Errors**: Check detailed error reports for failed rows

### CSV Format Requirements

Your CSV file should have the following columns (headers can be in any order):

```csv
name,date_of_birth,phone,credit_card,email,address
John Doe,19900515,(+57) 300 123 45 67,4111111111111111,john.doe@email.com,123 Main St
```

### Column Mapping

The system supports automatic column detection based on header names:
- `name` → Contact Name
- `date_of_birth` → Date of Birth
- `phone` → Phone Number
- `credit_card` or `credit_card_number` → Credit Card
- `email` → Email Address
- `address` → Address

Manual mapping is also available through the web interface.

## API Endpoints

### Contact Imports
- `GET /contact_imports` - List all imports
- `POST /contact_imports` - Create new import
- `GET /contact_imports/:id` - View import details
- `DELETE /contact_imports/:id` - Delete import

### Contacts
- `GET /contacts` - List contacts
- `GET /contacts/:id` - View contact details
- `DELETE /contacts/:id` - Delete contact

## Background Jobs

The application uses Sidekiq for processing CSV imports asynchronously:

### Job Types
- **CsvProcessingJob**: Handles CSV file parsing and contact creation
- **EmailNotificationJob**: Sends completion notifications (if configured)

### Monitoring Sidekiq

Access the Sidekiq Web UI at `http://localhost:3000/sidekiq` (requires admin authentication).

```bash
# View Sidekiq stats
bundle exec sidekiq-cli stats

# Clear failed jobs
bundle exec sidekiq-cli clear retries
```

## Configuration

### Environment Variables

```bash
# Database
DATABASE_USER="user"
DATABASE_PASSWORD="password"

# Redis
REDIS_URL=redis://localhost:6379/0

# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
```

### Sidekiq Configuration

Edit `config/sidekiq.yml`:

```yaml
:concurrency: 10
:queues:
  - default
  - mailers
  - csv_processing
:redis:
  url: redis://localhost:6379/0
```

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/services/csv_processing_service_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

**CSV Import Failures**
- Check CSV format matches requirements
- Verify column mappings are correct
- Review error logs in import details
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.