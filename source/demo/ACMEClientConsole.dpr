program ACMEClientConsole;

{$APPTYPE CONSOLE}
{$WARN SYMBOL_PLATFORM OFF}

{$R 'version.res' 'version.rc'}

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Generics.Collections,
  OpenSSL3.Types,
  OpenSSL3.Lib,
  ACME.Types,
  ACME.Orders;

type
  TACMEClientConsole = class
  private
    FACMEOrders: TACMEOrders;
  protected
    property ACMEOrders: TACMEOrders read FACMEOrders;
    procedure CreateNewCertificate;
    function GetAccountEmail: string;
    function GetCSRSubject(const ADefaultEmail: string = ''): TCsrSubject;
    function GetDomains: TArray<string>;
    procedure OnLogEvent(ASender: TObject; AMessage: string);
    procedure RenewExistingCertificate;
    procedure ResumeExistingOrder;
    function SelectChallengeType: TChallengeOptions;
    function SelectProvider: TAcmeProvider;
    function ShowMainMenu: Integer;
    procedure AutoRenew;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute;

  end;

  // Global ACME Orders instance
var
  Console: TACMEClientConsole;

  // Event handlers for TACMEOrders
procedure TACMEClientConsole.OnLogEvent(ASender: TObject; AMessage: string);
begin
  WriteLn(AMessage);
end;

function TACMEClientConsole.SelectProvider: TAcmeProvider;
var
  LChoice: string;
  LIndex: Integer;
  LProviders: TArray<TAcmeProvider>;
begin
  WriteLn;
  WriteLn('=== ACME Provider Selection ===');
  WriteLn;
  LProviders := ACMEOrders.Providers.GetKnownProviders;
  for LIndex := 0 to High(LProviders) do
    WriteLn(Format('%d. %s - %s', [LIndex + 1, LProviders[LIndex].Name,
      LProviders[LIndex].Description]));
  WriteLn;
  Write('Select provider (1-' + IntToStr(Length(LProviders)) +
    '): ');
  ReadLn(LChoice);

  LIndex := StrToIntDef(LChoice, 1) - 1;
   

  if (LIndex < 0) or (LIndex > High(LProviders)) then
    LIndex := -1; // Default to staging

  Result := LProviders[LIndex];
  WriteLn('Selected: ', Result.Name);
  WriteLn('Directory: ', Result.DirectoryUrl);
  WriteLn;
end;

destructor TACMEClientConsole.Destroy;
begin
  FACMEOrders.Free;
  inherited;
end;

function TACMEClientConsole.GetAccountEmail: string;
begin
  Write('Enter account email address: ');
  ReadLn(Result);
  if Result = '' then
    raise Exception.Create('Account email is required');
end;

function TACMEClientConsole.GetDomains: TArray<string>;
var
  LInput: string;
  LDomains: TStringList;
  LIndex: Integer;
begin
  WriteLn('Enter domains (comma-separated, e.g., example.com,www.example.com): ');
  ReadLn(LInput);
  if LInput = '' then
    raise Exception.Create('At least one domain is required');

  LDomains := TStringList.Create;
  try
    LDomains.CommaText := LInput;
    SetLength(Result, LDomains.Count);
    for LIndex := 0 to LDomains.Count - 1 do
    begin
      Result[LIndex] := Trim(LDomains[LIndex]);
      if Result[LIndex] = '' then
        raise Exception.Create('Empty domain not allowed');
    end;
  finally
    LDomains.Free;
  end;
end;

function TACMEClientConsole.GetCSRSubject(const ADefaultEmail: string = '')
  : TCsrSubject;
var
  LInput: string;
begin
  WriteLn;
  WriteLn('=== Certificate Subject Information ===');
  WriteLn('Please provide information for the certificate:');
  WriteLn;

  // Country (required)
  repeat
    Write('Country (2-letter code, e.g., US, AU): ');
    ReadLn(LInput);
    Result.Country := Trim(LInput);
    if Result.Country = '' then
      WriteLn('ERROR: Country code is required.');
  until Result.Country <> '';

  // State (required)
  repeat
    Write('State/Province: ');
    ReadLn(LInput);
    Result.State := Trim(LInput);
    if Result.State = '' then
      WriteLn('ERROR: State/Province is required.');
  until Result.State <> '';

  // Locality (required)
  repeat
    Write('City/Locality: ');
    ReadLn(LInput);
    Result.Locality := Trim(LInput);
    if Result.Locality = '' then
      WriteLn('ERROR: City/Locality is required.');
  until Result.Locality <> '';

  // Organization (required)
  repeat
    Write('Organization: ');
    ReadLn(LInput);
    Result.Organization := Trim(LInput);
    if Result.Organization = '' then
      WriteLn('ERROR: Organization is required.');
  until Result.Organization <> '';

  // Organizational Unit (optional)
  Write('Organizational Unit (optional): ');
  ReadLn(LInput);
  Result.OrganizationalUnit := Trim(LInput);

  // Email Address (optional, can use default)
  if ADefaultEmail <> '' then
    Write('Email Address (default: ' + ADefaultEmail +
      ', press ENTER to use default): ')
  else
    Write('Email Address (optional): ');
  ReadLn(LInput);
  if Trim(LInput) = '' then
    Result.EmailAddress := ADefaultEmail
  else
    Result.EmailAddress := Trim(LInput);

  // CommonName will be auto-set to first domain by ACME.Orders
  Result.CommonName := '';

  WriteLn;
  WriteLn('Subject information collected successfully.');
  WriteLn;
