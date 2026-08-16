# Business Manager

An offline-first Flutter business management application for managing business records, inventory, transactions, invoices, expenses, company balances, reports, and local backups from a single application.

## Overview

Business Manager is a local-first business management application built with Flutter and Dart.

The application stores its business data locally using SQLite and provides tools for managing:

- Companies and their balances
- Materials and products
- Stock levels and low-stock warnings
- Units of measurement
- Buying and selling transactions
- Payments and outstanding balances
- Invoices, proforma invoices, and quotes
- Expenses and expense balances
- Company, material, and product ledgers
- Business reports and CSV exports
- PDF invoices and transaction reports
- Local backup and restore
- Application password protection
- Delete protection
- Appearance and background settings

The application is designed to operate without requiring a cloud backend. The uploaded source contains local database, file, PDF, export, authentication, and backup functionality, but no cloud synchronization or online database service is implemented.

---

## Features

### Dashboard & Overview

The Overview screen provides a consolidated view of the business.

It includes:

- Available balance
- Total receivables
- Total payables
- Current-month expenses
- Current-month bought quantity/value
- Current-month sold quantity/value
- Invoice amount due
- Number of low-stock items
- Number of unpaid transactions
- Recent transactions
- Six-month income vs. expense trend
- Expense-category breakdown

Dashboard cards can be opened to navigate directly to the relevant section.

The application also displays low-stock warnings and can show reminders for outstanding unpaid transactions.

---

### Company Management

Companies represent the businesses or parties involved in transactions.

The company management functionality includes:

- Add companies
- Edit companies
- Delete companies
- Search companies
- View contact information
- Store:
  - Company name
  - Contact person
  - Phone
  - Address
- View company balances
- Filter companies by balance status
- View individual company ledgers

Balance filters include:

- All
- Has Outstanding Balance
- Fully Settled
- They Owe You
- You Owe

Company history can be retained when removing a company from the active list, or related data can be permanently deleted through the deletion workflow.

---

### Business Profile

The Business Profile section stores information used throughout the application and invoice generation.

Supported information includes:

- Business name
- Contact person
- Phone
- Email
- Address
- Tax number
- Business logo
- Invoice prefix
- Default payment days
- Invoice footer
- Default invoice terms
- Payment instructions
- Invoice accent color
- Invoice template

Invoice templates implemented in the source include:

- Classic
- Modern
- Compact
- Detailed

The profile also supports selecting an invoice signature image for use in generated invoice PDFs.

---

### Inventory

The Inventory section contains three areas:

- Materials
- Products
- Units

Each area has its own management screen.

---

### Materials

Materials represent stock items used by the transaction system.

Supported functionality includes:

- Add materials
- Edit materials
- Delete materials
- Search materials
- Track current stock
- Set a default price
- Set a low-stock warning level
- Assign a unit
- Add a new unit while editing a material
- View a material ledger
- Filter materials by stock status

Stock status can be viewed as:

- All
- Low Stock
- Not Low Stock

Changing a material's default price affects future transactions and does not modify prices already saved in existing transactions.

When deleting a material, the application provides options to keep historical records or permanently delete the related data.

---

### Products

Products are managed separately from materials.

Supported functionality includes:

- Add products
- Edit products
- Delete products
- Search products
- Track current stock
- Set a default price
- Assign a unit
- Add new units
- View a product ledger

Product transactions are supported by the same transaction system used for materials.

---

### Units

The Units screen provides management of reusable units of measurement.

It supports:

- Viewing units
- Adding units
- Deleting units

Units are stored as unique values in the local database.

Deleting a unit does not alter the stored unit value of existing materials that already use it.

---

### Transactions

Transactions record buying and selling activity.

A transaction can contain:

- Company
- Material or product
- Transaction type
- Quantity
- Price
- Payment status
- Transaction date
- Transaction number
- Notes
- Optional bill/receipt image

Supported transaction types are:

- Bought / In
- Sold / Out

Transactions support both materials and products.

The transaction screen provides:

