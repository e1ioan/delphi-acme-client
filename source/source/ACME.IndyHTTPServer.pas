unit ACME.IndyHTTPServer;

interface

uses
  System.Classes, System.SysUtils, System.JSON,
  System.Math, System.IOUtils, System.DateUtils,
  System.SyncObjs,  IdSSLOpenSSL, IdSSLOpenSSLHeaders,
  IdHTTPServer, ACME.Types, OpenSSL3.Lib, OpenSSL3.Helper,
  ACME.Orders;

type
  TACMEIndyHTTPServer = class;

  // Thread-based timer for NT service compatibility
  TACMERenewalThread = class(TThread)
  private
    FOwner: TACMEIndyHTTPServer;
    FTerminateEvent: TEvent;
    FIntervalHours: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TACMEIndyHTTPServer;
      AIntervalHours: Integer = 24);
    destructor Destroy; override;
    procedure StopThread;
  end;

  TACMEIndyHTTPServer = class(TAcmeObject)
  private
    FIdHTTPServer: TIdHTTPServer;
    FOrderName: string;
    FOrders: TACMEOrders;
    FRenewalThread: TACMERenewalThread;
    FCertificateFile: string;
    FPrivateKeyFile: string;
    FServerWasActive: Boolean;
    FLastCertificateModified: TDateTime;
    FRenewalIntervalHours: Integer;
    procedure SetOrderName(const AValue: string);
    procedure SetIdHTTPServer(const AValue: TIdHTTPServer);
    procedure SetRenewalIntervalHours(const AValue: Integer);
    function GetCertificateFilePath: string;
    function GetPrivateKeyFilePath: string;
    function CheckCertificateFilesChanged: Boolean;
    procedure RestartServerIfNeeded;
    procedure StartRenewalThread;
    procedure StopRenewalThread;
  protected
  public
    constructor Create(AOwner: TComponent = nil);
    destructor Destroy; override;

    procedure ConfigureSSL;
    procedure ClearSSL;
    procedure RenewSSL;

    property OrderName: string read FOrderName write SetOrderName;
    property HTTPServer: TIdHTTPServer read FIdHTTPServer write SetIdHTTPServer;
    property Orders: TACMEOrders read FOrders;
    property RenewalIntervalHours: Integer read FRenewalIntervalHours
      write SetRenewalIntervalHours;
  end;

implementation

{ TACMERenewalThread }

constructor TACMERenewalThread.Create(AOwner: TACMEIndyHTTPServer;
  AIntervalHours: Integer = 24);
begin
  inherited Create(True); // Create suspended
  FOwner := AOwner;
  FIntervalHours := AIntervalHours;
  FTerminateEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TACMERenewalThread.Destroy;
begin
  FTerminateEvent.Free;
  inherited;
end;

procedure TACMERenewalThread.StopThread;
begin
  Terminate;
  FTerminateEvent.SetEvent;
  WaitFor;
end;

procedure TACMERenewalThread.Execute;
var
  LWaitResult: TWaitResult;
  LIntervalMs: Cardinal;
begin
  LIntervalMs := FIntervalHours * 60 * 60 * 1000;
  // Convert hours to milliseconds

  while not Terminated do
  begin
    // Wait for the interval or termination event
    LWaitResult := FTerminateEvent.WaitFor(LIntervalMs);

    if LWaitResult = wrSignaled then
      Break; // Thread was terminated

    if not Terminated and Assigned(FOwner) then
    begin
      try
        // Perform renewal
        FOwner.RenewSSL;
      except
        on E: Exception do
        begin
          // Log error but continue thread
          if Assigned(FOwner) then
            FOwner.Log('ERROR in renewal thread: ' + E.Message);
        end;
      end;
    end;
  end;
end;

{ TACMEIndyHTTPServer }

constructor TACMEIndyHTTPServer.Create(AOwner: TComponent = nil);
begin
  inherited Create;
  FIdHTTPServer := nil;
  FOrderName := '';
  FOrders := TACMEOrders.Create;
  FCertificateFile := '';
  FPrivateKeyFile := '';
  FServerWasActive := False;
  FLastCertificateModified := 0;
  FRenewalThread := nil;
  FRenewalIntervalHours := 24; // Default to 24 hours
