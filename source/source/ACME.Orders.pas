unit ACME.Orders;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.Math,
  System.DateUtils,

  Winapi.Windows,
  Winapi.IpHlpApi,
  Winapi.IpTypes,
  IdDNSResolver,
  OpenSSL3.Types,
  OpenSSL3.Helper,
  OpenSSL3.CSRGenerator,
  ACME.Client,
  ACME.Providers,
  ACME.Types;

type
  TACMEOrders = class(TAcmeObject)
  private
    FClient: TAcmeClient;
    FProviders: TACMEProviders;
    FStorageFolder: string;
    FOnHTTPChallengeContinue: TNotifyEvent;
    FOnDNSChallengeContinue: TOnDNSChallenge;
    procedure SetCertificateStoragePath(const Value: string);
    function GetCertificateStoragePath: string;
    procedure InternalLog(ASender: TObject; AMessage: string);
  protected
    // CSR generation
    function GenerateCsr(const ADomains: TArray<string>;
      const APrivateKeyFile: string; const ACsrFile: string;
      const AStoredSubject: TCsrSubject;
      const ACertPrivateKeyFile: string = ''): TBytes;

    // Challenge handling
    function HandleHttp01Challenge(const AAuthUrl: string;
      const ADomains: TArray<string>; const AHttpPort: Integer): boolean;
    function HandleDns01Challenge(const AAuthUrl: string;
      const ADomains: TArray<string>; const AUseFastPolling: boolean): boolean;
    // Account state management
    procedure SaveAccountState(const AProviderId: string; const AEmail: string;
      const AKid: string; const ADirectoryUrl: string;
      const APrivateKey: string);
    function LoadAccountState(const AProviderId: string; const AEmail: string;
      out AKid: string; out ADirectoryUrl: string;
      out APrivateKey: string): boolean;
    function AccountExists(const AProviderId: string;
      const AEmail: string): boolean;

    // Order state management
    procedure SaveOrderState(const AOrder: TAcmeOrderState;
      const AFileName: string);

    // Order operations
    function ResumeOrder(const AOrderUrl: string): TJSONObject;

    // Certificate management
    function CanSkipDnsValidation(const AOrderState: TAcmeOrderState): boolean;

  public
    constructor Create;
    destructor Destroy; override;

    // Main flow operations
    function NewOrder(const AProvider: TAcmeProvider; const AEmail: string;
      const ADomains: TArray<string>;
      const AChallengeOptions: TChallengeOptions;
      const ACsrSubject: TCsrSubject; out AOrderFile: string): boolean;
    function ResumeExistingOrder(const AOrderFile: string = ''): boolean;
    function RenewExistingCertificate(const AOrderFile: string): boolean;
    procedure AutoRenew(out ASuccess: TArray<string>;
      out AFailed: TArray<string>; const ADays: Integer = 30);

    function FindCertificateFiles(AValidOnly: boolean = false): TArray<string>;

    function LoadOrderState(const AFileName: string): TAcmeOrderState;

    procedure DeleteOrder(const AFileName: string);

    // Certificate bundle management
    function IsCertificateBundled(const AFileName: string): boolean;
    procedure SplitCertificateBundle(const AFileName: string);
    function GetCertificateExpiryDate(const ACertificateFile: string)
      : TDateTime;
    function VerifyCertificateAndKey(const ACertFile, AKeyFile: string;
      out AErrorMessage: string): boolean;
    function DNSChallengeValidate(const ARecordName, ARecordValue: string;
      const ATimeout: Integer = 5000): boolean;
    function GetSystemDNSServers: TArray<string>;

    function IsOpenSSLLoaded: boolean;

    property Client: TAcmeClient read FClient;
    property Providers: TACMEProviders read FProviders;
    property StorageFolder: string read GetCertificateStoragePath
      write SetCertificateStoragePath;
    property OnHTTPChallengeContinue: TNotifyEvent read FOnHTTPChallengeContinue
      write FOnHTTPChallengeContinue;
    property OnDNSChallengeContinue: TOnDNSChallenge
      read FOnDNSChallengeContinue write FOnDNSChallengeContinue;
  end;

implementation

{ TACMEOrders }

constructor TACMEOrders.Create;
begin
  inherited Create;
  FClient := TAcmeClient.Create(InternalLog);
  FProviders := TACMEProviders.Create('', InternalLog);
  StorageFolder := GetDefaultStorageFolder;
  FProviders.OnLog := InternalLog;
end;

procedure TACMEOrders.DeleteOrder(const AFileName: string);
var
  LFullPath: string;
  LDomainPrefix: string;
  LStoragePath: string;
  LPrivateKeyFile: string;
  LCertificateFile: string;
  LCsrFile: string;
  LServerCertFile: string;
  LChainCertFile: string;
  LOrderState: TAcmeOrderState;
begin
  Log('=== Deleting Order ===');

  LStoragePath := GetCertificateStoragePath;
  LFullPath := TPath.Combine(LStoragePath, AFileName);

  if not TFile.Exists(LFullPath) then
  begin
    Log('Order file not found: ' + AFileName);
    Exit;
  end;

  try
    // Load order to get domain info for logging
    LOrderState := LoadOrderState(LFullPath);
    Log('Deleting order for domains: ' + string.Join(', ',
      LOrderState.Domains));

    // Extract domain prefix from filename (order_domain.json -> domain)
    LDomainPrefix := StringReplace(AFileName, 'order_', '', [rfIgnoreCase]);
    LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);

    // Build related filenames
    LPrivateKeyFile := TPath.Combine(LStoragePath,
      Format('private_%s.key', [LDomainPrefix]));
    LCertificateFile := TPath.Combine(LStoragePath, Format('certificate_%s.pem',
      [LDomainPrefix]));
    LCsrFile := TPath.Combine(LStoragePath,
      Format('csr_%s.pem', [LDomainPrefix]));
    LServerCertFile := TPath.Combine(LStoragePath,
      Format('server_%s.pem', [LDomainPrefix]));
    LChainCertFile := TPath.Combine(LStoragePath,
      Format('chain_%s.pem', [LDomainPrefix]));

    // Delete order file
    if TFile.Exists(LFullPath) then
    begin
      TFile.Delete(LFullPath);
      Log('Deleted order file: ' + AFileName);
    end;

    // Delete private key file
    if TFile.Exists(LPrivateKeyFile) then
    begin
      TFile.Delete(LPrivateKeyFile);
      Log('Deleted private key: ' + TPath.GetFileName(LPrivateKeyFile));
    end;

    // Delete certificate file
    if TFile.Exists(LCertificateFile) then
    begin
      TFile.Delete(LCertificateFile);
      Log('Deleted certificate: ' + TPath.GetFileName(LCertificateFile));
    end;

    // Delete CSR file
    if TFile.Exists(LCsrFile) then
    begin
      TFile.Delete(LCsrFile);
      Log('Deleted CSR: ' + TPath.GetFileName(LCsrFile));
    end;

    // Delete split certificate files
    if TFile.Exists(LServerCertFile) then
    begin
      TFile.Delete(LServerCertFile);
      Log('Deleted server certificate: ' + TPath.GetFileName(LServerCertFile));
    end;

    if TFile.Exists(LChainCertFile) then
    begin
      TFile.Delete(LChainCertFile);
      Log('Deleted chain certificate: ' + TPath.GetFileName(LChainCertFile));
    end;

    Log('Order deleted successfully');
  except
    on E: Exception do
    begin
      Log('ERROR: Failed to delete order: ' + E.Message);
      raise;
    end;
  end;
end;

destructor TACMEOrders.Destroy;
begin
  FClient.Free;
  FProviders.Free;
  inherited Destroy;
end;

function TACMEOrders.IsCertificateBundled(const AFileName: string): boolean;
var
  LCertContent: string;
  LPos: Integer;
  LCount: Integer;
begin
  Result := false;

  if not TFile.Exists(AFileName) then
    Exit;

  try
    LCertContent := TFile.ReadAllText(AFileName, TEncoding.ASCII);

    // Count occurrences of certificate markers
    LCount := 0;
    LPos := 1;
    while LPos > 0 do
    begin
      LPos := Pos('-----BEGIN CERTIFICATE-----', LCertContent, LPos);
      if LPos > 0 then
      begin
        Inc(LCount);
        Inc(LPos);
      end;
    end;

    // If more than one certificate, it's a bundle
    Result := LCount > 1;
  except
    Result := false;
  end;
end;

function TACMEOrders.IsOpenSSLLoaded: boolean;
begin
  Result := false;
  if ASsigned(FClient) then
  begin
    Result := FClient.IsOpenSSLLoaded;
  end;
end;

function TACMEOrders.GetCertificateExpiryDate(const ACertificateFile: string)
  : TDateTime;
begin
  Result := 0;

  if not TFile.Exists(ACertificateFile) then
  begin
    Log('ERROR: Certificate file not found: ' + ACertificateFile);
    Exit;
  end;

  try
    // Use OpenSSL to parse the actual certificate expiry date
    Result := OpenSSL3.Helper.TOpenSSLHelper.GetCertificateExpiryDate
      (ACertificateFile);

  except
    on E: Exception do
    begin
      Log('ERROR: Failed to get certificate expiry date: ' + E.Message);
    end;
  end;