end;

function TACMEClientConsole.SelectChallengeType: TChallengeOptions;
var
  LChoice: string;
  LPortInput: string;
begin
  WriteLn;
  WriteLn('=== Challenge Type Selection ===');
  WriteLn('1. HTTP-01 Challenge (requires web server access)');
  WriteLn('2. DNS-01 Challenge (requires DNS record creation)');
  WriteLn;
  Write('Select challenge type (1-2, default 1): ');
  ReadLn(LChoice);

  if (LChoice = '') or (LChoice = '1') then
    Result.ChallengeType := ctHttp01
  else if LChoice = '2' then
    Result.ChallengeType := ctDns01
  else
    raise Exception.Create('Invalid challenge type selection');

  WriteLn('Selected: ', IfThen(Result.ChallengeType = ctHttp01, 'HTTP-01',
    'DNS-01'));

  // Prompt for HTTP port if HTTP-01 is selected
  if Result.ChallengeType = ctHttp01 then
  begin
    WriteLn;
    Write('Enter HTTP server port (default 80): ');
    ReadLn(LPortInput);
    if LPortInput = '' then
      Result.HTTPPort := 80
    else
      Result.HTTPPort := StrToIntDef(LPortInput, 80);
    WriteLn('HTTP Port: ', Result.HTTPPort);
  end
  else
  begin
    Result.HTTPPort := 80; // Default value for DNS-01 (not used)
  end;

  WriteLn;
end;

constructor TACMEClientConsole.Create;
begin
  inherited;
  FACMEOrders := TACMEOrders.Create;
  FACMEOrders.OnLog := OnLogEvent;
end;

procedure TACMEClientConsole.CreateNewCertificate;
var
  LProvider: TAcmeProvider;
  LEmail: string;
  LDomains: TArray<string>;
  LChallengeOptions: TChallengeOptions;
  LCsrSubject: TCsrSubject;
  LOrderFile: string;
begin
  try
    // Step 1: Select provider
    LProvider := SelectProvider;

    // Step 2: Get account email
    LEmail := GetAccountEmail;

    // Step 3: Get domains
    LDomains := GetDomains;

    // Step 4: Select challenge type and options
    LChallengeOptions := SelectChallengeType;

    // Step 5: Get CSR subject information
    LCsrSubject := GetCSRSubject(LEmail);

    // Set the CommonName to the first domain
    LCsrSubject.CommonName := LDomains[0];

    if ACMEOrders.NewOrder(LProvider, LEmail, LDomains, LChallengeOptions,
      LCsrSubject, LOrderFile) then
      WriteLn('Certificate creation completed successfully! Order file: ' +
        LOrderFile)
    else
      WriteLn('Certificate creation failed.');

  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure TACMEClientConsole.ResumeExistingOrder;
var
  LCertFiles: TArray<string>;
  I: Integer;
  LResumeChoice: string;
  LIndex: Integer;
begin
  try
    LCertFiles := ACMEOrders.FindCertificateFiles;
    if Length(LCertFiles) = 0 then
    begin
      WriteLn('No existing certificates found. Please create a new certificate first.');
    end
    else
    begin
      WriteLn('Select certificate to resume:');
      for I := 0 to High(LCertFiles) do
      begin
        WriteLn('  ', I + 1, '. ', LCertFiles[I]);
      end;
      Write('Enter choice (1-', Length(LCertFiles), '): ');
      ReadLn(LResumeChoice);
      LIndex := StrToIntDef(LResumeChoice, -1);
      if (LIndex >= 0) and (LIndex < Length(LCertFiles)) then
      begin
        if ACMEOrders.ResumeExistingOrder(LCertFiles[LIndex]) then
          WriteLn('Order resumed successfully!')
        else
          WriteLn('Order resume failed.');
      end
      else
      begin
        WriteLn('Invalid choice.');
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure TACMEClientConsole.RenewExistingCertificate;
var
  LValidCertificates: TArray<string>;
  I: Integer;
  LChoice: string;
  LIndex: Integer;