end;

destructor TACMEIndyHTTPServer.Destroy;
begin
  StopRenewalThread;
  FOrders.Free;
  inherited;
end;

procedure TACMEIndyHTTPServer.SetOrderName(const AValue: string);
begin
  if FOrderName <> AValue then
  begin
    FOrderName := AValue;
    FCertificateFile := '';
    FPrivateKeyFile := '';

    if FOrderName <> '' then
    begin
      ConfigureSSL;

      // Start renewal thread if we have an order
      StartRenewalThread;
    end
    else
    begin
      // Stop renewal thread if order name is cleared
      StopRenewalThread;
    end;
  end;
end;

procedure TACMEIndyHTTPServer.SetRenewalIntervalHours(const AValue: Integer);
begin
  if (AValue > 0) and (FRenewalIntervalHours <> AValue) then
  begin
    FRenewalIntervalHours := AValue;

    // Restart thread with new interval if it's running
    if Assigned(FRenewalThread) then
    begin
      StopRenewalThread;
      if FOrderName <> '' then
        StartRenewalThread;
    end;
  end;
end;

procedure TACMEIndyHTTPServer.StartRenewalThread;
begin
  if Assigned(FRenewalThread) then
    Exit; // Thread already running

  Log('Starting automatic renewal thread (interval: ' +
    IntToStr(FRenewalIntervalHours) + ' hours)');
  FRenewalThread := TACMERenewalThread.Create(Self, FRenewalIntervalHours);
  FRenewalThread.Start;
end;

procedure TACMEIndyHTTPServer.StopRenewalThread;
begin
  if not Assigned(FRenewalThread) then
    Exit;

  Log('Stopping automatic renewal thread');
  try
    FRenewalThread.StopThread;
    FreeAndNil(FRenewalThread);
  except
    on E: Exception do
    begin
      Log('ERROR stopping renewal thread: ' + E.Message);
      // Force free if stop failed
      FreeAndNil(FRenewalThread);
    end;
  end;
end;

procedure TACMEIndyHTTPServer.SetIdHTTPServer(const AValue: TIdHTTPServer);
begin
  if FIdHTTPServer <> AValue then
  begin
    FIdHTTPServer := AValue;

    if (FIdHTTPServer <> nil) and (FOrderName <> '') then
    begin
      ConfigureSSL;
    end;
  end;
end;

function TACMEIndyHTTPServer.GetCertificateFilePath: string;
var
  LStoragePath: string;
  LDomainPrefix: string;
begin
  if FCertificateFile <> '' then
    Exit(FCertificateFile);

  if FOrderName = '' then
    Exit('');

  LStoragePath := FOrders.StorageFolder;

  // Extract domain prefix from order filename (order_domain.json -> domain)
  LDomainPrefix := StringReplace(FOrderName, 'order_', '', [rfIgnoreCase]);
  LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);

  FCertificateFile := TPath.Combine(LStoragePath, Format('certificate_%s.pem',
    [LDomainPrefix]));
  Result := FCertificateFile;
end;

function TACMEIndyHTTPServer.GetPrivateKeyFilePath: string;
var
  LStoragePath: string;
  LDomainPrefix: string;
begin
  if FPrivateKeyFile <> '' then
    Exit(FPrivateKeyFile);

  if FOrderName = '' then
    Exit('');

  LStoragePath := FOrders.StorageFolder;

  // Extract domain prefix from order filename (order_domain.json -> domain)
  LDomainPrefix := StringReplace(FOrderName, 'order_', '', [rfIgnoreCase]);
  LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);

  FPrivateKeyFile := TPath.Combine(LStoragePath, Format('private_%s.key',
    [LDomainPrefix]));
  Result := FPrivateKeyFile;
end;

function TACMEIndyHTTPServer.CheckCertificateFilesChanged: Boolean;
var
  LCertFile: string;
  LModified: TDateTime;
