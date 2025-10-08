# Delphi ACME Client for Let's Encrypt

A comprehensive Delphi implementation of the ACME (Automated Certificate Management Environment) protocol for obtaining and managing SSL/TLS certificates from Let's Encrypt and other ACME-compliant certificate authorities.

## Features

- 🔐 **Full ACME v2 Protocol Support** - Compatible with Let's Encrypt and other ACME providers
- 🔑 **RSA 2048-bit Key Generation** - Secure key pair generation using OpenSSL 3.x
- ✅ **HTTP-01 Challenge** - Web server validation with configurable ports
- 🌐 **DNS-01 Challenge** - DNS TXT record validation with local DNS verification
- 📜 **Certificate Management** - Create, resume, renew, and auto-renew certificates
- 💾 **Persistent Storage** - JSON-based storage for accounts, orders, and certificates
- 🔄 **Auto-Renewal** - Intelligent automatic renewal based on actual certificate expiry dates
- 🖥️ **Console & GUI Applications** - Both command-line and graphical interfaces
- 📊 **Comprehensive Logging** - Detailed operation logs with event-driven architecture
- 🔧 **Provider Management** - Support for multiple ACME providers (production/staging)
- 🌐 **TIdHTTPServer Integration** - `TACMEIndyHTTPServer` component for automatic SSL management
- 🎨 **VCL Forms** - Reusable certificate management and DNS challenge forms
- 📅 **Certificate Expiry Parsing** - Read actual expiry dates from X.509 certificates using OpenSSL
- 🔀 **Automatic Certificate Splitting** - Splits certificate bundles for Indy compatibility
- ⏰ **Thread-Based Renewal** - Background renewal timer compatible with NT services

## Architecture

### Core Components

#### `TACMEIndyHTTPServer` - SSL Management for TIdHTTPServer

The `TACMEIndyHTTPServer` component provides seamless SSL certificate management for Indy HTTP servers:

**Key Features:**
- Automatic SSL configuration for `TIdHTTPServer`
- Certificate renewal with server restart handling
- Thread-based automatic renewal timer (NT service compatible)
- Automatic certificate bundle splitting for Indy compatibility
- Real-time certificate file change detection
- Comprehensive logging and error handling

**Properties:**
- `HTTPServer: TIdHTTPServer` - The HTTP server to manage
- `OrderName: string` - Certificate order file name
- `RenewalIntervalHours: Integer` - Auto-renewal check interval (default: 24 hours)
- `OnLog: TOnLog` - Logging event

**Main Methods:**
```delphi
procedure ConfigureSSL;  // Configure SSL with current certificate
procedure ClearSSL;      // Remove SSL configuration
procedure RenewSSL;      // Trigger manual certificate renewal
```

**Usage Example:**
```delphi
var
  LHTTPServer: TIdHTTPServer;
  LACMEServer: TACMEIndyHTTPServer;
begin
  LHTTPServer := TIdHTTPServer.Create(nil);
  LACMEServer := TACMEIndyHTTPServer.Create;
  try
    LACMEServer.HTTPServer := LHTTPServer;
    LACMEServer.OrderName := 'order_example_com.json';
    LACMEServer.RenewalIntervalHours := 24;
    LACMEServer.ConfigureSSL;
    
    LHTTPServer.Active := True;
    // Server now running with SSL
  finally
    LACMEServer.Free;
    LHTTPServer.Free;
  end;
end;
```

#### `TACMEClient` - Low-Level ACME Protocol Handler

The `TACMEClient` class provides direct ACME protocol implementation:

**Key Features:**
- ACME directory discovery and initialization
- Account creation and management (with KID-based authentication)
- RSA key pair generation and JWS (JSON Web Signature) signing
- Order creation and authorization handling
- Challenge triggering and validation polling
- Certificate finalization and download
- HTTP-01 and DNS-01 challenge support
- Built-in HTTP server for HTTP-01 challenges