begin
  try
    // Find available certificate files
    LValidCertificates := ACMEOrders.FindCertificateFiles(True);
    if Length(LValidCertificates) = 0 then
    begin
      WriteLn('No existing certificates found. Please create a new certificate first.');
      Exit;
    end;

    // Let user select which certificate to renew
    WriteLn('Available valid certificates to renew:');
    for I := 0 to High(LValidCertificates) do
    begin
      WriteLn('  ', I + 1, '. ', LValidCertificates[I]);
    end;
    WriteLn;

    Write('Select certificate to renew (1-', Length(LValidCertificates), '): ');
    ReadLn(LChoice);

    LIndex := StrToIntDef(LChoice, 0) - 1;
    if (LIndex < 0) or (LIndex >= Length(LValidCertificates)) then
    begin
      WriteLn('Invalid selection.');
      Exit;
    end;

    if ACMEOrders.RenewExistingCertificate(LValidCertificates[LIndex]) then
      WriteLn('Certificate renewed successfully!')
    else
      WriteLn('Certificate renewal failed.');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure TACMEClientConsole.AutoRenew;
var
  LSuccess: TArray<string>;
  LFailed: TArray<string>;
  LFile: string;
begin
  WriteLn('=== AUTO RENEW ===');
  WriteLn('Checking for certificates that need renewal...');
  WriteLn;

  try
    ACMEOrders.AutoRenew(LSuccess, LFailed);

    WriteLn;
    WriteLn('=== AUTO RENEW SUMMARY ===');
    WriteLn('Successfully renewed: ', Length(LSuccess));
    WriteLn('Failed: ', Length(LFailed));

    if Length(LSuccess) > 0 then
    begin
      WriteLn;
      WriteLn('Successfully renewed certificates:');
      for LFile in LSuccess do
        WriteLn('  - ', LFile);
    end;

    if Length(LFailed) > 0 then
    begin
      WriteLn;
      WriteLn('Failed to renew:');
      for LFile in LFailed do
        WriteLn('  - ', LFile);
    end;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      raise; // Re-raise for caller to handle exit code
    end;
  end;
end;

function TACMEClientConsole.ShowMainMenu: Integer;
var
  LChoice: string;
begin
  WriteLn;
  WriteLn('=== ACME Certificate Management ===');
  WriteLn('Certificate Storage: ', ACMEOrders.StorageFolder);
  WriteLn;
  WriteLn('1. Create new certificate');
  WriteLn('2. Resume existing order');
  WriteLn('3. Renew existing certificate');
  WriteLn('4. Auto renew');
  WriteLn('5. Exit');
  WriteLn;

  Write('Select option (1-5): ');
  ReadLn(LChoice);
  Result := StrToIntDef(LChoice, -1);
end;

procedure TACMEClientConsole.Execute;
var
  LChoice: Integer;
  LParam: string;
  I: Integer;
begin
  // Check for command-line parameters
  for I := 1 to ParamCount do
  begin
    LParam := UpperCase(ParamStr(I));

    if LParam = '/AUTORENEW' then
    begin
      WriteLn('=== AUTO RENEW MODE ===');
      WriteLn('Running automatic certificate renewal...');
      WriteLn;
      try
        AutoRenew;
        WriteLn;
        WriteLn('Auto-renewal process completed.');
        Exit; // Exit after auto-renewal
      except
        on E: Exception do
        begin
          WriteLn('ERROR: Auto-renewal failed');
          WriteLn('Error: ', E.ClassName, ': ', E.Message);
          ExitCode := 1; // Set non-zero exit code for failure
          Exit;
        end;
      end;
    end;
  end;

  // Interactive mode - show menu
  while True do
  begin

    LChoice := ShowMainMenu;
    WriteLn;

    case LChoice of
      1:
        begin
          try
            CreateNewCertificate;
          except
            on E: Exception do
            begin
              WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
            end;
          end;
        end;

      2:
        begin
          try
            ResumeExistingOrder;
          except
            on E: Exception do
            begin
              WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
            end;
          end;
        end;

      3:
        begin
          try
            RenewExistingCertificate;
          except
            on E: Exception do
            begin
              WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
            end;
          end;
        end;
      4:
        begin
          try
            AutoRenew;
          except
            on E: Exception do
            begin
              WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
            end;
          end;
        end;

      5:
        begin
          WriteLn('Goodbye!');
          Break;
        end;

    else
      begin
        WriteLn('Invalid choice. Please select 1-4.');
      end;
    end;

  end;

end;

begin
  try
    Console := TACMEClientConsole.Create;
    try
      Console.Execute;
    finally
      Console.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
    end;
  end;

  if DebugHook <> 0 then
  begin
    WriteLn;
    WriteLn('Press ENTER to continue...');
    ReadLn;
    WriteLn;
  end;

end.