begin
  Result := False;
  LCertFile := GetCertificateFilePath;

  if not TFile.Exists(LCertFile) then
    Exit;

  LModified := TFile.GetLastWriteTime(LCertFile);

  if FLastCertificateModified = 0 then
  begin
    FLastCertificateModified := LModified;
    Exit;
  end;

  if LModified <> FLastCertificateModified then
  begin
    FLastCertificateModified := LModified;
    Result := True;
  end;
end;

procedure TACMEIndyHTTPServer.RestartServerIfNeeded;
begin
  if FIdHTTPServer = nil then
    Exit;

  if FServerWasActive then
  begin
    Log('Certificate files changed, restarting server to apply new SSL configuration...');

    try
      FIdHTTPServer.Active := False;
      Sleep(100); // Brief pause to ensure clean shutdown

      ConfigureSSL;

      FIdHTTPServer.Active := True;
      Log('Server restarted successfully with new SSL configuration');
    except
      on E: Exception do
      begin
        Log('ERROR: Failed to restart server: ' + E.Message);
        raise;
      end;
    end;
  end;
end;

procedure TACMEIndyHTTPServer.ConfigureSSL;
var
  LCertFile: string;
  LKeyFile: string;
  LSSLIOHandler: TIdServerIOHandlerSSLOpenSSL;
  LServerCertFile: string;
  LChainCertFile: string;
  LStoragePath: string;
  LDomainPrefix: string;
begin
  if FIdHTTPServer = nil then
  begin
    Log('Cannot configure SSL: HTTPServer is not assigned');
    Exit;
  end;

  if FOrderName = '' then
  begin
    Log('Cannot configure SSL: OrderName is not set');
    Exit;
  end;

  if not FOrders.IsOpenSSLLoaded then
  begin
    Log('OpenSSL is not avaialable');
    Exit;
  end;

  Log('=== Configuring SSL for HTTP Server ===');

  LCertFile := GetCertificateFilePath;
  LKeyFile := GetPrivateKeyFilePath;

  if not TFile.Exists(LCertFile) then
  begin
    Log('ERROR: Certificate file not found: ' + LCertFile);
    Exit;
  end;

  if not TFile.Exists(LKeyFile) then
  begin
    Log('ERROR: Private key file not found: ' + LKeyFile);
    Exit;
  end;

  Log('Certificate file: ' + LCertFile);
  Log('Private key file: ' + LKeyFile);

  try
    // Remember if server was active
    FServerWasActive := FIdHTTPServer.Active;

    // Stop server before reconfiguring SSL
    if FServerWasActive then
    begin
      Log('Stopping server to reconfigure SSL...');
      FIdHTTPServer.Active := False;
    end;

    // Split certificate bundle if needed (for Indy compatibility)
    // Let's Encrypt provides full chain, Indy needs server cert separate from chain
    if FOrders.IsCertificateBundled(LCertFile) then
    begin
      Log('Certificate bundle detected, splitting...');
      FOrders.SplitCertificateBundle(LCertFile);

      // Build split file paths
      LStoragePath := FOrders.StorageFolder;
      LDomainPrefix := StringReplace(FOrderName, 'order_', '', [rfIgnoreCase]);
      LDomainPrefix := StringReplace(LDomainPrefix, '.json', '',
        [rfIgnoreCase]);

      LServerCertFile := TPath.Combine(LStoragePath,
        Format('server_%s.pem', [LDomainPrefix]));
      LChainCertFile := TPath.Combine(LStoragePath,
        Format('chain_%s.pem', [LDomainPrefix]));
    end
    else
    begin
      // Single certificate, use as-is
      LServerCertFile := LCertFile;
      LChainCertFile := '';
      Log('Single certificate (no chain)');
    end;

    // Create or get existing SSL IO Handler
    if not Assigned(FIdHTTPServer.IOHandler) or
      not(FIdHTTPServer.IOHandler is TIdServerIOHandlerSSLOpenSSL) then
    begin
      Log('Creating new SSL IO Handler');
      LSSLIOHandler := TIdServerIOHandlerSSLOpenSSL.Create(FIdHTTPServer);
      FIdHTTPServer.IOHandler := LSSLIOHandler;
    end
    else
    begin
      Log('Using existing SSL IO Handler');
      LSSLIOHandler := FIdHTTPServer.IOHandler as TIdServerIOHandlerSSLOpenSSL;
    end;

    // Configure SSL options
    LSSLIOHandler.SSLOptions.Mode := sslmServer;
    LSSLIOHandler.SSLOptions.Method := sslvTLSv1_2;
    // Note: Don't set SSLVersions when using Method - use one or the other, not both
    LSSLIOHandler.SSLOptions.VerifyMode := [];
    LSSLIOHandler.SSLOptions.VerifyDepth := 0;

    // Set certificate files
    Log('Setting certificate files...');
    LSSLIOHandler.SSLOptions.CertFile := LServerCertFile;
    Log('CertFile set: ' + LServerCertFile);
    Log('Certificate expiry date: ' +
      DateTimeToStr(Orders.GetCertificateExpiryDate(LServerCertFile)));

    LSSLIOHandler.SSLOptions.KeyFile := LKeyFile;
    Log('KeyFile set: ' + LKeyFile);

    // ACME certificates don't have passwords
    LSSLIOHandler.OnGetPassword := nil;

    // Set chain certificate if available
    if LChainCertFile <> '' then
    begin
      LSSLIOHandler.SSLOptions.RootCertFile := LChainCertFile;
      Log('RootCertFile set: ' + LChainCertFile);
    end
    else
    begin
      LSSLIOHandler.SSLOptions.RootCertFile := '';
      Log('No chain certificate');
    end;

    // Update last modified time
    FLastCertificateModified := TFile.GetLastWriteTime(LCertFile);

    Log('SSL configured successfully');

    // Restart server if it was active
    if FServerWasActive then
    begin
      Log('Restarting server...');
      FIdHTTPServer.Active := True;
      Log('Server restarted successfully');
    end;
  except
    on E: Exception do
    begin
      Log('ERROR: Failed to configure SSL: ' + E.Message);
      raise;
    end;
  end;