end;

procedure TACMEOrders.SplitCertificateBundle(const AFileName: string);
var
  LCertContent: string;
  LServerCert: string;
  LChainCerts: string;
  LPos: Integer;
  LStoragePath: string;
  LDomainPrefix: string;
  LServerCertFile: string;
  LChainCertFile: string;
  LOrderFileName: string;
begin
  if not TFile.Exists(AFileName) then
  begin
    Log('ERROR: Certificate file not found: ' + AFileName);
    Exit;
  end;

  Log('=== Splitting Certificate Bundle ===');
  Log('Certificate file: ' + AFileName);

  try
    // Read certificate content
    LCertContent := TFile.ReadAllText(AFileName, TEncoding.ASCII);

    // Find the end of the first certificate
    LPos := Pos('-----END CERTIFICATE-----', LCertContent);
    if LPos <= 0 then
    begin
      Log('No valid certificate found in file');
      Exit;
    end;

    // Extract server certificate (first certificate in chain)
    LServerCert := Copy(LCertContent, 1,
      LPos + Length('-----END CERTIFICATE-----') - 1);

    // Extract chain certificates (remaining certificates)
    LChainCerts :=
      Trim(Copy(LCertContent,
      LPos + Length('-----END CERTIFICATE-----'), MaxInt));

    if LChainCerts = '' then
    begin
      Log('Single certificate (no chain) - nothing to split');
      Exit;
    end;

    // Determine output filenames based on input filename
    LStoragePath := ExtractFilePath(AFileName);
    if LStoragePath = '' then
      LStoragePath := GetCertificateStoragePath;

    // Extract domain prefix from filename (certificate_domain.pem -> domain)
    LOrderFileName := ExtractFileName(AFileName);
    LDomainPrefix := StringReplace(LOrderFileName, 'certificate_', '',
      [rfIgnoreCase]);
    LDomainPrefix := StringReplace(LDomainPrefix, '.pem', '', [rfIgnoreCase]);

    LServerCertFile := TPath.Combine(LStoragePath,
      Format('server_%s.pem', [LDomainPrefix]));
    LChainCertFile := TPath.Combine(LStoragePath,
      Format('chain_%s.pem', [LDomainPrefix]));

    // Write server certificate
    TFile.WriteAllText(LServerCertFile, LServerCert, TEncoding.ASCII);
    Log('Server certificate written to: ' + LServerCertFile);

    // Write chain certificates
    TFile.WriteAllText(LChainCertFile, LChainCerts, TEncoding.ASCII);
    Log('Certificate chain written to: ' + LChainCertFile);

    Log('Certificate bundle split successfully');
  except
    on E: Exception do
    begin
      Log('ERROR: Failed to split certificate bundle: ' + E.Message);
      raise;
    end;
  end;
end;

procedure TACMEOrders.SaveAccountState(const AProviderId: string;
  const AEmail: string; const AKid: string; const ADirectoryUrl: string;
  const APrivateKey: string);
var
  LAccountsFile: string;
  LJson: TJSONObject;
  LAccountsArray: TJSONArray;
  LAccountObj: TJSONObject;
  I: Integer;
  LFound: boolean;
  LJsonStr: string;
  LExistingAccount: TJSONObject;
begin
  LAccountsFile := TPath.Combine(GetCertificateStoragePath, 'accounts.json');

  // Load existing accounts
  LJson := TJSONObject.Create;
  try
    if TFile.Exists(LAccountsFile) then
    begin
      LJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(LAccountsFile,
        TEncoding.UTF8)) as TJSONObject;
    end;

    if not ASsigned(LJson) then
      LJson := TJSONObject.Create;

    // Use FindValue to avoid exception when 'accounts' doesn't exist
    LAccountsArray := LJson.FindValue('accounts') as TJSONArray;
    if not ASsigned(LAccountsArray) then
    begin
      LAccountsArray := TJSONArray.Create;
      LJson.AddPair('accounts', LAccountsArray);
    end;

    // Check if account already exists and update it, or add new one
    LFound := false;
    for I := 0 to LAccountsArray.Count - 1 do
    begin
      LExistingAccount := LAccountsArray.Items[I] as TJSONObject;
      if (LExistingAccount.GetValue<string>('providerId') = AProviderId) and
        (LExistingAccount.GetValue<string>('email') = AEmail) then
      begin
        // Update existing account
        LExistingAccount.RemovePair('kid');
        LExistingAccount.AddPair('kid', AKid);
        LExistingAccount.RemovePair('directoryUrl');
        LExistingAccount.AddPair('directoryUrl', ADirectoryUrl);
        LExistingAccount.RemovePair('privateKey');
        LExistingAccount.AddPair('privateKey', APrivateKey);
        LFound := True;
        Break;
      end;
    end;

    if not LFound then
    begin
      // Add new account
      LAccountObj := TJSONObject.Create;
      LAccountObj.AddPair('providerId', AProviderId);
      LAccountObj.AddPair('email', AEmail);
      LAccountObj.AddPair('kid', AKid);
      LAccountObj.AddPair('directoryUrl', ADirectoryUrl);
      LAccountObj.AddPair('created', DateTimeToStr(Now));
      LAccountObj.AddPair('privateKey', APrivateKey);
      LAccountsArray.AddElement(LAccountObj);
    end;

    // Save back to file
    LJsonStr := LJson.ToJSON;
    TFile.WriteAllText(LAccountsFile, LJsonStr, TEncoding.UTF8);
  finally
    LJson.Free;
  end;
end;

function TACMEOrders.LoadAccountState(const AProviderId: string;
  const AEmail: string; out AKid: string; out ADirectoryUrl: string;
  out APrivateKey: string): boolean;
var
  LAccountsFile: string;
  LJson: TJSONObject;
  LAccountsArray: TJSONArray;
  I: Integer;
  LAccountObj: TJSONObject;
begin
  Result := false;
  LAccountsFile := TPath.Combine(GetCertificateStoragePath, 'accounts.json');

  if not TFile.Exists(LAccountsFile) then
    Exit;

  try
    LJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(LAccountsFile,
      TEncoding.UTF8)) as TJSONObject;
    try
      // Use FindValue to avoid exception when 'accounts' doesn't exist
      LAccountsArray := LJson.FindValue('accounts') as TJSONArray;
      if ASsigned(LAccountsArray) then
      begin
        for I := 0 to LAccountsArray.Count - 1 do
        begin
          LAccountObj := LAccountsArray.Items[I] as TJSONObject;
          if (LAccountObj.GetValue<string>('providerId') = AProviderId) and
            (LAccountObj.GetValue<string>('email') = AEmail) then
          begin
            AKid := LAccountObj.GetValue<string>('kid');
            ADirectoryUrl := LAccountObj.GetValue<string>('directoryUrl');
            APrivateKey := LAccountObj.GetValue<string>('privateKey');
            Result := True;
            Exit;
          end;
        end;
      end;
    finally
      LJson.Free;
    end;
  except
    Result := false;
  end;
end;

function TACMEOrders.AccountExists(const AProviderId: string;
  const AEmail: string): boolean;
var
  LKid, LDirectoryUrl, LPrivateKey: string;
begin
  Result := LoadAccountState(AProviderId, AEmail, LKid, LDirectoryUrl,
    LPrivateKey);
end;

procedure TACMEOrders.SaveOrderState(const AOrder: TAcmeOrderState;
  const AFileName: string);
var
  LJson: TJSONObject;
  LStream: TFileStream;
  LDomainsArray: TJSONArray;
  LAuthUrlsArray: TJSONArray;
  LI: Integer;
  LJsonStr: string;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('orderUrl', AOrder.OrderUrl);
    LJson.AddPair('finalizeUrl', AOrder.FinalizeUrl);
    LJson.AddPair('status', AOrder.Status);
    LJson.AddPair('expires', AOrder.Expires);
    LJson.AddPair('challengeType', IntToStr(Ord(AOrder.ChallengeType)));
    LJson.AddPair('certificateUrl', AOrder.CertificateUrl);
    LJson.AddPair('created', DateTimeToStr(AOrder.Created));
    LJson.AddPair('httpPort', IntToStr(AOrder.HttpPort));
    LJson.AddPair('providerId', AOrder.ProviderId);
    LJson.AddPair('providerDirectoryUrl', AOrder.ProviderDirectoryUrl);

    // Add CSR subject details
    LJson.AddPair('csrCountry', AOrder.CsrCountry);
    LJson.AddPair('csrState', AOrder.CsrState);
    LJson.AddPair('csrLocality', AOrder.CsrLocality);
    LJson.AddPair('csrOrganization', AOrder.CsrOrganization);
    LJson.AddPair('csrOrganizationalUnit', AOrder.CsrOrganizationalUnit);
    LJson.AddPair('csrEmailAddress', AOrder.CsrEmailAddress);
    LJson.AddPair('csrCommonName', AOrder.CsrCommonName);

    // Add domains array
    LDomainsArray := TJSONArray.Create;
    for LI := 0 to High(AOrder.Domains) do
      LDomainsArray.AddElement(TJSONString.Create(AOrder.Domains[LI]));
    LJson.AddPair('domains', LDomainsArray);

    // Add auth URLs array
    LAuthUrlsArray := TJSONArray.Create;
    for LI := 0 to High(AOrder.AuthUrls) do
      LAuthUrlsArray.AddElement(TJSONString.Create(AOrder.AuthUrls[LI]));
    LJson.AddPair('authUrls', LAuthUrlsArray);

    LStream := TFileStream.Create(AFileName, fmCreate);
    try
      LJsonStr := LJson.ToJSON;
      LStream.WriteBuffer(PAnsiChar(AnsiString(LJsonStr))^, Length(LJsonStr));
    finally
      LStream.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TACMEOrders.SetCertificateStoragePath(const Value: string);