- Search
- Payment-status filtering
- Buy/sell filtering
- Company filtering
- Material filtering
- Date-range filtering
- Transaction summaries
- Material breakdowns
- Transaction details
- Editing transaction information
- Payment recording
- Transaction deletion

Payment states include:

- Paid
- Partial
- Unpaid

Partial payments can be added after the original transaction.

The transaction system also maintains payment records separately from the original transaction.

---

### Unpaid Transactions

The application includes a dedicated view for unpaid or outstanding transactions.

It can be reached from the Overview screen and is also surfaced through outstanding-payment reminders.

The application can notify the user when there are overdue or long-outstanding unpaid transactions and offer to open the unpaid transactions screen.

---

### Transaction Ledgers

The application provides detailed ledger views for companies, materials, and products.

#### Company Ledger

A company ledger provides:

- Bought totals
- Sold totals
- Amounts owed
- Amounts receivable
- Material breakdowns
- Payment-status filtering
- Buy/sell filtering
- Date-range filtering
- Transaction history
- PDF export

#### Material Ledger

A material ledger provides:

- Total bought quantity
- Total bought amount
- Total sold quantity
- Total sold amount
- Transaction history
- Payment information

#### Product Ledger

A product ledger provides the corresponding product transaction history and totals, including:

- Total bought quantity
- Total bought amount
- Total sold quantity
- Total sold amount
- Payment information

---

### Invoices

The invoice system supports creating and managing business documents.

Supported document types include:

- Invoice
- Proforma
- Quote

Invoices can contain:

- Company
- Invoice number
- Issue date
- Due date
- Valid-until date
- Material or product line items
- Quantity
- Unit price
- Notes
- Terms
- Payment instructions

Invoice statuses include:

- Draft
- Confirmed
- Unpaid
- Partially Paid
- Paid

The invoice workflow supports:

- Creating invoices
- Editing draft invoices
- Adding and removing line items
- Selecting materials or products
- Adding companies directly from the invoice workflow
- Recording payments
- Deleting draft invoices
- Previewing invoices
- Generating invoice PDFs
- Sharing invoice PDFs

When confirming an invoice, the application checks available stock and warns when there is insufficient stock. The user can choose whether to continue when stock would become negative.

The invoice PDF generator supports the configured business profile, invoice templates, business logo, invoice signature, terms, payment instructions, notes, and footer.

---

### Expenses

The Expenses section records business expenses.

Supported functionality includes:

- Add expenses
- Edit expenses
- Delete expenses
- Search expenses
- Filter by category
- Assign an expense to an expense balance
- View monthly totals
- View yearly totals
- View total balances
- Manage expense categories
- Manage expense balances

Each expense can contain:

- Category
- Description
- Amount
- Date
- Optional expense balance

Deleting an expense restores its effect on the associated balance.

---

### Expense Categories

Expense categories can be managed independently.

The application supports:

- Adding categories
- Preventing duplicate category names
- Using categories when recording expenses

---

### Expense Balances

Expense balances provide separate balances that can be used when recording expenses.

The application supports:

- Creating balances
- Managing current balances
- Adding funds
- Recording balance activity
- Viewing balance history
- Deducting expenses from a selected balance

Balance history is maintained through separate balance records.

---

### Reports

The Reports section provides CSV export tools for:

- Transactions
- Expenses
- Invoices
- Balances

The exported files are designed to be compatible with spreadsheet applications.

Transaction reports can also be generated as PDF files from the Transactions and Ledger screens.

---

### PDF Generation

The application generates PDF documents locally.

PDF functionality includes:

- Invoice PDFs
- Transaction reports
- Company ledger PDFs

Invoice PDFs support multiple invoice templates and can include business information, branding, terms, payment instructions, notes, and signature information.

Generated PDFs can be saved and shared using the application's file and sharing functionality.

---

### Backup & Restore

The application includes a local backup and restore system.

Backups are stored as JSON files and include application database data.

The backup system also handles:

- Business profile information
- Business logo
- Transaction attachments such as bill/receipt images

A backup can be:

- Saved as a local file
- Shared
- Restored from a selected JSON backup

Restoring a backup replaces the current application data with the selected backup data.