end;

procedure TACMEIndyHTTPServer.ClearSSL;
var
  LWasActive: Boolean;
begin
  if FIdHTTPServer = nil then
    Exit;

  Log('=== Clearing SSL Configuration ===');

  try
    LWasActive := FIdHTTPServer.Active;

    if LWasActive then
    begin
      Log('Stopping server...');
      FIdHTTPServer.Active := False;
    end;

    if Assigned(FIdHTTPServer.IOHandler) then
    begin
      Log('Removing SSL IO Handler');
      FIdHTTPServer.IOHandler.Free;
      FIdHTTPServer.IOHandler := nil;
    end;

    FServerWasActive := False;
    FLastCertificateModified := 0;

    Log('SSL configuration cleared');

    if LWasActive then
    begin
      Log('Note: Server was stopped. Call ConfigureSSL to re-enable SSL and restart.');
    end;
  except
    on E: Exception do
    begin
      Log('ERROR: Failed to clear SSL: ' + E.Message);
      raise;
    end;
  end;
end;

procedure TACMEIndyHTTPServer.RenewSSL;
var
  LSuccess: Boolean;
  LCertFilesChanged: Boolean;
begin
  if FOrderName = '' then
  begin
    Log('Cannot renew SSL: OrderName is not set');
    Exit;
  end;

  if not FOrders.IsOpenSSLLoaded then
  begin
    Log('OpenSSL is not avaialable');
    Exit;
  end;

  Log('=== Renewing SSL Certificate ===');
  Log('Order: ' + FOrderName);

  try
    Log('Starting certificate renewal process...');
    LSuccess := FOrders.RenewExistingCertificate(FOrderName);

    if LSuccess then
    begin
      Log('Certificate renewed successfully');

      // Check if certificate files have changed
      LCertFilesChanged := CheckCertificateFilesChanged;

      if LCertFilesChanged then
      begin
        // Reconfigure SSL with new certificate
        RestartServerIfNeeded;
      end
      else
      begin
        Log('Certificate files unchanged, no server restart needed');
      end;
    end
    else
    begin
      Log('ERROR: Certificate renewal failed - check logs above for details');
    end;
  except
    on E: Exception do
    begin
      Log('ERROR: Exception during certificate renewal: ' + E.ClassName + ': ' +
        E.Message);
      raise;
    end;
  end;
end;

end.