begin
  FStorageFolder := Value;
  FStorageFolder := IncludeTrailingPathDelimiter(FStorageFolder);
  if ASsigned(FProviders) then
  begin
    FProviders.StoragePath := FStorageFolder;
  end;
end;

function TACMEOrders.LoadOrderState(const AFileName: string): TAcmeOrderState;
var
  LJson: TJSONObject;
  LStream: TFileStream;
  LJsonStr: string;
  LBuffer: TBytes;
  LDomainsArray: TJSONArray;
  LAuthUrlsArray: TJSONArray;
  LI: Integer;
begin
  if not TFile.Exists(AFileName) then
    raise EAcmeError.Create('Order state file not found: ' + AFileName);

  LStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    SetLength(LBuffer, LStream.Size);
    LStream.ReadBuffer(LBuffer[0], LStream.Size);
    LJsonStr := TEncoding.UTF8.GetString(LBuffer);
  finally
    LStream.Free;
  end;

  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;

  if not ASsigned(LJson) then
    raise EAcmeError.CreateFmt('Failed to parse order file: %s', [AFileName]);

  try
    Result.OrderUrl := LJson.GetValue<string>('orderUrl');
    Result.FinalizeUrl := LJson.GetValue<string>('finalizeUrl');
    Result.Status := LJson.GetValue<string>('status');
    Result.Expires := LJson.GetValue<string>('expires');
    Result.ChallengeType :=
      TChallengeType(StrToIntDef(LJson.GetValue<string>('challengeType'), 0));
    Result.CertificateUrl := LJson.GetValue<string>('certificateUrl');
    Result.Created := StrToDateTime(LJson.GetValue<string>('created'));

    // HttpPort - default to 80 if not found (for backward compatibility)
    if LJson.TryGetValue<string>('httpPort', LJsonStr) then
      Result.HttpPort := StrToIntDef(LJsonStr, ACME_DEFAULT_HTTP_PORT)
    else
      Result.HttpPort := ACME_DEFAULT_HTTP_PORT;

    Result.ProviderId := LJson.GetValue<string>('providerId');
    Result.ProviderDirectoryUrl := LJson.GetValue<string>
      ('providerDirectoryUrl');

    // Load CSR subject details (with defaults for backward compatibility)
    Result.CsrCountry := LJson.GetValue<string>('csrCountry');
    Result.CsrState := LJson.GetValue<string>('csrState');
    Result.CsrLocality := LJson.GetValue<string>('csrLocality');
    Result.CsrOrganization := LJson.GetValue<string>('csrOrganization');
    Result.CsrOrganizationalUnit := LJson.GetValue<string>
      ('csrOrganizationalUnit');
    Result.CsrEmailAddress := LJson.GetValue<string>('csrEmailAddress');
    Result.CsrCommonName := LJson.GetValue<string>('csrCommonName');

    // Load domains array
    LDomainsArray := LJson.GetValue<TJSONArray>('domains');
    SetLength(Result.Domains, LDomainsArray.Count);
    for LI := 0 to LDomainsArray.Count - 1 do
      Result.Domains[LI] := LDomainsArray.Items[LI].Value;

    // Load auth URLs array
    LAuthUrlsArray := LJson.GetValue<TJSONArray>('authUrls');
    SetLength(Result.AuthUrls, LAuthUrlsArray.Count);
    for LI := 0 to LAuthUrlsArray.Count - 1 do
      Result.AuthUrls[LI] := LAuthUrlsArray.Items[LI].Value;
  finally
    LJson.Free;
  end;
end;

function TACMEOrders.ResumeOrder(const AOrderUrl: string): TJSONObject;
var
  LText: string;
begin
  // Query the order status from the ACME server
  LText := FClient.PostAsJws(AOrderUrl, nil, True);
  Result := TJSONObject.ParseJSONValue(LText) as TJSONObject;
end;


function TACMEOrders.VerifyCertificateAndKey(const ACertFile, AKeyFile: string;
  out AErrorMessage: string): boolean;
begin
  Result := TOpenSSLHelper.VerifyCertificateAndKey(ACertFile, AKeyFile,
    AErrorMessage);
end;

function TACMEOrders.GetSystemDNSServers: TArray<string>;
var
  LFixedInfo: PFixedInfo;
  LBufferSize: ULONG;
  LDNS: PIP_ADDR_STRING;
  LDNSList: TList<string>;
  LDNSAddr: string;
begin
  SetLength(Result, 0);
  LDNSList := TList<string>.Create;
  try
    LBufferSize := SizeOf(TFixedInfo);
    GetMem(LFixedInfo, LBufferSize);
    try
      if GetNetworkParams(LFixedInfo, LBufferSize) = ERROR_BUFFER_OVERFLOW then
      begin
        ReallocMem(LFixedInfo, LBufferSize);
      end;

      if GetNetworkParams(LFixedInfo, LBufferSize) = NO_ERROR then
      begin
        LDNS := @LFixedInfo^.DnsServerList;
        while LDNS <> nil do
        begin
          LDNSAddr := string(AnsiString(LDNS^.IpAddress.S));
          if LDNSAddr <> '' then
          begin
            LDNSList.Add(LDNSAddr);
            Log('Found DNS server: ' + LDNSAddr);
          end;
          LDNS := LDNS^.Next;
        end;
      end
      else
      begin
        Log('ERROR: Failed to get network parameters');
      end;
    finally
      FreeMem(LFixedInfo);
    end;

    Result := LDNSList.ToArray;
  finally
    LDNSList.Free;
  end;
end;

function TACMEOrders.DNSChallengeValidate(const ARecordName,
  ARecordValue: string; const ATimeout: Integer = 5000): boolean;
var
  LDNS: TIdDNSResolver;
  LI: Integer;
  LRecord: TResultRecord;
  LTxt: TTextRecord;
  LDNSServers: TArray<string>;
  LDNSServer: string;
begin
  Result := false;

  Log('=== DNS Challenge Validation ===');
  Log('Record Name: ' + ARecordName);
  Log('Expected Value: ' + ARecordValue);

  // Get system DNS servers
  LDNSServers := GetSystemDNSServers;

  if Length(LDNSServers) = 0 then
  begin
    Log('WARNING: No DNS servers found, using default (8.8.8.8)');
    SetLength(LDNSServers, 1);
    LDNSServers[0] := '8.8.8.8'; // Google DNS as fallback
  end;

  // Try each DNS server
  for LDNSServer in LDNSServers do
  begin
    Log('Querying DNS server: ' + LDNSServer);

    LDNS := TIdDNSResolver.Create(nil);
    try
      LDNS.WaitingTime := ATimeout;
      LDNS.QueryType := [qtTXT];
      LDNS.Host := LDNSServer;

      try
        LDNS.Resolve(ARecordName);

        Log('DNS query returned ' + IntToStr(LDNS.QueryResult.Count) +
          ' record(s)');

        for LI := 0 to LDNS.QueryResult.Count - 1 do
        begin
          LRecord := LDNS.QueryResult[LI];
          if LRecord.RecType = qtTXT then
          begin
            LTxt := TTextRecord(LRecord);
            Log('Found TXT record: ' + LTxt.Text[0]);

            // Check if this matches the expected value
            if LTxt.Text[0] = ARecordValue then
            begin
              Log('SUCCESS: DNS TXT record matches expected value!');
              Result := True;
              Exit;
            end
            else
            begin
              Log('TXT record found but value does not match');
              Log('  Expected: ' + ARecordValue);
              Log('  Found:    ' + LTxt.Text[0]);
            end;
          end;
        end;

        if not Result then
        begin
          Log('TXT record not found or value mismatch on DNS server: ' +
            LDNSServer);
        end;

      except
        on E: Exception do
        begin
          Log('ERROR querying DNS server ' + LDNSServer + ': ' + E.Message);
        end;
      end;

    finally
      LDNS.Free;
    end;

    // If we found the correct record, no need to check other DNS servers
    if Result then
      Break;
  end;

  if not Result then
  begin
    Log('DNS validation failed: TXT record not found or incorrect value');
    Log('Make sure the DNS record has been created and propagated');
    Log('You can manually verify with: nslookup -type=TXT ' + ARecordName);
  end;
end;

function TACMEOrders.GetCertificateStoragePath: string;
begin
  Result := FStorageFolder;
  // Ensure the directory exists
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

function TACMEOrders.FindCertificateFiles(AValidOnly: boolean = false)
  : TArray<string>;
var
  LFiles: TArray<string>;
  LFile: string;
  LCount: Integer;
  LStoragePath: string;
  LOrderState: TAcmeOrderState;
  LAddFile: boolean;