**Main Methods:**
```delphi
procedure Initialize(const ADirectoryUrl: string);
procedure CreateOrLoadAccount(const AEmail: string; const ATosAgreed: Boolean);
function NewOrder(const ADomains: TArray<string>): TJSONObject;
function TriggerHttp01AndValidate(const AAuthUrl: string): Boolean;
function TriggerDns01AndValidate(const AAuthUrl: string): Boolean;
function FinalizeAndDownloadWithCsr(const AFinalizeUrl: string; 
  const ACsrDer: TBytes; out ACertificateUrl: string): string;
```

**Usage Example:**
```delphi
var
  LClient: TAcmeClient;
begin
  LClient := TAcmeClient.Create;
  try
    LClient.Initialize('https://acme-staging-v02.api.letsencrypt.org/directory');
    LClient.GenerateRsaKeyPair2048;
    LClient.CreateOrLoadAccount('admin@example.com', True);
    // ... perform ACME operations
  finally
    LClient.Free;
  end;
end;
```

#### `TACMEOrders` - High-Level Certificate Management

The `TACMEOrders` class provides user-friendly certificate management:

**Key Features:**
- Complete certificate lifecycle management
- Automatic CSR (Certificate Signing Request) generation
- Order state persistence and resumption
- Certificate renewal with archive management
- Multi-provider support
- Event-driven user interaction (OnLog, OnHTTPChallengeContinue, OnDNSChallengeContinue)
- Intelligent auto-renewal with actual certificate expiry checking
- Certificate bundle detection and splitting for Indy
- DNS TXT record validation
- X.509 certificate expiry date parsing

**Main Methods:**
```delphi
function NewOrder(const AProvider: TAcmeProvider; const AEmail: string;
  const ADomains: TArray<string>; const AChallengeOptions: TChallengeOptions;
  const ACsrSubject: TCsrSubject; out AOrderFile: string): Boolean;

function ResumeExistingOrder(const AOrderFile: string = ''): Boolean;

function RenewExistingCertificate(const AOrderFile: string): Boolean;

procedure AutoRenew(out ASuccess: TArray<string>; 
  out AFailed: TArray<string>; const ADays: Integer = 30);

function FindCertificateFiles(AValidOnly: Boolean = False): TArray<string>;

function GetCertificateExpiryDate(const ACertificateFile: string): TDateTime;

function DNSChallengeValidate(const ARecordName, ARecordValue: string; 
  const ATimeout: Integer = 5000): Boolean;

function IsCertificateBundled(const AFileName: string): Boolean;

procedure SplitCertificateBundle(const AFileName: string);
```

**Usage Example:**
```delphi
var
  LOrders: TACMEOrders;
  LProvider: TAcmeProvider;
  LDomains: TArray<string>;
  LChallengeOptions: TChallengeOptions;
  LCsrSubject: TCsrSubject;
  LOrderFile: string;
begin
  LOrders := TACMEOrders.Create;
  try
    // Configure
    LProvider := LOrders.Providers.GetProviderByName('Let''s Encrypt Staging');
    LDomains := ['example.com', 'www.example.com'];
    LChallengeOptions.ChallengeType := ctHttp01;
    LChallengeOptions.HTTPPort := 80;
    
    // Set CSR subject
    LCsrSubject.Country := 'US';
    LCsrSubject.State := 'California';
    LCsrSubject.Locality := 'San Francisco';
    LCsrSubject.Organization := 'Example Inc';
    LCsrSubject.EmailAddress := 'admin@example.com';
    
    // Create certificate
    if LOrders.NewOrder(LProvider, 'admin@example.com', LDomains, 
                        LChallengeOptions, LCsrSubject, LOrderFile) then
      WriteLn('Certificate created: ', LOrderFile);
  finally
    LOrders.Free;
  end;
end;
```

#### `TACMEProviders` - Provider Management

Manages ACME provider configurations:

**Features:**
- Load/save provider configurations from JSON
- Default providers (Let's Encrypt Production/Staging)
- Provider lookup by name, ID, or URL
- Add/remove custom providers

**Main Methods:**
```delphi
function GetKnownProviders: TArray<TAcmeProvider>;
function GetProviderByName(const AName: string): TAcmeProvider;
function GetProviderById(const AId: string): TAcmeProvider;
procedure AddProvider(const AProvider: TAcmeProvider);
```

### VCL Forms (Reusable Components)

#### `TACMENewCertificateForm` - Certificate Creation Wizard

A 4-step wizard for creating new SSL certificates:

**Features:**
- Provider and account setup with Terms of Service agreement
- Multi-domain configuration (one per line)
- Complete CSR subject details entry
- Challenge type selection (HTTP-01 or DNS-01)
- Integration with DNS challenge form
- Input validation at each step

**Class Function:**
```delphi
class function CreateNewCertificate(AACMEOrders: TACMEOrders): Boolean;
```

#### `TACMEDNSChallengeForm` - DNS Challenge Assistant

Interactive form for DNS-01 challenge validation:

**Features:**
- Copy DNS record name and value to clipboard
- One-click "Copy All" for quick setup
- Local DNS validation using system DNS servers
- Real-time DNS query status with color-coded feedback
- Visual confirmation when DNS records are properly configured
- Integration with `TIdDNSResolver` for TXT record queries

**Class Function:**
```delphi
class function ShowDNSChallenge(const ARecordName, ARecordValue: string;
  AACMEOrders: TACMEOrders = nil): Boolean;
```

#### `TACMECertificateListForm` - Certificate Selection

Browse and manage certificate orders:

**Features:**
- List all orders with status, created date, and certificate expiry
- Color-coded status display (Green=Valid, Yellow=Pending, Orange=Ready, Red=Invalid)
- Delete orders with confirmation dialog
- Dual modes: Resume orders or Renew certificates
- Optional delete button visibility
- Real-time certificate expiry from X.509 files

**Class Function:**
```delphi
class function SelectCertificate(AACMEOrders: TACMEOrders;
  AMode: TCertificateListMode; AAllowDelete: Boolean;
  out ASelectedOrderFile: string): Boolean;
```

### Data Structures

#### `TAcmeProvider`
```delphi
TAcmeProvider = record
  Id: string;              // Unique identifier
  Name: string;            // Display name
  DirectoryUrl: string;    // ACME directory URL
  Description: string;     // Provider description
end;
```

#### `TCsrSubject`
```delphi
TCsrSubject = record
  Country: string;               // 2-character country code (required)
  State: string;                 // State or province (required)
  Locality: string;              // City (required)
  Organization: string;          // Organization name (required)
  OrganizationalUnit: string;    // Department (optional)
  EmailAddress: string;          // Contact email (optional)
  CommonName: string;            // Common name (automatically set to first domain)
end;
```

**Note:** The `CommonName` field is automatically populated with the first domain from your certificate request. You do not need to set this field manually - leave it empty and it will be set automatically by `TACMEOrders.NewOrder()`.

#### `TChallengeOptions`
```delphi
TChallengeOptions = record
  ChallengeType: TChallengeType;  // ctHttp01 or ctDns01
  HTTPPort: Integer;              // Port for HTTP-01 (default: 80)
end;
```

#### `TAcmeOrderState`
```delphi
TAcmeOrderState = record
  OrderUrl: string;
  FinalizeUrl: string;
  Status: string;                // pending, ready, valid, invalid
  Expires: string;
  Domains: TArray<string>;
  ChallengeType: TChallengeType;
  AuthUrls: TArray<string>;
  CertificateUrl: string;
  Created: TDateTime;
  HTTPPort: Integer;
  ProviderId: string;
  ProviderDirectoryUrl: string;
  // CSR subject details for renewal
  CsrCountry, CsrState, CsrLocality, CsrOrganization,
  CsrOrganizationalUnit, CsrEmailAddress, CsrCommonName: string;
end;
```

## Demo Applications

### 1. Console Application (`ACMEClientConsole.dpr`)

A full-featured command-line interface for certificate management.

**Features:**
- Interactive menu system
- Create new certificates with step-by-step prompts
- Resume incomplete orders
- Renew existing certificates
- List all certificates
- Provider selection
- Challenge type configuration

**Usage:**

*Interactive Mode:*
```bash
ACMEClientConsole.exe
```

*Auto-Renewal Mode (for scheduled tasks):*
```bash
ACMEClientConsole.exe /AUTORENEW
```

**Command-Line Parameters:**
- `/AUTORENEW` - Automatically renew all certificates expiring within 30 days and exit. Sets exit code 0 on success, 1 on failure. Perfect for Windows Task Scheduler or cron jobs.

**Menu Options:**
```
=== ACME Certificate Manager ===
1. Create New Certificate
2. Resume Existing Order
3. Renew Existing Certificate
4. Auto Renew
5. Exit

Storage folder: C:\ProgramData\DelphiACMEClient
```

### 2. GUI Application (`ACMEClientGUI.dpr`)

A modern Windows VCL graphical interface for certificate management.

**Features:**
- **New Certificate Wizard** - 4-step guided process with VCL forms:
  1. Provider & Account Setup
  2. Domain Configuration (multi-domain support)
  3. Certificate Subject Details
  4. Challenge Type Selection (HTTP-01 or DNS-01)
  
- **DNS Challenge Assistant** - Interactive DNS-01 validation:
  - Copy record name and value to clipboard
  - Local DNS validation button
  - Real-time verification feedback
  - Step-by-step instructions
  
- **Certificate List** - Browse and manage certificates:
  - Color-coded status indicators
  - Real certificate expiry dates (from X.509)
  - Delete orders with confirmation
  - Filter by status (valid/pending/etc.)
  
- **Resume Orders** - Visual list of pending orders with status
- **Renew Certificates** - Select and renew valid certificates
- **Auto Renew All** - Batch renewal with configurable expiry window
- **Real-time Logging** - View all ACME operations as they happen
- **Status Bar** - Current operation status display

### 3. HTTP Server Demo (`ACMEHTTPServerDemo.dpr`)

Complete HTTPS server example with automatic SSL certificate management.

**Features:**
- **TIdHTTPServer Integration** - Full Indy HTTP server with SSL
- **Static File Serving** - Serve HTML/CSS/JS from `html` subfolder
- **SSL Certificate Management**:
  - Create new certificates directly from the demo
  - Configure SSL with certificate selection
  - Manual certificate renewal
  - Verify certificate and key compatibility
  - Clear SSL configuration
  
- **Automatic Renewal**:
  - Thread-based renewal timer (NT service compatible)
  - Configurable renewal interval (hours)
  - Automatic server restart on certificate update
  
- **Server Controls**:
  - Start/Stop server
  - Configure port (default: 8080)
  - Enable/Disable SSL
  - Test server button (opens in browser)
  
- **Comprehensive Logging**:
  - Connection tracking (connect/disconnect)
  - Request logging with SSL status
  - Certificate file verification
  - Detailed SSL configuration display

**Usage Example:**
1. Launch `ACMEHTTPServerDemo.exe`
2. Click "New Certificate" to create SSL certificate
3. Select the certificate from dropdown
4. Click "Configure SSL"
5. Set port (e.g., 443 for HTTPS)
6. Enable "Enable SSL/HTTPS" checkbox
7. Click "Start Server"
8. Access via `https://localhost:443`

**Perfect for:**
- Testing TIdHTTPServer with SSL
- NT service development
- Automated certificate renewal in services
- Production HTTPS servers


## Installation

### Prerequisites

1. **Delphi** 10.x or later (VCL support required for GUI)
2. **OpenSSL 3.x** libraries:
   - `libcrypto-3.dll` (or `libcrypto-3-x64.dll` for 64-bit)
   - `libssl-3.dll` (or `libssl-3-x64.dll` for 64-bit)
   - `legacy.dll` (for legacy algorithm support)
3. **Indy Components** (usually included with Delphi)

### OpenSSL Libraries

**Download OpenSSL:**
The latest OpenSSL 3.x libraries for Windows can be downloaded from:
- **Official Windows builds:** [https://slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html)
- Download either the "Light" or full version (Light is sufficient for this application)
- Choose Win32 or Win64 based on your target platform
- OpenSSL 3.5.x (LTS) or 3.4.x recommended


**Installation:**
Copy the DLL files to one of these locations:
1. Your application directory (recommended for deployment)
2. Windows System32 directory (system-wide installation)
3. Any directory in your system PATH

**Required Files:**
- **Win32:** `libcrypto-3.dll`, `libssl-3.dll`, `legacy.dll`
- **Win64:** `libcrypto-3-x64.dll`, `libssl-3-x64.dll`, `legacy.dll`

### Project Structure

```
delphi-lets-encrypt/
├── source/
│   └── source/
│       ├── ACME.Client.pas              # Low-level ACME protocol
│       ├── ACME.Orders.pas              # High-level certificate management
│       ├── ACME.Providers.pas           # Provider configuration
│       ├── ACME.Types.pas               # Shared data types
│       ├── ACME.IndyHTTPServer.pas      # SSL management for TIdHTTPServer
│       ├── OpenSSL3.Lib.pas             # OpenSSL 3.x API bindings
│       ├── OpenSSL3.Helper.pas          # OpenSSL helper functions
│       ├── OpenSSL3.CSRGenerator.pas    # CSR generation
│       ├── OpenSSL3.Legacy.pas          # Legacy provider support
│       ├── OpenSSL3.Types.pas           # OpenSSL type definitions
│       └── forms/
│           └── vcl/
│               ├── ACME.NewCertificateForm.pas    # Certificate wizard
│               ├── ACME.DNSChallengeForm.pas      # DNS challenge assistant
│               └── ACME.CertificateListForm.pas   # Certificate browser
└── demo/
    ├── ACMEClientConsole.dpr        # Console application
    ├── ACMEClientGUI.dpr            # GUI application
    ├── ACMEHTTPServerDemo.dpr       # HTTP server demo
    ├── MainFormU.pas                # Main GUI form
    ├── HTTPServerDemoFormU.pas      # HTTP server demo form
    └── CertificateListFormU.pas     # (deprecated - moved to vcl/)
```

## Building

### Console Application

1. Open `demo/ACMEClientConsole.dproj` in Delphi
2. Build → Build ACMEClientConsole
3. Executable created in `demo/Win32/Debug` or `demo/Win32/Release`

### GUI Application

1. Open `demo/ACMEClientGUI.dproj` in Delphi
2. Build → Build ACMEClientGUI
3. Executable created in `demo/Win32/Debug` or `demo/Win32/Release`

### Required Search Paths

Ensure these paths are in your project search path:
- `source/source`
- `source/source/forms/vcl`

### HTTP Server Demo Build

1. Open `demo/ACMEHTTPServerDemo.dproj` in Delphi
2. Build → Build ACMEHTTPServerDemo
3. Create `html` subfolder in executable directory for static files
4. Executable created in `build/bin/Win32/Debug` or `build/bin/Win32/Release`

## Usage Guide

### Creating a New Certificate

#### Console:
```
1. Select "Create New Certificate"
2. Choose ACME provider (Let's Encrypt Staging for testing)
3. Enter email address
4. Enter domains (one per line)
5. Enter CSR subject details (Country, State, City, Organization)
6. Select challenge type (HTTP-01 or DNS-01)
7. Complete challenge validation
8. Certificate saved automatically
```

#### GUI:
1. Click **"New Certificate"**
2. Follow 4-step wizard:
   - Provider & Account
   - Domains
   - Certificate Subject
   - Challenge Type
3. Click **"Create Certificate"**
4. Follow prompts for challenge validation

### Challenge Types

#### HTTP-01 Challenge
- Requires web server on port 80 (or custom port)
- ACME server validates domain by accessing:
  `http://yourdomain.com/.well-known/acme-challenge/{token}`
- Automatically starts built-in HTTP server for validation
- Best for: Single domain certificates with web server access

#### DNS-01 Challenge (Enhanced)
- Requires adding TXT record to DNS zone
- Record name: `_acme-challenge.yourdomain.com`
- Record value: SHA-256 hash provided by the application
- **New Features:**
  - Interactive DNS challenge form with clipboard integration
  - Local DNS validation before submitting to ACME server
  - Queries system DNS servers using `TIdDNSResolver`
  - Color-coded validation feedback
  - Manual verification command suggestions
- Best for: Wildcard certificates or domains without web server
- **Validation:** Use the "Verify DNS Record" button to test propagation before proceeding

### Resuming an Order

If a certificate order was interrupted:
1. Select **"Resume Order"** (or **"Resume Existing Order"** in console)
2. Choose order from list
3. Complete any pending challenges
4. Certificate will be finalized

### Renewing Certificates

Let's Encrypt certificates are valid for 90 days. Renew before expiration:

1. Select **"Renew Certificate"**
2. Choose certificate from list
3. Renewal uses stored account and CSR details
4. Old certificate archived with timestamp
5. New certificate replaces old one

### Auto-Renewal

Automatically renew multiple certificates:

```delphi
procedure AutoRenew(out ASuccess: TArray<string>; 
                    out AFailed: TArray<string>;
                    const ADays: Integer = 30);
```

**Parameters:**
- `ASuccess`: Array of successfully renewed order files
- `AFailed`: Array of failed renewal order files
- `ADays`: Renew certificates expiring within this many days (default: 30)

**Features:**
- Scans all valid certificates
- **Reads actual certificate expiry dates** from X.509 files using OpenSSL
- Calculates days until expiry for each certificate
- Skips certificates not due for renewal (outside renewal window)
- Attempts renewal for certificates within expiry window
- Returns detailed success/failure lists with logging
- Archives old certificates with timestamps

**How It Works:**
1. Finds all valid certificates in storage
2. For each certificate:
   - Reads expiry date from certificate file (not estimation)
   - Calculates days remaining until expiry
   - If expiry ≤ ADays days: renews certificate
   - If expiry > ADays days: skips (logs "not due for renewal")
3. Returns arrays of successful and failed renewals

**Recommended Schedule:**
- Run daily at 2 AM
- Use 30-day renewal window (Let's Encrypt recommends renewing at 30 days)
- Log all operations to file
- Send alerts on failures
- Use `/AUTORENEW` parameter for scheduled tasks

## Storage

By default, all data is stored in:
```
Windows: C:\ProgramData\DelphiACMEClient\
```

**Files:**
- `accounts.json` - ACME account information (email, KID, private keys)
- `providers.json` - ACME provider configurations
- `order_*.json` - Order state files
- `certificate_*.pem` - Full certificate chain (PEM format)
- `server_*.pem` - Server certificate only (split from bundle for Indy)
- `chain_*.pem` - Intermediate/root certificates (split from bundle for Indy)
- `private_*.key` - Private keys (PEM format)
- `csr_*.pem` - Certificate signing requests (reference only)
- `certificate_*.pem.backup_YYYYMMDD_HHNNSS` - Archived certificates from renewals

**Security Notes:**
- Private keys are stored in PEM format
- Protect `private_*.key` files - they are critical for certificate renewal
- Backup account private keys for disaster recovery
- Consider encrypting the storage directory

## Configuration

### Default Providers

Two providers are configured by default:

1. **Let's Encrypt Production**
   - URL: `https://acme-v02.api.letsencrypt.org/directory`
   - Use for production certificates
   - Rate limits apply

2. **Let's Encrypt Staging**
   - URL: `https://acme-staging-v02.api.letsencrypt.org/directory`
   - Use for testing
   - Certificates not trusted by browsers
   - Higher rate limits

### Adding Custom Providers

```delphi
var
  LProvider: TAcmeProvider;
begin
  LProvider := TAcmeProvider.Create(
    'custom-provider',
    'Custom ACME Provider',
    'https://acme.example.com/directory',
    'Custom ACME CA'
  );
  ACMEProviders.AddProvider(LProvider);
end;
```

## API Reference

### Event Handlers

#### `TOnLog`
```delphi
TOnLog = procedure(ASender: TObject; AMessage: string) of object;
```
Called for all logging operations. Implement to capture logs.

#### `OnHTTPChallengeContinue`
```delphi
property OnHTTPChallengeContinue: TNotifyEvent;
```
Called before starting HTTP-01 challenge validation. User can set up web server.

#### `OnDNSChallengeContinue`
```delphi
property OnDNSChallengeContinue: TNotifyEvent;
```
Called before starting DNS-01 challenge validation. User can create DNS record.

### Common Patterns

#### Setting up logging:
```delphi
procedure TMyClass.LogHandler(ASender: TObject; AMessage: string);
begin
  WriteLn(AMessage);
  // Or: LogMemo.Lines.Add(AMessage);
end;

LOrders.OnLog := LogHandler;
LOrders.ACMEClient.OnLog := LogHandler;
```

#### Error handling:
```delphi
try
  if not LOrders.NewOrder(...) then
    ShowMessage('Certificate creation failed');
except
  on E: EAcmeError do
    ShowMessage('ACME Error: ' + E.Message);
  on E: Exception do
    ShowMessage('Error: ' + E.Message);
end;
```

## Troubleshooting

### "Failed to load OpenSSL library"
- **Download OpenSSL:** Get the latest Windows builds from [https://slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html)
- Ensure OpenSSL 3.x DLLs are in application directory or PATH
- Check for 32-bit vs 64-bit DLL mismatch (Win32 app needs 32-bit DLLs)
- Verify DLL versions are compatible (OpenSSL 3.4.x or 3.5.x recommended)
- Required files: `libcrypto-3.dll`, `libssl-3.dll`, `legacy.dll` (or `-x64` versions)

### "Account validation failed"
- Check internet connection
- Verify provider URL is correct
- Check firewall settings
- Review account KID in logs

### "Challenge validation timeout"
- **HTTP-01**: Verify port 80 is accessible from internet
- **HTTP-01**: Check firewall rules
- **DNS-01**: Verify TXT record created correctly
- **DNS-01**: Wait for DNS propagation (can take minutes)

### "Order is invalid"
- Order may have expired (orders valid for 7 days)
- Previous challenge validation may have failed
- Create a new order instead of resuming

### "ERR_SSL_PROTOCOL_ERROR" or SSL Handshake Failures
- **Common Cause**: Certificate bundle not split for Indy
  - Solution: Call `ConfigureSSL` which automatically splits certificates
  - Or manually: `SplitCertificateBundle(certfile)`
  
- **Verify Files Exist**:
  - Check that `server_*.pem` and `chain_*.pem` files exist
  - Use "Verify Certificate" button in HTTP Server Demo
  
- **TIdServerIOHandlerSSLOpenSSL Configuration**:
  - Don't set both `Method` and `SSLVersions` (causes conflicts)
  - Use `Method := sslvTLSv1_2` only
  - Ensure `Mode := sslmServer`

### "DNS validation failed"
- Verify TXT record was created correctly
- Wait for DNS propagation (can take minutes to hours)
- Use "Verify DNS Record" button for local validation
- Manually test: `nslookup -type=TXT _acme-challenge.yourdomain.com`
- Check DNS server accessibility

### Rate Limits (Let's Encrypt)
- **Production**: 50 certificates per domain per week
- **Staging**: Much higher limits for testing
- Use staging environment for development
- See: https://letsencrypt.org/docs/rate-limits/

## Scheduling Auto-Renewal

### Windows Task Scheduler

Create a scheduled task to automatically renew certificates:

**Using Command-Line Parameter:**
```batch
C:\Path\To\ACMEClientConsole.exe /AUTORENEW
```

**Task Configuration:**
- **Trigger:** Daily at 2:00 AM
- **Action:** Start a program
  - Program: `C:\Path\To\ACMEClientConsole.exe`
  - Arguments: `/AUTORENEW`
- **Settings:**
  - Run whether user is logged on or not
  - Run with highest privileges
  - Configure for: Windows 10

**PowerShell Script Example:**
```powershell
$action = New-ScheduledTaskAction -Execute "C:\Path\To\ACMEClientConsole.exe" -Argument "/AUTORENEW"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ACME Certificate Auto-Renewal" -Description "Automatically renew SSL certificates"
```

**Exit Codes:**
- `0` - Success (all renewals completed or no certificates due for renewal)
- `1` - Failure (one or more renewals failed or exception occurred)

## Best Practices

1. **Testing**: Always test with Let's Encrypt Staging first
2. **Renewal**: Renew certificates at 30 days before expiry (Let's Encrypt recommendation)
3. **Backups**: Backup private keys and account data regularly
4. **Monitoring**: Implement automated renewal monitoring and alerts
5. **Security**: Protect private keys, use strong file permissions
6. **Logging**: Enable comprehensive logging for troubleshooting
7. **Scheduling**: Use `/AUTORENEW` parameter for scheduled tasks
8. **Validation**: Ensure challenge endpoints are accessible before starting
9. **DNS-01**: Use "Verify DNS Record" button before proceeding with ACME validation
10. **TIdHTTPServer**: Use `TACMEIndyHTTPServer` for automatic SSL management and renewal
11. **Certificate Expiry**: Use `GetCertificateExpiryDate` to read actual expiry dates from certificates

## Dependencies

- **Delphi RTL** - Standard runtime library
- **Indy** - HTTP client components
- **OpenSSL 3.x** - Cryptographic operations

## License

[Specify your license here]

## Support

For issues, questions, or contributions:
- Review logs in the application storage directory
- Check demo applications for usage examples
- Review inline code documentation
- Test with Let's Encrypt Staging environment first

## Advanced Features

### Certificate Bundle Splitting

Let's Encrypt provides certificates as a bundle (server cert + intermediate + root). Indy requires these to be separate files.

**Automatic Splitting:**
- `TACMEOrders` automatically detects bundled certificates
- Calls `SplitCertificateBundle` after finalization
- Creates `server_*.pem` and `chain_*.pem` files
- `TACMEIndyHTTPServer.ConfigureSSL` uses split files automatically

**Manual Splitting:**
```delphi
if ACMEOrders.IsCertificateBundled('certificate_example_com.pem') then
  ACMEOrders.SplitCertificateBundle('certificate_example_com.pem');
```

### Certificate Expiry Date Parsing

Read actual expiry dates from X.509 certificates:

```delphi
var
  LExpiryDate: TDateTime;
begin
  LExpiryDate := ACMEOrders.GetCertificateExpiryDate('certificate_example_com.pem');
  if LExpiryDate > 0 then
    WriteLn('Expires: ', DateTimeToStr(LExpiryDate));
end;
```

**Uses OpenSSL 3.x API:**
- `X509_get0_notAfter` - Get expiry time
- `ASN1_TIME_print` - Parse to string
- Accurate to the second
- Returns TDateTime (0 on error)

### DNS Challenge Validation

Verify DNS TXT records before ACME validation:

```delphi
if ACMEOrders.DNSChallengeValidate('_acme-challenge.example.com', 'token_value') then
  WriteLn('DNS record verified!')
else
  WriteLn('DNS record not found or incorrect');
```

**Features:**
- Queries system DNS servers (from Windows registry)
- Falls back to Google DNS (8.8.8.8) if needed
- Configurable timeout (default: 5 seconds)
- Uses `TIdDNSResolver` for TXT record queries
- Comprehensive logging of DNS queries

### Thread-Based Renewal Timer

For NT service compatibility, use thread-based renewal:

```delphi
// TACMEIndyHTTPServer uses TACMERenewalThread internally
// No message loop required - works in services!
LACMEServer.RenewalIntervalHours := 24; // Check every 24 hours
```

**Benefits:**
- Works in NT services (no message pump required)
- Independent background thread
- Automatic server restart on certificate renewal
- Configurable check interval

## Roadmap

Potential future enhancements:
- ECDSA key support (P-256, P-384)
- Certificate revocation API
- External account binding (EAB)
- TLS-ALPN-01 challenge support
- REST API for remote management
- Web-based management interface
- Docker container support
- Multiple certificate profiles
- Certificate deployment automation

## Acknowledgments

- **Let's Encrypt** - Free certificate authority
- **OpenSSL** - Cryptographic library
- **Indy Project** - HTTP/SSL components
- **Delphi Community** - Support and feedback