After restoring a backup, the application asks the user to restart the app so all screens can refresh from the restored data.

The application also includes a backup reminder when no backup has been created within the configured reminder period.

**Important:** The backup system is file-based. The uploaded source does not implement automatic cloud backup or cloud synchronization.

---

### Data Export

CSV export is available for:

| Data | Export Format |
|---|---|
| Transactions | CSV |
| Expenses | CSV |
| Invoices | CSV |
| Balances | CSV |

The application uses a file-save mechanism so the user can choose where exported files are stored.

---

### Security

The application provides local password protection.

On first use, the user can create an application password.

The password system:

- Does not store the plain-text password
- Generates a random salt
- Stores a SHA-256 hash of the salted password
- Verifies passwords against the stored hash
- Tracks failed login attempts
- Applies a temporary lockout after five failed attempts
- Uses a one-minute lockout period
- Supports changing the application password
- Supports removing password protection after verifying the current password

The application can also be manually locked from Settings.

#### Delete Protection

Deleting data can require a separate delete password.

The application provides a dedicated Delete Password setting and requires verification before protected deletion operations.

Deletion dialogs distinguish between retaining history and permanently deleting related records where supported.

These mechanisms provide application-level protection; they should not be interpreted as a replacement for operating-system security, disk encryption, or enterprise security controls.

---

### Appearance & Settings

Settings include:

- Background appearance controls
- Background brightness
- Company Profile
- Backup & Restore
- Change Password
- Delete Password
- Lock App

The application uses a custom animated/frozen wave background and translucent "glass" UI components.

The background can be animated on the login/lock experience and can be frozen during normal application use for reduced continuous rendering work.

The background brightness can be adjusted from Settings.

The UI adapts text and icon colors to the selected background brightness.

---

## Offline Architecture / Data Storage

Business Manager uses a local SQLite database for its primary application data.

The database is accessed through:

- `sqflite`
- `sqflite_common_ffi`

The database is managed centrally through `DatabaseHelper`.

The current database schema includes tables for:

- Companies
- Materials
- Products
- Transactions
- Units
- Payments
- Expenses
- Expense categories
- Expense balances
- Expense balance records
- Business profile
- Application settings
- Invoices
- Invoice items

The database currently uses schema version `19` and includes upgrade/migration logic for previous database versions.

Indexes are also created for frequently queried relationships and transaction/date/status fields.

Application settings, including authentication information and reminder state, are stored in the local `app_settings` table.

There is no cloud database, online API, or synchronization service present in the uploaded source.

---

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Application UI and cross-platform framework |
| Dart | Application programming language |
| SQLite / `sqflite` | Local database |
| `sqflite_common_ffi` | SQLite FFI support |
| `path_provider` | Local filesystem/application paths |
| `path` | Filesystem path manipulation |
| `pdf` | PDF document generation |
| `printing` | PDF printing/sharing-related functionality |
| `crypto` | Password hashing |
| `file_selector` | File and folder selection |
| `share_plus` | Sharing generated files |
| Flutter CustomPainter | Custom dashboard charts and visual components |

The application does not use a third-party charting package for its dashboard charts. The income/expense trend and expense-category donut charts are implemented with Flutter's custom painting APIs.

No external state-management package is listed in `pubspec.yaml`; the application primarily uses Flutter's built-in widget state, controllers, and `ValueNotifier`-based mechanisms.

---

## Project Structure

The uploaded project uses a relatively flat `lib/` structure.

### Application Entry Point

- `lib/main.dart`
  - Starts the application
  - Handles authentication/lock state
  - Builds the main application shell
  - Defines the main navigation tabs
  - Provides Quick Add functionality
  - Handles low-stock and unpaid-transaction reminders

### Main Screens

- `overview_screen.dart` — Dashboard and business overview
- `transactions_screen.dart` — Transaction list, filtering, summaries, and PDF reporting
- `invoices_screen.dart` — Invoice management and payment recording
- `companies_screen.dart` — Company management and balance filtering
- `inventory_screen.dart` — Inventory entry point for materials, products, and units
- `reports_screen.dart` — CSV export tools
- `settings_screen.dart` — Application settings and security controls