begin
  SetLength(Result, 0);
  LStoragePath := GetCertificateStoragePath;
  LFiles := TDirectory.GetFiles(LStoragePath, 'order_*.json');
  LCount := 0;
  for LFile in LFiles do
  begin
    LAddFile := True;
    if AValidOnly then
    begin
      LOrderState := LoadOrderState(TPath.Combine(LStoragePath, LFile));
      LAddFile := SameText(LOrderState.Status, 'valid');
    end;
    if LAddFile then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := TPath.GetFileName(LFile); // Store just the filename
      Inc(LCount);
    end;
  end;
end;

function TACMEOrders.CanSkipDnsValidation(const AOrderState
  : TAcmeOrderState): boolean;
begin
  // Skip DNS validation if:
  // 1. The certificate was issued recently (within 30 days)
  // 2. The domains haven't changed
  // 3. The same challenge type is being used
  Result := (Now - AOrderState.Created) < 30.0; // Within 30 days
end;

function TACMEOrders.GenerateCsr(const ADomains: TArray<string>;
  const APrivateKeyFile: string; const ACsrFile: string;
  const AStoredSubject: TCsrSubject;
  const ACertPrivateKeyFile: string = ''): TBytes;
var
  LCsrGen: TCsrGenerator;
  LCsrDer: TBytes;
  LCsrPem: string;
begin
  Log('=== Certificate Signing Request Generation ===');
  Log('Using certificate subject details:');
  Log('  Country: ' + AStoredSubject.Country);
  Log('  State: ' + AStoredSubject.State);
  Log('  Locality: ' + AStoredSubject.Locality);
  Log('  Organization: ' + AStoredSubject.Organization);
  Log('  Email: ' + AStoredSubject.EmailAddress);
  Log('  Common Name: ' + AStoredSubject.CommonName);

  LCsrGen := TCsrGenerator.Create;
  try
    // Use existing private key if provided, otherwise generate new one
    if APrivateKeyFile <> '' then
    begin
      Log('Using existing private key from: ' + APrivateKeyFile);
      LCsrGen.LoadPrivateKeyFromPem(APrivateKeyFile);
    end
    else
    begin
      Log('Generating 2048-bit RSA key pair...');
      LCsrGen.GenerateRsaKeyPair2048;
    end;

    LCsrGen.Subject := AStoredSubject;
    LCsrGen.SanNames := ADomains;

    // Generate CSR
    Log('Generating CSR...');
    try
      LCsrDer := LCsrGen.GenerateCsrDer;
      LCsrPem := LCsrGen.GenerateCsrPem;
    except
      on E: EOpenSSL3CSRError do
      begin
        Log('CSR generation failed: ' + E.Message);
        raise;
      end;
    end;

    // Save private key if we generated a new one
    if APrivateKeyFile = '' then
    begin
      if ACertPrivateKeyFile <> '' then
      begin
        Log('Saving certificate private key to ' + ACertPrivateKeyFile + '...');
        LCsrGen.SavePrivateKeyToPem(ACertPrivateKeyFile);
      end
      else
      begin
        Log('Saving private key to private.key...');
        LCsrGen.SavePrivateKeyToPem('private.key');
      end;
    end;

    // Save CSR in PEM format for reference
    if ACsrFile <> '' then
    begin
      Log('Saving CSR (PEM format) to ' + ACsrFile + '...');
      TFile.WriteAllText(ACsrFile, LCsrPem, TEncoding.ASCII);
    end;

    Log('CSR generated successfully!');
    Result := LCsrDer;
  finally
    LCsrGen.Free;
  end;
end;

function TACMEOrders.HandleHttp01Challenge(const AAuthUrl: string;
  const ADomains: TArray<string>; const AHttpPort: Integer): boolean;
var
  LRetryCount: Integer;
  LMaxRetries: Integer;
  LDomain: string;
begin
  Result := false;
  LMaxRetries := 5;

  Log('=== HTTP-01 Challenge Setup ===');
  Log('Starting HTTP server on port ' + IntToStr(AHttpPort));
  Log('Make sure your domain(s) point to this machine:');
  for LDomain in ADomains do
    Log('  ' + LDomain + ' -> YOUR_IP_ADDRESS');

  // Trigger the OnHTTPChallengeContinue event if assigned
  if ASsigned(FOnHTTPChallengeContinue) then
    FOnHTTPChallengeContinue(Self);

  FClient.StartHttpServer(AHttpPort);
  try
    LRetryCount := 0;
    repeat
      Inc(LRetryCount);
      Log(Format('Attempt %d of %d...', [LRetryCount, LMaxRetries]));

      if FClient.TriggerHttp01AndValidate(AAuthUrl) then
      begin
        Log('HTTP-01 challenge validated successfully!');
        Result := True;
        Exit;
      end;

      if LRetryCount < LMaxRetries then
      begin
        Log('Challenge validation failed. Retrying...');
        Sleep(2000); // Wait 2 seconds before retry
      end;
    until LRetryCount >= LMaxRetries;

    if not Result then
      Log('HTTP-01 challenge failed after ' + IntToStr(LMaxRetries) +
        ' attempts');

  finally
    FClient.StopHttpServer;
  end;
end;

procedure TACMEOrders.InternalLog(ASender: TObject; AMessage: string);
begin
  Log(AMessage);
end;

function TACMEOrders.HandleDns01Challenge(const AAuthUrl: string;
  const ADomains: TArray<string>; const AUseFastPolling: boolean): boolean;
var
  LRetryCount: Integer;
  LMaxRetries: Integer;
  LToken, LKeyAuth, LRecordName, LRecordValue: string;
  LPayload: TJSONObject;
  LStart, LNow: Cardinal;
  LStatus: string;
  LAuth: TJSONObject;
  LChallenges: TJSONArray;
  LChObj: TJSONObject;
  LType: string;
  LI: Integer;
  LUrl: string;
  LSuccess: boolean;
  LChallengeTriggered: boolean;
  LPollInterval: Integer;
begin
  Result := false;
  LMaxRetries := 10;
  LChallengeTriggered := false;

  // Use faster polling for recent certificates
  if AUseFastPolling then
    LPollInterval := 5000 // 5 seconds for recent certificates
  else
    LPollInterval := 10000; // 10 seconds for normal certificates

  Log('=== DNS-01 Challenge Setup ===');
  Log('You will need to create TXT records in your DNS.');
  Log('The system will provide you with the exact record details.');
  if AUseFastPolling then
    Log('Using optimized polling for recent certificate (5-second intervals)...');

  // Get challenge details once
  if not FClient.GetDns01ChallengeDetails(AAuthUrl, LToken, LKeyAuth,
    LRecordName, LRecordValue) then
  begin
    Log('Failed to get DNS-01 challenge details');
    Exit;
  end;

  // Find the challenge URL
  LAuth := FClient.GetAuthorization(AAuthUrl);
  try
    LChallenges := LAuth.GetValue<TJSONArray>('challenges');
    LChObj := nil;
    for LI := 0 to LChallenges.Count - 1 do
    begin
      LType := (LChallenges.Items[LI] as TJSONObject).GetValue<string>('type');
      if SameText(LType, 'dns-01') then
      begin
        LChObj := (LChallenges.Items[LI] as TJSONObject);
        Break;
      end;
    end;

    if not ASsigned(LChObj) then
    begin
      Log('DNS-01 challenge not available');
      Exit;
    end;

    LUrl := LChObj.GetValue<string>('url');
  finally
    LAuth.Free;
  end;

  LRetryCount := 0;
  repeat
    Inc(LRetryCount);
    Log(Format('Attempt %d of %d...', [LRetryCount, LMaxRetries]));

    // Show challenge details
    Log('DNS-01 Challenge Details:');
    Log('Record Name: ' + LRecordName);
    Log('Record Type: TXT');
    Log('Record Value: ' + LRecordValue);
    Log('DNS Troubleshooting Tips:');
    Log('1. Ensure the TXT record is created exactly as shown above');
    Log('2. Wait for DNS propagation (can take up to 24 hours)');
    Log('3. Verify with: nslookup -type=TXT ' + LRecordName);
    Log('4. Check for typos in the record name or value');

    if not LChallengeTriggered then
    begin
      if AUseFastPolling then
      begin
        // For renewals (recent certificates), assume DNS records already exist
        Log('Renewal detected - assuming DNS records already exist from previous certificate.');
        Log('Triggering DNS-01 challenge immediately...');
      end
      else
      begin
        // Trigger the OnDNSChallengeContinue event if assigned
        if ASsigned(FOnDNSChallengeContinue) then
          FOnDNSChallengeContinue(Self, LRecordName, LRecordValue);
      end;

      // Trigger the challenge only once
      Log('Triggering DNS-01 challenge...');
      LPayload := TJSONObject.Create;
      try
        FClient.PostAsJws(LUrl, LPayload, True);
        LChallengeTriggered := True;
        Log('Challenge triggered successfully!');
      finally
        LPayload.Free;
      end;
    end
    else
    begin
      Log('Challenge already triggered. Checking validation status...');
    end;

    // Poll for validation with optimized intervals
    LStart := GetTickCount;
    LSuccess := false;
    repeat
      Sleep(LPollInterval);
      LAuth := FClient.GetAuthorization(AAuthUrl);
      try
        LStatus := LAuth.GetValue<string>('status');
        if SameText(LStatus, 'valid') then
        begin
          Log('DNS-01 challenge validated successfully!');
          LSuccess := True;
          Result := True;
          Break;
        end;
        if SameText(LStatus, 'invalid') then
        begin
          Log('DNS-01 challenge validation failed');
          Log('Challenge failed, but continuing to poll for DNS propagation...');
        end;
        Log('Challenge status: ' + LStatus + ' - waiting...' +
          IfThen(AUseFastPolling, ' (auto-polling)', ''));
        LNow := GetTickCount;
      finally
        LAuth.Free;
      end;
    until (LNow - LStart) >= 300000; // 5 minute timeout per attempt

    if LSuccess then
      Exit;

    if LRetryCount < LMaxRetries then
    begin
      Log('Challenge validation failed. Retrying polling...');
      Sleep(5000); // Wait 5 seconds before next retry
    end;
  until LRetryCount >= LMaxRetries;

  if not Result then
    Log('DNS-01 challenge failed after ' + IntToStr(LMaxRetries) + ' attempts');
end;

function TACMEOrders.NewOrder(const AProvider: TAcmeProvider;
  const AEmail: string; const ADomains: TArray<string>;
  const AChallengeOptions: TChallengeOptions; const ACsrSubject: TCsrSubject;
  out AOrderFile: string): boolean;
var
  LOrderJson: TJSONObject;
  LAuthUrl: string;
  LFinalizeUrl: string;
  LCsrDer: TBytes;
  LCertPem: string;
  LAuths: TJSONArray;
  LSuccess: boolean;
  LOrderState: TAcmeOrderState;
  LDomainPrefix: string;
  LOrderFile: string;
  LPrivateKeyFile: string;
  LCsrFile: string;
  LCertificateFile: string;
  LStoragePath: string;
  LIdx: Integer;
  LCertificateUrl: string;
  LCsrSubject: TCsrSubject;
  LExistingKid, LExistingDirectoryUrl, LExistingPrivateKey: string;
  LTempKeyFile: string;
  LPrivateKeyPem: string;
begin
  Result := false;

  // Copy const parameter to local variable so we can modify CommonName
  LCsrSubject := ACsrSubject;

  try
    Log('=== ACME v2 Certificate Management ===');
    Log('Domains: ' + string.Join(', ', ADomains));
    Log('=== Initializing ACME Client ===');
    FClient.Initialize(AProvider.DirectoryUrl);

    // Check if account already exists for this provider and email
    if AccountExists(AProvider.Id, AEmail) then
    begin
      Log('Existing account found for email: ' + AEmail);
      Log('Loading existing account...');

      // Load existing account
      if LoadAccountState(AProvider.Id, AEmail, LExistingKid,
        LExistingDirectoryUrl, LExistingPrivateKey) then
      begin
        FClient.AccountKid := LExistingKid;
        FClient.DirectoryUrl := LExistingDirectoryUrl;

        // Load private key from PEM string
        // Create a temporary file with the PEM data
        LTempKeyFile := TPath.GetTempFileName;
        try
          TFile.WriteAllText(LTempKeyFile, LExistingPrivateKey,
            TEncoding.ASCII);
          FClient.LoadPrivateKeyFromPem(LTempKeyFile);
        finally
          TFile.Delete(LTempKeyFile);
        end;
        Log('Account loaded successfully');

        // Validate the existing account
        Log('Validating existing account...');
        if not FClient.ValidateAccount then
        begin
          Log('WARNING: Existing account validation failed, creating new account...');
          FClient.GenerateRsaKeyPair2048;
          FClient.CreateOrLoadAccount(AEmail, True);
        end
        else
        begin
          Log('Existing account validation successful.');
        end;
      end
      else
      begin
        Log('ERROR: Failed to load existing account, creating new account...');
        FClient.GenerateRsaKeyPair2048;
        FClient.CreateOrLoadAccount(AEmail, True);
      end;
    end
    else
    begin
      Log('No existing account found for email: ' + AEmail);
      Log('Creating new account...');
      FClient.GenerateRsaKeyPair2048;
      FClient.CreateOrLoadAccount(AEmail, True);
    end;

    Log('ACME client initialized successfully');

    // Step 7: Create new order
    Log('=== Creating Certificate Order ===');
    LOrderJson := FClient.NewOrder(ADomains);
    try
      Log('Order created:');
      Debug(LOrderJson.ToJSON);

      LAuths := LOrderJson.GetValue<TJSONArray>('authorizations');
      if (LAuths = nil) or (LAuths.Count = 0) then
        raise Exception.Create('No authorizations in order');
      LAuthUrl := LAuths.Items[0].Value;
      LFinalizeUrl := LOrderJson.GetValue<string>('finalize');

      LStoragePath := GetCertificateStoragePath;
      LDomainPrefix := StringReplace(ADomains[0], '.', '_', [rfReplaceAll]);

      // Use simple domain-based names for certificate files
      LOrderFile := TPath.Combine(LStoragePath,
        Format('order_%s.json', [LDomainPrefix]));
      LPrivateKeyFile := TPath.Combine(LStoragePath,
        Format('private_%s.key', [LDomainPrefix]));
      LCsrFile := TPath.Combine(LStoragePath,
        Format('csr_%s.pem', [LDomainPrefix]));
      LCertificateFile := TPath.Combine(LStoragePath,
        Format('certificate_%s.pem', [LDomainPrefix]));

      // Set the out parameter with just the filename (not full path)
      AOrderFile := Format('order_%s.json', [LDomainPrefix]);

      // Save account private key and state only if we created a new account
      if not AccountExists(AProvider.Id, AEmail) then
      begin
        // Get private key as PEM string
        LTempKeyFile := TPath.GetTempFileName;
        try
          FClient.SavePrivateKeyToPem(LTempKeyFile);
          LPrivateKeyPem := TFile.ReadAllText(LTempKeyFile, TEncoding.ASCII);
        finally
          TFile.Delete(LTempKeyFile);
        end;

        // Save account state with private key
        SaveAccountState(AProvider.Id, AEmail, FClient.AccountKid,
          AProvider.DirectoryUrl, LPrivateKeyPem);
        Log('Account state saved successfully');
      end
      else
      begin
        Log('Using existing account for provider: ' + AProvider.Id + ', email: '
          + AEmail);
      end;

      // Save order state
      LOrderState.OrderUrl := FClient.GetResponseHeader('Location');
      LOrderState.FinalizeUrl := LFinalizeUrl;
      LOrderState.Status := LOrderJson.GetValue<string>('status');
      LOrderState.Expires := LOrderJson.GetValue<string>('expires');
      LOrderState.Domains := ADomains;
      LOrderState.ChallengeType := AChallengeOptions.ChallengeType;
      LOrderState.HttpPort := AChallengeOptions.HttpPort;
      SetLength(LOrderState.AuthUrls, LAuths.Count);
      for LIdx := 0 to LAuths.Count - 1 do
        LOrderState.AuthUrls[LIdx] := LAuths.Items[LIdx].Value;
      LOrderState.CertificateUrl := '';
      LOrderState.Created := Now;
      LOrderState.ProviderId := AProvider.Id;
      LOrderState.ProviderDirectoryUrl := AProvider.DirectoryUrl;

      SaveOrderState(LOrderState, LOrderFile);
      Log('Order state saved to: ' + LOrderFile);

      // Step 5: Generate CSR (now that we have the filenames)
      // Set CommonName to first domain if not provided
      if LCsrSubject.CommonName = '' then
        LCsrSubject.CommonName := ADomains[0];

      // For new certificates, we generate a new private key, so pass empty string for account private key
      LCsrDer := GenerateCsr(ADomains, '', LCsrFile, LCsrSubject,
        LPrivateKeyFile);

      // Save CSR subject details to order state
      LOrderState.CsrCountry := LCsrSubject.Country;
      LOrderState.CsrState := LCsrSubject.State;
      LOrderState.CsrLocality := LCsrSubject.Locality;
      LOrderState.CsrOrganization := LCsrSubject.Organization;
      LOrderState.CsrOrganizationalUnit := LCsrSubject.OrganizationalUnit;
      LOrderState.CsrEmailAddress := LCsrSubject.EmailAddress;
      LOrderState.CsrCommonName := LCsrSubject.CommonName;

      // Update order state with CSR details
      SaveOrderState(LOrderState, LOrderFile);

      // Step 8: Handle challenge
      Log('=== Processing Challenge ===');
      LSuccess := false;
      case AChallengeOptions.ChallengeType of
        ctHttp01:
          LSuccess := HandleHttp01Challenge(LAuthUrl, ADomains,
            AChallengeOptions.HttpPort);
        ctDns01:
          LSuccess := HandleDns01Challenge(LAuthUrl, ADomains, false);
      end;

      if not LSuccess then
      begin
        Log('Challenge validation failed. Cannot proceed with certificate issuance.');
        Exit;
      end;

      // Step 9: Finalize and download certificate
      Log('=== Finalizing Certificate Order ===');
      LCertPem := FClient.FinalizeAndDownloadWithCsr(LFinalizeUrl, LCsrDer,
        LCertificateUrl);

      if LCertPem = '' then
        raise Exception.Create('No certificate returned');

      // Step 10: Save certificate
      TFile.WriteAllText(LCertificateFile, LCertPem, TEncoding.ASCII);
      Log('Certificate saved to: ' + LCertificateFile);

      // Split certificate bundle for Indy compatibility
      if IsCertificateBundled(LCertificateFile) then
        SplitCertificateBundle(LCertificateFile);

      // Step 11: Update order state with certificate URL
      LOrderState.Status := 'valid';
      LOrderState.CertificateUrl := LCertificateUrl;
      SaveOrderState(LOrderState, LOrderFile);
      Log('Order state updated with certificate URL: ' + LCertificateUrl);
      Log('=== SUCCESS ===');
      Log('Certificate obtained and saved successfully!');
      Result := True;

    finally
      LOrderJson.Free;
    end;

  except
    on E: Exception do
    begin
      Log('ERROR: ' + E.ClassName + ': ' + E.Message);
      Result := false;
    end;
  end;