### Company & Business Profile

- `add_company_screen.dart` — Add company workflow
- `company_profile_screen.dart` — Business information and invoice configuration

### Inventory

- `materials_screen.dart` — Material management
- `add_material_screen.dart` — Material creation/editing
- `products_screen.dart` — Product management
- `add_product_screen.dart` — Product creation/editing
- `units_screen.dart` — Unit management
- `add_unit_dialog.dart` — Unit creation dialog

### Transactions

- `add_transaction_screen.dart` — Create/edit transactions
- `transaction_detail_dialog.dart` — Transaction details and payment/data operations
- `transaction_status_utils.dart` — Transaction payment-status calculations
- `unpaid_transactions_screen.dart` — Outstanding transaction view
- `ledger_screen.dart` — Company ledger
- `material_ledger_screen.dart` — Material ledger
- `product_ledger_screen.dart` — Product ledger

### Invoices

- `add_invoice_screen.dart` — Invoice creation/editing
- `invoice_preview_screen.dart` — Invoice preview
- `invoice_pdf_service.dart` — Invoice PDF generation

### Expenses

- `expenses_screen.dart` — Expense management
- `add_expense_screen.dart` — Add/edit expenses
- `expense_setup_screens.dart` — Expense categories, balances, and balance history

### Database & Storage

- `database_helper.dart` — SQLite database creation, migrations, queries, and data operations
- `backup_service.dart` — JSON backup and restore
- `export_file_service.dart` — Local file saving and sharing
- `csv_export_service.dart` — CSV generation

### Authentication & Protection

- `auth_service.dart` — Password setup, verification, hashing, and lockout
- `login_screen.dart` — Password setup/unlock screen
- `change_password_screen.dart` — Password changes
- `delete_password_screen.dart` — Delete-password configuration
- `delete_protection_service.dart` — Delete protection
- `delete_confirm.dart` — Protected deletion confirmation

### PDF Reporting

- `invoice_pdf_service.dart` — Invoice PDFs
- `transaction_report_pdf_service.dart` — Transaction/ledger PDF reports

### UI Components

The `lib/widgets/` directory contains reusable visual components:

- `glass.dart` — Glass/translucent UI surfaces and adaptive text
- `glass_tab_bar.dart` — Animated glass-style tab navigation
- `wave_background.dart` — Custom wave background
- `app_background_controller.dart` — Background state and brightness control
- `mini_charts.dart` — Dashboard charts
- `app_loading_indicator.dart` — Loading indicators

---

## Requirements

The uploaded `pubspec.yaml` specifies:

- Flutter
- Dart SDK `^3.12.2`

The application also requires the dependencies listed in `pubspec.yaml`.

Because only the `lib/` folder and `pubspec.yaml` were supplied for this README generation, platform-specific project folders such as `android/`, `windows/`, `macos/`, `ios/`, and `linux/` were not available for inspection.

The source does include `sqflite_common_ffi`, file-selection, filesystem, PDF, and sharing functionality, indicating support for local filesystem/database workflows beyond a purely web-based application. The exact set of configured Flutter target platforms cannot be conclusively determined from the uploaded files alone.

---

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/abdullah-devc/business-manager.git
Then enter the project directory:

cd business-manager
2. Install dependencies

Run:

flutter pub get

This downloads the packages declared in pubspec.yaml.

3. Check Flutter setup

Run:

flutter doctor

Resolve any required Flutter SDK, platform toolchain, or device issues reported by the command.

4. Run the application

Run:

flutter run

If multiple devices or platforms are available, Flutter can be instructed to run on a specific device using its normal device-selection options.

For example:

flutter devices

can be used to view available targets.

The exact desktop/mobile platform configuration should be verified against the platform folders in the complete repository.

5. Build the application

Flutter build commands can be used for the platform configured in the repository.

For example:

flutter build apk

can be used when an Android target is configured.

For desktop targets, use the corresponding Flutter build command for the platform configured in the repository.

The uploaded files do not include the platform-specific project directories, so this README does not prescribe a platform build configuration that could not be verified.