end;

function TACMEOrders.ResumeExistingOrder(const AOrderFile: string = '')
  : boolean;
var
  LOrderState: TAcmeOrderState;
  LOrderJson: TJSONObject;
  LStatus: string;
  LCsrDer: TBytes;
  LCertPem: string;
  LI: Integer;
  LSuccess: boolean;
  LOrderFileName: string;
  LAccountFileName: string;
  LPrivateKeyFileName: string;
  LCertificateFileName: string;
  LKid, LDirectoryUrl: string;
  LStoragePath: string;
  LAccountPrivateKeyFileName: string;
  LCertUrl: string;
  LAuthUrls: TJSONArray;
  LAuthUrl: string;
  LCertificateUrl: string;
  I: Integer;
  LPrivateKey: string;
  LTempKeyFile: string;
  LStoredSubject: TCsrSubject;
  LNewOrderJson: TJSONObject;
  LNewFinalizeUrl: string;
  LNewAuthUrls: TJSONArray;
begin
  Result := false;
  try
    Log('=== Resuming Existing Order ===');

    LStoragePath := GetCertificateStoragePath;

    if AOrderFile = '' then
    begin
      LOrderFileName := TPath.Combine(LStoragePath, 'order.json');
      LAccountFileName := TPath.Combine(LStoragePath, 'account.json');
      LAccountPrivateKeyFileName := TPath.Combine(LStoragePath,
        'account_private.key');
      LPrivateKeyFileName := TPath.Combine(LStoragePath, 'private.key');
      LCertificateFileName := TPath.Combine(LStoragePath, 'certificate.pem');
    end
    else
    begin
      LOrderFileName := TPath.Combine(LStoragePath, AOrderFile);

      // Load order state to get email for account filenames
      LOrderState := LoadOrderState(LOrderFileName);

      // Account loading is now handled by the new system below

      // Derive certificate-specific filenames from order filename
      LPrivateKeyFileName := TPath.Combine(LStoragePath,
        StringReplace(AOrderFile, 'order_', 'private_', []));
      LPrivateKeyFileName := StringReplace(LPrivateKeyFileName, '.json',
        '.key', []);
      LCertificateFileName := TPath.Combine(LStoragePath,
        StringReplace(AOrderFile, 'order_', 'certificate_', []));
      LCertificateFileName := StringReplace(LCertificateFileName, '.json',
        '.pem', []);
    end;

    // Load account state using new system
    if LoadAccountState(LOrderState.ProviderId, LOrderState.CsrEmailAddress,
      LKid, LDirectoryUrl, LPrivateKey) then
    begin
      FClient.AccountKid := LKid;
      FClient.DirectoryUrl := LDirectoryUrl;
      if LDirectoryUrl <> '' then
        FClient.Initialize(LDirectoryUrl);
      Log('Account loaded successfully');

      // Load account private key from PEM string
      LTempKeyFile := TPath.GetTempFileName;
      try
        TFile.WriteAllText(LTempKeyFile, LPrivateKey, TEncoding.ASCII);
        FClient.LoadPrivateKeyFromPem(LTempKeyFile);
      finally
        TFile.Delete(LTempKeyFile);
      end;
      Log('Account private key loaded successfully');

      // Validate the account
      Log('Validating account...');
      if not FClient.ValidateAccount then
      begin
        Log('WARNING: Account validation failed, but continuing with resume attempt...');
        Log('This might happen if:');
        Log('  - The account was reset on the staging server');
        Log('  - The private key was changed');
        Log('  - The ACME server configuration changed');
        Log('We will attempt to resume the order anyway.');
      end
      else
      begin
        Log('Account validation successful.');
      end;
    end
    else
    begin
      Log('ERROR: Account not found for provider: ' + LOrderState.ProviderId +
        ', email: ' + LOrderState.CsrEmailAddress);
      Exit;
    end;

    // Load private key
    if TFile.Exists(LPrivateKeyFileName) then
    begin
      // Don't load certificate private key into ACME client - it overwrites account key
      // The certificate private key will be loaded directly by CSR generation if needed
      Log('Certificate private key found at: ' + LPrivateKeyFileName);
    end
    else
    begin
      Log('ERROR: Private key file not found: ' + LPrivateKeyFileName);
      Log('Cannot resume order without the original private key.');
      Exit;
    end;

    // Load order state
    LOrderState := LoadOrderState(LOrderFileName);
    Log('Order loaded: ' + LOrderState.OrderUrl);
    Log('Status: ' + LOrderState.Status);
    Log('Domains: ' + string.Join(', ', LOrderState.Domains));

    // Query current order status
    LOrderJson := ResumeOrder(LOrderState.OrderUrl);
    try
      LStatus := LOrderJson.GetValue<string>('status');
      Log('Current order status: ' + LStatus);

      if SameText(LStatus, 'valid') then
      begin
        Log('Order is already valid! Downloading certificate...');
        LCertUrl := LOrderJson.GetValue<string>('certificate');
        if LCertUrl <> '' then
        begin
          LCertPem := FClient.DownloadCertificateChainPem(LCertUrl);
          TFile.WriteAllText(LCertificateFileName, LCertPem);
          Log('Certificate saved to: ' + LCertificateFileName);

          // Split certificate bundle for Indy compatibility
          if IsCertificateBundled(LCertificateFileName) then
            SplitCertificateBundle(LCertificateFileName);
        end;
      end
      else if SameText(LStatus, 'pending') then
      begin
        Log('Order is still pending. Continuing with challenges...');

        LAuthUrls := LOrderJson.GetValue<TJSONArray>('authorizations');
        LSuccess := True;

        for LI := 0 to LAuthUrls.Count - 1 do
        begin
          LAuthUrl := LAuthUrls.Items[LI].Value;
          Log('Processing authorization: ' + LAuthUrl);

          if LOrderState.ChallengeType = ctHttp01 then
          begin
            if not HandleHttp01Challenge(LAuthUrl, LOrderState.Domains,
              LOrderState.HttpPort) then
            begin
              LSuccess := false;
              Break;
            end;
          end
          else if LOrderState.ChallengeType = ctDns01 then
          begin
            if not HandleDns01Challenge(LAuthUrl, LOrderState.Domains, false)
            then
            begin
              LSuccess := false;
              Break;
            end;
          end;
        end;

        if LSuccess then
        begin
          Log('All challenges completed successfully!');
          // Generate CSR using stored subject details
          LStoredSubject.Country := LOrderState.CsrCountry;
          LStoredSubject.State := LOrderState.CsrState;
          LStoredSubject.Locality := LOrderState.CsrLocality;
          LStoredSubject.Organization := LOrderState.CsrOrganization;
          LStoredSubject.OrganizationalUnit :=
            LOrderState.CsrOrganizationalUnit;
          LStoredSubject.EmailAddress := LOrderState.CsrEmailAddress;
          LStoredSubject.CommonName := LOrderState.CsrCommonName;

          LCsrDer := GenerateCsr(LOrderState.Domains, LPrivateKeyFileName, '',
            LStoredSubject);
          LCertPem := FClient.FinalizeAndDownloadWithCsr
            (LOrderState.FinalizeUrl, LCsrDer, LCertificateUrl);
          TFile.WriteAllText(LCertificateFileName, LCertPem);
          Log('Certificate saved to: ' + LCertificateFileName);

          // Split certificate bundle for Indy compatibility
          if IsCertificateBundled(LCertificateFileName) then
            SplitCertificateBundle(LCertificateFileName);

          // Update order state with certificate URL
          LOrderState.Status := 'valid';
          LOrderState.CertificateUrl := LCertificateUrl;
          SaveOrderState(LOrderState, LOrderFileName);
          Log('Order state updated with certificate URL: ' + LCertificateUrl);
        end;
      end
      else
      begin
        Log('Order status is: ' + LStatus);
        if SameText(LStatus, 'invalid') then
        begin
          Log('This order is invalid (likely cancelled during DNS validation).');
          Log('Creating a new order for the same domain automatically...');
          Log('Creating new order for domain: ' + string.Join(', ',
            LOrderState.Domains));
          Log('Using existing account and private key...');

          // Create new order using existing account and domain
          LNewOrderJson := FClient.NewOrder(LOrderState.Domains);
          try
            LNewFinalizeUrl := LNewOrderJson.GetValue<string>('finalize');
            LNewAuthUrls := LNewOrderJson.GetValue<TJSONArray>
              ('authorizations');

            // Update order state with new order details
            LOrderState.OrderUrl := FClient.GetResponseHeader('Location');
            LOrderState.FinalizeUrl := LNewFinalizeUrl;
            LOrderState.Status := 'pending';
            LOrderState.ChallengeType := LOrderState.ChallengeType;
            // Keep existing challenge type
            // Clear and rebuild auth URLs array
            SetLength(LOrderState.AuthUrls, LNewAuthUrls.Count);
            for I := 0 to LNewAuthUrls.Count - 1 do
              LOrderState.AuthUrls[I] := LNewAuthUrls.Items[I].Value;

            Log('New order created: ' + LOrderState.OrderUrl);
            Log('Continuing with challenges...');

            // Continue with challenge handling using the new order
            LSuccess := True;
            for I := 0 to LNewAuthUrls.Count - 1 do
            begin
              LAuthUrl := LNewAuthUrls.Items[I].Value;
              Log('Processing authorization: ' + LAuthUrl);

              if LOrderState.ChallengeType = ctHttp01 then
              begin
                if not HandleHttp01Challenge(LAuthUrl, LOrderState.Domains,
                  LOrderState.HttpPort) then
                begin
                  LSuccess := false;
                  Break;
                end;
              end
              else
              begin
                if not HandleDns01Challenge(LAuthUrl, LOrderState.Domains, false)
                then
                begin
                  LSuccess := false;
                  Break;
                end;
              end;
            end;

            if LSuccess then
            begin
              Log('All challenges completed successfully!');
              // Generate CSR using stored subject details
              LStoredSubject.Country := LOrderState.CsrCountry;
              LStoredSubject.State := LOrderState.CsrState;
              LStoredSubject.Locality := LOrderState.CsrLocality;
              LStoredSubject.Organization := LOrderState.CsrOrganization;
              LStoredSubject.OrganizationalUnit :=
                LOrderState.CsrOrganizationalUnit;
              LStoredSubject.EmailAddress := LOrderState.CsrEmailAddress;
              LStoredSubject.CommonName := LOrderState.CsrCommonName;

              LCsrDer := GenerateCsr(LOrderState.Domains, LPrivateKeyFileName,
                '', LStoredSubject);

              LCertPem := FClient.FinalizeAndDownloadWithCsr
                (LOrderState.FinalizeUrl, LCsrDer, LCertificateUrl);
              TFile.WriteAllText(LCertificateFileName, LCertPem);
              Log('Certificate saved to: ' + LCertificateFileName);

              // Split certificate bundle for Indy compatibility
              if IsCertificateBundled(LCertificateFileName) then
                SplitCertificateBundle(LCertificateFileName);

              // Update order state
              LOrderState.Status := 'valid';
              LOrderState.CertificateUrl := LCertificateUrl;
              SaveOrderState(LOrderState, LOrderFileName);
              Log('Order state updated with certificate URL: ' +
                LCertificateUrl);
            end;
          finally
            LNewOrderJson.Free;
          end;
        end
        else
        begin
          Log('Cannot resume this order. Please create a new one.');
        end;
      end;
      Result := True;
    finally
      LOrderJson.Free;
    end;
  except
    on E: Exception do
    begin
      Log('ERROR: ' + E.ClassName + ': ' + E.Message);
      Result := false;
    end;
  end;
end;

function TACMEOrders.RenewExistingCertificate(const AOrderFile: string)
  : boolean;
var
  LDomains: TArray<string>;
  LChallengeType: TChallengeType;
  LCsrDer: TBytes;
  LCertPem: string;
  LPrivateKeyFile: string;
  LStoragePath: string;
  LOrderState: TAcmeOrderState;
  LOrderJson: TJSONObject;
  LFinalizeUrl: string;
  LAuthUrls: TJSONArray;
  LSuccess: boolean;
  LAuthIdx: Integer;
  LAuthUrl: string;
  LOldCertFile: string;
  LArchiveCertFile: string;
  LArchiveTimestamp: string;
  LStoredSubject: TCsrSubject;
  LSelectedOrderFile: string;
  LCurrentExpiryDate: TDateTime;
  LDaysRemaining: Integer;
  LUseFastPolling: Boolean;
  LNewExpiryDate: TDateTime;
  LKid, LDirectoryUrl, LPrivateKey: string;
  LTempKeyFile: string;
  LCertificateUrl: string;
begin
  Result := false;
  try
    Log('=== Renewing Existing Certificate ===');

    // Validate the provided order file
    if AOrderFile = '' then
    begin
      Log('ERROR: No order file specified.');
      Exit;
    end;

    LStoragePath := GetCertificateStoragePath;

    LSelectedOrderFile := TPath.Combine(LStoragePath, AOrderFile);

    if not TFile.Exists(LSelectedOrderFile) then
    begin
      Log('ERROR: Order file not found: ' + LSelectedOrderFile);
      Exit;
    end;

    // Load and validate order state
    try
      LOrderState := LoadOrderState(LSelectedOrderFile);
      if not SameText(LOrderState.Status, 'valid') then
      begin
        Log('ERROR: Certificate is not valid (status: ' + LOrderState.Status +
          '). Cannot renew.');
        Exit;
      end;
    except
      Log('ERROR: Failed to load order state from: ' + LSelectedOrderFile);
      Exit;
    end;

    Log('Selected: ' + AOrderFile);

    // Derive certificate-specific filenames from selected order file
    LPrivateKeyFile := TPath.Combine(LStoragePath,
      StringReplace(LSelectedOrderFile, 'order_', 'private_', []));
    LPrivateKeyFile := StringReplace(LPrivateKeyFile, '.json', '.key', []);

    // Log current certificate expiry date before renewal
    LOldCertFile := TPath.Combine(LStoragePath,
      StringReplace(LSelectedOrderFile, 'order_', 'certificate_', []));
    LOldCertFile := StringReplace(LOldCertFile, '.json', '.pem', []);

    if TFile.Exists(LOldCertFile) then
    begin
      LCurrentExpiryDate := GetCertificateExpiryDate(LOldCertFile);
      if LCurrentExpiryDate > 0 then
      begin
        LDaysRemaining := DaysBetween(Now, LCurrentExpiryDate);
        Log('Current certificate expiry: ' + DateTimeToStr(LCurrentExpiryDate) +
          ' (' + IntToStr(LDaysRemaining) + ' days remaining)');
        if LCurrentExpiryDate < Now then
          Log('WARNING: Certificate has already expired!');
      end;
    end;

    // Account loading is now handled by the new system below

    if not LoadAccountState(LOrderState.ProviderId, LOrderState.CsrEmailAddress,
      LKid, LDirectoryUrl, LPrivateKey) then
    begin
      Log('ERROR: Account not found for provider: ' + LOrderState.ProviderId +
        ', email: ' + LOrderState.CsrEmailAddress);
      Log('Cannot renew certificate without account information.');
      Exit;
    end;

    FClient.AccountKid := LKid;
    FClient.DirectoryUrl := LDirectoryUrl;
    if LDirectoryUrl <> '' then
      FClient.Initialize(LDirectoryUrl);
    Log('Account loaded successfully');

    // Load account private key from PEM string
    LTempKeyFile := TPath.GetTempFileName;
    try
      TFile.WriteAllText(LTempKeyFile, LPrivateKey, TEncoding.ASCII);
      FClient.LoadPrivateKeyFromPem(LTempKeyFile);
    finally
      TFile.Delete(LTempKeyFile);
    end;
    Log('Account private key loaded successfully');

    // Validate the account
    Log('Validating account...');
    if not FClient.ValidateAccount then
    begin
      Log('ERROR: Account is no longer valid on the ACME server.');
      Log('This can happen if:');
      Log('  - The account was deleted or expired');
      Log('  - The private key was changed');
      Log('  - The ACME server configuration changed');
      Log('Please create a new certificate instead.');
      Exit;
    end;
    Log('Account validation successful.');

    // Note: We don't load the certificate private key here because it would
    // overwrite the account private key needed for ACME authentication.
    // The certificate private key will be loaded by GenerateCsr when needed.
    if not TFile.Exists(LPrivateKeyFile) then
    begin
      Log('ERROR: Private key file not found: ' + LPrivateKeyFile);
      Log('Cannot renew certificate without the original private key.');
      Exit;
    end;

    // Use domains from existing certificate
    LDomains := LOrderState.Domains;
    Log('Renewing certificate for domains: ' + string.Join(', ', LDomains));

    // Use the same challenge type as the original certificate
    LChallengeType := TChallengeType(LOrderState.ChallengeType);
    Log('Using ' + IfThen(LChallengeType = ctHttp01, 'HTTP-01', 'DNS-01') +
      ' challenge');

    // For recent certificates, we can use faster polling
    if CanSkipDnsValidation(LOrderState) then
    begin
      Log('Certificate is recent (within 30 days), using optimized validation process...');
    end;

    // Create new order
    LOrderJson := FClient.NewOrder(LDomains);
    try
      LFinalizeUrl := LOrderJson.GetValue<string>('finalize');
      LAuthUrls := LOrderJson.GetValue<TJSONArray>('authorizations');

      // Handle challenges with optimized settings for recent certificates
      LSuccess := True;

      for LAuthIdx := 0 to LAuthUrls.Count - 1 do
      begin
        LAuthUrl := LAuthUrls.Items[LAuthIdx].Value;
        if LChallengeType = ctHttp01 then
        begin
          if not HandleHttp01Challenge(LAuthUrl, LDomains, LOrderState.HttpPort)
          then
          begin
            LSuccess := false;
            Break;
          end;
        end
        else
        begin
          // For recent certificates, use faster polling intervals
          LUseFastPolling := CanSkipDnsValidation(LOrderState);
          if not HandleDns01Challenge(LAuthUrl, LDomains, LUseFastPolling) then
          begin
            LSuccess := false;
            Break;
          end;
        end;
      end;

      if LSuccess then
      begin
        Log('All challenges completed successfully!');

        // Use stored CSR subject details for seamless renewal

        LStoredSubject.Country := LOrderState.CsrCountry;
        LStoredSubject.State := LOrderState.CsrState;
        LStoredSubject.Locality := LOrderState.CsrLocality;
        LStoredSubject.Organization := LOrderState.CsrOrganization;
        LStoredSubject.OrganizationalUnit := LOrderState.CsrOrganizationalUnit;
        LStoredSubject.EmailAddress := LOrderState.CsrEmailAddress;
        LStoredSubject.CommonName := LOrderState.CsrCommonName;

        LCsrDer := GenerateCsr(LDomains, LPrivateKeyFile, '', LStoredSubject);

        LCertPem := FClient.FinalizeAndDownloadWithCsr(LFinalizeUrl, LCsrDer,
          LCertificateUrl);

        // Archive the old certificate and replace with new one
        if TFile.Exists(LOldCertFile) then
        begin
          // Create archive filename with timestamp
          LArchiveTimestamp := FormatDateTime('yyyymmdd-hhnnss', Now);
          LArchiveCertFile := StringReplace(LOldCertFile, '.pem',
            Format('-archive-%s.pem', [LArchiveTimestamp]), []);

          // Rename old certificate to archive
          TFile.Move(LOldCertFile, LArchiveCertFile);
          Log('Old certificate archived to: ' + LArchiveCertFile);
        end;

        // Save new certificate with the same name as the old one
        TFile.WriteAllText(LOldCertFile, LCertPem);
        Log('New certificate saved to: ' + LOldCertFile);

        // Log new certificate expiry date
        LNewExpiryDate := GetCertificateExpiryDate(LOldCertFile);
        if LNewExpiryDate > 0 then
        begin
          Log('New certificate expires: ' + DateTimeToStr(LNewExpiryDate) + ' ('
            + IntToStr(DaysBetween(Now, LNewExpiryDate)) + ' days from now)');
        end;

        // Split certificate bundle for Indy compatibility
        if IsCertificateBundled(LOldCertFile) then
          SplitCertificateBundle(LOldCertFile);

        // Update order state with new certificate URL
        LOrderState.Status := 'valid';
        LOrderState.CertificateUrl := LCertificateUrl;
        SaveOrderState(LOrderState, TPath.Combine(LStoragePath,
          LSelectedOrderFile));
        Log('Order state updated with certificate URL: ' + LCertificateUrl);
        Log('=== RENEWAL SUCCESS ===');
        Log('Certificate renewed successfully!');
        Log('Old certificate archived with timestamp: ' + LArchiveTimestamp);
        Result := True;
      end;
    finally
      LOrderJson.Free;
    end;
  except
    on E: Exception do
    begin
      Log('ERROR: ' + E.ClassName + ': ' + E.Message);
      Result := false;
    end;
  end;
end;

procedure TACMEOrders.AutoRenew(out ASuccess: TArray<string>;
  out AFailed: TArray<string>; const ADays: Integer = 30);
var
  LCertFiles: TArray<string>;
  LOrderFile: string;
  LSuccessList: TList<string>;
  LFailedList: TList<string>;
  LSkippedList: TList<string>;
  LOrderState: TAcmeOrderState;
  LDomainList: string;
  LDaysUntilExpiry: Integer;
  LExpiryDate: TDateTime;
  LCertFile: string;
  LDomainPrefix: string;
begin
  Log('=== AUTO RENEW ===');
  Log('Starting automatic certificate renewal process...');
  Log('Renewal window: certificates expiring within ' + IntToStr(ADays)
    + ' days');

  LSuccessList := TList<string>.Create;
  LFailedList := TList<string>.Create;
  LSkippedList := TList<string>.Create;
  try
    // Find all valid certificates
    LCertFiles := FindCertificateFiles(True);

    if Length(LCertFiles) = 0 then
    begin
      Log('No valid certificates found to check.');
      SetLength(ASuccess, 0);
      SetLength(AFailed, 0);
      Exit;
    end;

    Log('Found ' + IntToStr(Length(LCertFiles)) +
      ' valid certificate(s) to check');
    Log('');

    // Attempt to renew each certificate
    for LOrderFile in LCertFiles do
    begin
      try
        // Load order state to get domain info
        LOrderState := LoadOrderState(TPath.Combine(GetCertificateStoragePath,
          LOrderFile));
        LDomainList := string.Join(', ', LOrderState.Domains);

        // Build certificate file path
        LDomainPrefix := StringReplace(LOrderFile, 'order_', '', [rfIgnoreCase]);
        LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);
        LCertFile := TPath.Combine(GetCertificateStoragePath, 
          Format('certificate_%s.pem', [LDomainPrefix]));

        // Get actual certificate expiry date from the certificate file
        if not TFile.Exists(LCertFile) then
        begin
          Log('WARNING: Certificate file not found: ' + LCertFile);
          LFailedList.Add(LOrderFile);
          Continue;
        end;
        
        LExpiryDate := GetCertificateExpiryDate(LCertFile);
        
        if LExpiryDate <= 0 then
        begin
          Log('WARNING: Could not read certificate expiry date from ' + LCertFile);
          LFailedList.Add(LOrderFile);
          Continue;
        end;
        
        LDaysUntilExpiry := DaysBetween(Now, LExpiryDate);

        Log('---');
        Log('Processing: ' + LOrderFile);
        Log('Domains: ' + LDomainList);
        Log('Created: ' + DateTimeToStr(LOrderState.Created));
        Log('Certificate Expires: ' + DateTimeToStr(LExpiryDate));
        Log('Days until expiry: ' + IntToStr(LDaysUntilExpiry));

        // Check if certificate is within renewal window
        if LExpiryDate < Now then
        begin
          Log('Certificate has already expired! Attempting renewal...');
        end
        else if LDaysUntilExpiry > ADays then
        begin
          Log('SKIPPED: Certificate not due for renewal (expires in ' +
            IntToStr(LDaysUntilExpiry) + ' days, threshold is ' +
            IntToStr(ADays) + ' days)');
          LSkippedList.Add(LOrderFile);
          Log('');
          Continue;
        end
        else
        begin
          Log('Certificate is within renewal window, proceeding...');
        end;

        if RenewExistingCertificate(LOrderFile) then
        begin
          Log('SUCCESS: Renewed ' + LDomainList);
          LSuccessList.Add(LOrderFile);
        end
        else
        begin
          Log('FAILED: Could not renew ' + LDomainList);
          LFailedList.Add(LOrderFile);
        end;

        Log('');
      except
        on E: Exception do
        begin
          Log('ERROR: Exception while processing ' + LOrderFile + ': ' +
            E.Message);
          LFailedList.Add(LOrderFile);
          Log('');
        end;
      end;
    end;

    // Convert lists to arrays
    SetLength(ASuccess, LSuccessList.Count);
    SetLength(AFailed, LFailedList.Count);

    if LSuccessList.Count > 0 then
      ASuccess := LSuccessList.ToArray;

    if LFailedList.Count > 0 then
      AFailed := LFailedList.ToArray;

    // Summary
    Log('=== AUTO RENEW COMPLETE ===');
    Log('Total certificates checked: ' + IntToStr(Length(LCertFiles)));
    Log('Skipped (not due): ' + IntToStr(LSkippedList.Count));
    Log('Successfully renewed: ' + IntToStr(LSuccessList.Count));
    Log('Failed: ' + IntToStr(LFailedList.Count));

    if LSkippedList.Count > 0 then
    begin
      Log('');
      Log('Skipped (not within ' + IntToStr(ADays) + ' day renewal window):');
      for LOrderFile in LSkippedList do
        Log('  - ' + LOrderFile);
    end;

    if LSuccessList.Count > 0 then
    begin
      Log('');
      Log('Successfully renewed:');
      for LOrderFile in ASuccess do
        Log('  - ' + LOrderFile);
    end;

    if LFailedList.Count > 0 then
    begin
      Log('');
      Log('Failed to renew:');
      for LOrderFile in AFailed do
        Log('  - ' + LOrderFile);
    end;

  finally
    LSuccessList.Free;
    LFailedList.Free;
    LSkippedList.Free;
  end;
end;

end.
