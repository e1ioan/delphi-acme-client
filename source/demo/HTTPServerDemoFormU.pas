unit HTTPServerDemoFormU;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  IdHTTPServer, IdContext, IdCustomHTTPServer, IdSSLOpenSSL, IdGlobal,
  ACME.IndyHTTPServer, ACME.Orders, ACME.Types;

type
  THTTPServerDemoForm = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelCenter: TPanel;
    MemoLog: TMemo;
    PanelBottom: TPanel;
    StatusBar: TStatusBar;
    GroupBoxServer: TGroupBox;
    LabelPort: TLabel;
    EditPort: TEdit;
    ButtonStartServer: TButton;
    ButtonStopServer: TButton;
    CheckBoxSSL: TCheckBox;
    GroupBoxCertificate: TGroupBox;
    LabelOrderFile: TLabel;
    ComboBoxOrders: TComboBox;
    ButtonRefreshOrders: TButton;
    ButtonConfigureSSL: TButton;
    ButtonClearSSL: TButton;
    ButtonRenewCertificate: TButton;
    ButtonVerifyCert: TButton;
    ButtonNewCertificate: TButton;
    GroupBoxRenewal: TGroupBox;
    LabelRenewalInterval: TLabel;
    EditRenewalInterval: TEdit;
    LabelHours: TLabel;
    ButtonApplyInterval: TButton;
    CheckBoxAutoRenewal: TCheckBox;
    ButtonTestServer: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonStartServerClick(Sender: TObject);
    procedure ButtonStopServerClick(Sender: TObject);
    procedure ButtonRefreshOrdersClick(Sender: TObject);
    procedure ButtonConfigureSSLClick(Sender: TObject);
    procedure ButtonClearSSLClick(Sender: TObject);
    procedure ButtonRenewCertificateClick(Sender: TObject);
    procedure ButtonApplyIntervalClick(Sender: TObject);
    procedure ButtonTestServerClick(Sender: TObject);
    procedure CheckBoxSSLClick(Sender: TObject);
    procedure CheckBoxAutoRenewalClick(Sender: TObject);
    procedure ButtonVerifyCertClick(Sender: TObject);
    procedure ButtonNewCertificateClick(Sender: TObject);
  private
    FIdHTTPServer: TIdHTTPServer;
    FACMEIndyHTTPServer: TACMEIndyHTTPServer;
    FHTMLFolder: string;
    procedure OnHTTPServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure OnLogEvent(ASender: TObject; AMessage: string);
    procedure LoadAvailableOrders;
    procedure UpdateServerStatus;
    procedure HandleStaticFileRequest(ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    function GetRequestedFileName(const APath: string;
      const AHTMLFolder: string; out AFileName: string): Boolean;
    function GetMIMEType(const AFileName: string): string;
    procedure HTTPServerConnect(AContext: TIdContext);
    procedure HTTPServerDisconnect(AContext: TIdContext);
    procedure HTTPServerException(AContext: TIdContext; AException: Exception);
    procedure HTTPServerQuerySSLPort(APort: TIdPort; var VUseSSL: Boolean);
    function OpenURL(const URL: string): Boolean;
  public
  end;

var
  HTTPServerDemoForm: THTTPServerDemoForm;

implementation

{$R *.dfm}

uses
  System.IOUtils, Winapi.ShellAPI, ACME.NewCertificateForm;

procedure THTTPServerDemoForm.FormCreate(Sender: TObject);
begin
  // Create HTTP Server
  FIdHTTPServer := TIdHTTPServer.Create(nil);
  FIdHTTPServer.OnCommandGet := OnHTTPServerCommandGet;
  FIdHTTPServer.OnConnect := HTTPServerConnect;
  FIdHTTPServer.OnDisconnect := HTTPServerDisconnect;
  FIdHTTPServer.OnException := HTTPServerException;
  FIdHTTPServer.OnQuerySSLPort := HTTPServerQuerySSLPort;
  FIdHTTPServer.DefaultPort := 8080;

  // Create ACME HTTP Server Manager
  FACMEIndyHTTPServer := TACMEIndyHTTPServer.Create;
  FACMEIndyHTTPServer.OnLog := OnLogEvent;
  FACMEIndyHTTPServer.HTTPServer := FIdHTTPServer;

  // Initialize HTML folder (html subfolder in EXE directory)
  FHTMLFolder := TPath.Combine(ExtractFilePath(ParamStr(0)), 'html');
  if not TDirectory.Exists(FHTMLFolder) then
    TDirectory.CreateDirectory(FHTMLFolder);

  // Initialize UI
  EditPort.Text := '8080';
  EditRenewalInterval.Text := '24';
  CheckBoxSSL.Checked := False;
  CheckBoxAutoRenewal.Checked := False;

  // Load available orders
  LoadAvailableOrders;

  OnLogEvent(Self, 'HTTP Server Demo initialized');
  OnLogEvent(Self, 'Storage folder: ' +
    FACMEIndyHTTPServer.Orders.StorageFolder);
  OnLogEvent(Self, 'HTML folder: ' + FHTMLFolder);

  UpdateServerStatus;
end;

procedure THTTPServerDemoForm.FormDestroy(Sender: TObject);
begin
  if FIdHTTPServer.Active then
    FIdHTTPServer.Active := False;

  FACMEIndyHTTPServer.Free;
  FIdHTTPServer.Free;
end;

procedure THTTPServerDemoForm.OnLogEvent(ASender: TObject; AMessage: string);
begin
  try
    if Assigned(MemoLog) then
    begin
      MemoLog.Lines.Add('[' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + '] '
        + AMessage);
      Application.ProcessMessages;
    end;
  except
    // Ignore logging errors
  end;
end;

procedure THTTPServerDemoForm.HTTPServerConnect(AContext: TIdContext);
var
  LIsSSL: Boolean;
begin
  LIsSSL := (AContext.Connection.IOHandler is TIdSSLIOHandlerSocketOpenSSL);
  OnLogEvent(Self, Format('Client connected from %s (SSL: %s)',
    [AContext.Binding.PeerIP, BoolToStr(LIsSSL, True)]));
end;

procedure THTTPServerDemoForm.HTTPServerDisconnect(AContext: TIdContext);
begin
  OnLogEvent(Self, Format('Client disconnected from %s',
    [AContext.Binding.PeerIP]));
end;

procedure THTTPServerDemoForm.HTTPServerException(AContext: TIdContext;
  AException: Exception);
begin
  OnLogEvent(Self, 'EXCEPTION: ' + AException.ClassName + ': ' +
    AException.Message);
end;

procedure THTTPServerDemoForm.HTTPServerQuerySSLPort(APort: TIdPort;
  var VUseSSL: Boolean);
begin
  // Tell Indy whether to use SSL for this port
  VUseSSL := CheckBoxSSL.Checked;
  OnLogEvent(Self, Format('QuerySSLPort: Port=%d, UseSSL=%s',
    [APort, BoolToStr(VUseSSL, True)]));
end;

procedure THTTPServerDemoForm.OnHTTPServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LIsSSL: Boolean;
begin
  try
    // Determine if connection is SSL
    LIsSSL := (AContext.Connection.IOHandler is TIdSSLIOHandlerSocketOpenSSL);

    OnLogEvent(Self, Format('Request: %s %s (SSL: %s, Client: %s)',
      [ARequestInfo.Command, ARequestInfo.Document, BoolToStr(LIsSSL, True),
      AContext.Connection.Socket.Binding.PeerIP]));

    HandleStaticFileRequest(ARequestInfo, AResponseInfo);

  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'ERROR handling request: ' + E.ClassName + ': ' +
        E.Message);
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ContentText := 'Internal Server Error';
    end;
  end;
end;

procedure THTTPServerDemoForm.LoadAvailableOrders;
var
  LOrders: TArray<string>;
  LOrder: string;
begin
  ComboBoxOrders.Clear;

  try
    LOrders := FACMEIndyHTTPServer.Orders.FindCertificateFiles(True);

    for LOrder in LOrders do
      ComboBoxOrders.Items.Add(LOrder);

    if ComboBoxOrders.Items.Count > 0 then
      ComboBoxOrders.ItemIndex := 0;

    OnLogEvent(Self, 'Found ' + IntToStr(Length(LOrders)) +
      ' valid certificate(s)');
  except
    on E: Exception do
      OnLogEvent(Self, 'ERROR loading orders: ' + E.Message);
  end;
end;

procedure THTTPServerDemoForm.UpdateServerStatus;
begin
  if FIdHTTPServer.Active then
  begin
    StatusBar.SimpleText := 'Server Running on Port ' +
      IntToStr(FIdHTTPServer.DefaultPort) + ' - SSL: ' +
      BoolToStr(CheckBoxSSL.Checked, True);
    ButtonStartServer.Enabled := False;
    ButtonStopServer.Enabled := True;
    ButtonTestServer.Enabled := True;
  end
  else
  begin
    StatusBar.SimpleText := 'Server Stopped';
    ButtonStartServer.Enabled := True;
    ButtonStopServer.Enabled := False;
    ButtonTestServer.Enabled := False;
  end;
end;

procedure THTTPServerDemoForm.ButtonStartServerClick(Sender: TObject);
var
  LPort: Integer;
begin
  try
    OnLogEvent(Self, '=== Starting Server ===');
    LPort := StrToIntDef(EditPort.Text, 8080);
    OnLogEvent(Self, 'Target port: ' + IntToStr(LPort));

    // Clear existing bindings
    OnLogEvent(Self, 'Clearing existing bindings...');
    FIdHTTPServer.Bindings.Clear;

    // Add new binding
    OnLogEvent(Self, 'Adding new binding (0.0.0.0:' + IntToStr(LPort) + ')');
    with FIdHTTPServer.Bindings.Add do
    begin
      IP := '0.0.0.0';
      Port := LPort;
    end;
    FIdHTTPServer.DefaultPort := LPort;

    if CheckBoxSSL.Checked and (ComboBoxOrders.ItemIndex >= 0) then
    begin
      OnLogEvent(Self, 'SSL enabled, configuring certificates...');
      OnLogEvent(Self, 'Selected order: ' + ComboBoxOrders.Text);

      // Configure SSL before starting
      FACMEIndyHTTPServer.OrderName := ComboBoxOrders.Text;
      FACMEIndyHTTPServer.ConfigureSSL;

      // Verify SSL configuration
      if Assigned(FIdHTTPServer.IOHandler) then
      begin
        OnLogEvent(Self, 'IOHandler assigned: ' +
          FIdHTTPServer.IOHandler.ClassName);
        if FIdHTTPServer.IOHandler is TIdServerIOHandlerSSLOpenSSL then
        begin
          OnLogEvent(Self, 'SSL IOHandler confirmed');
          with TIdServerIOHandlerSSLOpenSSL(FIdHTTPServer.IOHandler)
            .SSLOptions do
          begin
            OnLogEvent(Self, 'SSL CertFile: ' + CertFile);
            OnLogEvent(Self, 'SSL KeyFile: ' + KeyFile);
            OnLogEvent(Self, 'SSL RootCertFile: ' + RootCertFile);
            OnLogEvent(Self, 'SSL Mode: ' + IntToStr(Ord(Mode)));
            OnLogEvent(Self, 'SSL Method: ' + IntToStr(Ord(Method)));
          end;
        end
        else
          OnLogEvent(Self,
            'WARNING: IOHandler is not TIdServerIOHandlerSSLOpenSSL!');
      end
      else
        OnLogEvent(Self, 'ERROR: IOHandler is not assigned!');
    end
    else if CheckBoxSSL.Checked then
    begin
      OnLogEvent(Self, 'ERROR: SSL enabled but no certificate selected!');
      ShowMessage('Please select a certificate order before enabling SSL');
      Exit;
    end
    else
    begin
      OnLogEvent(Self, 'SSL disabled, starting in HTTP mode');
    end;

    OnLogEvent(Self, 'Activating server...');
    FIdHTTPServer.Active := True;
    OnLogEvent(Self, 'Server started successfully on port ' + IntToStr(LPort));

    if CheckBoxSSL.Checked then
      OnLogEvent(Self, 'SSL Enabled - Access via https://localhost:' +
        IntToStr(LPort))
    else
      OnLogEvent(Self, 'SSL Disabled - Access via http://localhost:' +
        IntToStr(LPort));

    UpdateServerStatus;
  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'EXCEPTION starting server: ' + E.ClassName + ': ' +
        E.Message);
      OnLogEvent(Self, 'Server start failed!');
      ShowMessage('Failed to start server: ' + E.Message + #13#10 +
        'Check the log for details.');
    end;
  end;
end;

procedure THTTPServerDemoForm.ButtonStopServerClick(Sender: TObject);
begin
  try
    FIdHTTPServer.Active := False;
    OnLogEvent(Self, 'Server stopped');
    UpdateServerStatus;
  except
    on E: Exception do
      OnLogEvent(Self, 'ERROR stopping server: ' + E.Message);
  end;
end;

procedure THTTPServerDemoForm.ButtonRefreshOrdersClick(Sender: TObject);
begin
  LoadAvailableOrders;
end;

procedure THTTPServerDemoForm.ButtonConfigureSSLClick(Sender: TObject);
begin
  if ComboBoxOrders.ItemIndex < 0 then
  begin
    ShowMessage('Please select a certificate order first');
    Exit;
  end;

  try
    OnLogEvent(Self, '=== Configuring SSL ===');
    OnLogEvent(Self, 'Selected order: ' + ComboBoxOrders.Text);

    FACMEIndyHTTPServer.OrderName := ComboBoxOrders.Text;
    FACMEIndyHTTPServer.ConfigureSSL;

    // Verify SSL configuration
    if Assigned(FIdHTTPServer.IOHandler) then
    begin
      OnLogEvent(Self, 'IOHandler assigned: ' +
        FIdHTTPServer.IOHandler.ClassName);
      if FIdHTTPServer.IOHandler is TIdServerIOHandlerSSLOpenSSL then
      begin
        with TIdServerIOHandlerSSLOpenSSL(FIdHTTPServer.IOHandler).SSLOptions do
        begin
          OnLogEvent(Self, 'SSL CertFile: ' + CertFile);
          OnLogEvent(Self, 'SSL KeyFile: ' + KeyFile);
          OnLogEvent(Self, 'SSL RootCertFile: ' + RootCertFile);

          // Check if files exist
          if FileExists(CertFile) then
            OnLogEvent(Self, 'Certificate file exists: YES')
          else
            OnLogEvent(Self, 'ERROR: Certificate file NOT FOUND: ' + CertFile);

          if FileExists(KeyFile) then
            OnLogEvent(Self, 'Private key file exists: YES')
          else
            OnLogEvent(Self, 'ERROR: Private key file NOT FOUND: ' + KeyFile);

          if (RootCertFile <> '') then
          begin
            if FileExists(RootCertFile) then
              OnLogEvent(Self, 'Chain file exists: YES')
            else
              OnLogEvent(Self, 'ERROR: Chain file NOT FOUND: ' + RootCertFile);
          end;
        end;
      end;
    end;

    CheckBoxSSL.Checked := True;
    OnLogEvent(Self, 'SSL configured successfully');
  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'ERROR configuring SSL: ' + E.ClassName + ': ' +
        E.Message);
      ShowMessage('Failed to configure SSL: ' + E.Message);
    end;
  end;
end;

procedure THTTPServerDemoForm.ButtonClearSSLClick(Sender: TObject);
begin
  try
    FACMEIndyHTTPServer.ClearSSL;
    CheckBoxSSL.Checked := False;
    OnLogEvent(Self, 'SSL cleared');
  except
    on E: Exception do
      OnLogEvent(Self, 'ERROR clearing SSL: ' + E.Message);
  end;
end;

procedure THTTPServerDemoForm.ButtonRenewCertificateClick(Sender: TObject);
begin
  if ComboBoxOrders.ItemIndex < 0 then
  begin
    ShowMessage('Please select a certificate order first');
    Exit;
  end;

  try
    OnLogEvent(Self, 'Starting certificate renewal...');
    FACMEIndyHTTPServer.OrderName := ComboBoxOrders.Text;
    FACMEIndyHTTPServer.RenewSSL;
  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'ERROR renewing certificate: ' + E.Message);
      ShowMessage('Failed to renew certificate: ' + E.Message);
    end;
  end;
end;

procedure THTTPServerDemoForm.ButtonApplyIntervalClick(Sender: TObject);
var
  LInterval: Integer;
begin
  LInterval := StrToIntDef(EditRenewalInterval.Text, 24);

  if LInterval < 1 then
  begin
    ShowMessage('Interval must be at least 1 hour');
    Exit;
  end;

  FACMEIndyHTTPServer.RenewalIntervalHours := LInterval;
  OnLogEvent(Self, 'Renewal interval set to ' + IntToStr(LInterval) + ' hours');
end;

function THTTPServerDemoForm.OpenURL(const URL: string): Boolean;
begin
  ShellExecute(0, 'OPEN', PChar(URL), '', '', SW_SHOWNORMAL);
  Result := True;
end;

procedure THTTPServerDemoForm.ButtonTestServerClick(Sender: TObject);
var
  LUrl: string;
begin
  if CheckBoxSSL.Checked then
    LUrl := 'https://localhost:' + IntToStr(FIdHTTPServer.DefaultPort)
  else
    LUrl := 'http://localhost:' + IntToStr(FIdHTTPServer.DefaultPort);

  OnLogEvent(Self, 'Test URL: ' + LUrl);

  OpenURL(LUrl);

end;

procedure THTTPServerDemoForm.CheckBoxSSLClick(Sender: TObject);
begin
  GroupBoxRenewal.Enabled := CheckBoxSSL.Checked;
end;

procedure THTTPServerDemoForm.CheckBoxAutoRenewalClick(Sender: TObject);
begin
  if CheckBoxAutoRenewal.Checked then
  begin
    if ComboBoxOrders.ItemIndex < 0 then
    begin
      ShowMessage('Please select a certificate order first');
      CheckBoxAutoRenewal.Checked := False;
      Exit;
    end;

    FACMEIndyHTTPServer.OrderName := ComboBoxOrders.Text;
    OnLogEvent(Self, 'Automatic renewal enabled');
  end
  else
  begin
    FACMEIndyHTTPServer.OrderName := '';
    OnLogEvent(Self, 'Automatic renewal disabled');
  end;
end;

procedure THTTPServerDemoForm.ButtonVerifyCertClick(Sender: TObject);
var
  LOrderFile: string;
  LDomainPrefix: string;
  LStoragePath: string;
  LCertFile: string;
  LKeyFile: string;
  LServerCertFile: string;
  LChainCertFile: string;
  LErrorMessage: string;
begin
  if ComboBoxOrders.ItemIndex < 0 then
  begin
    ShowMessage('Please select a certificate order first');
    Exit;
  end;

  try
    OnLogEvent(Self, '=== Verifying Certificate Files ===');

    LOrderFile := ComboBoxOrders.Text;
    LStoragePath := FACMEIndyHTTPServer.Orders.StorageFolder;

    // Extract domain prefix
    LDomainPrefix := StringReplace(LOrderFile, 'order_', '', [rfIgnoreCase]);
    LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);

    // Build file paths
    LCertFile := TPath.Combine(LStoragePath, Format('certificate_%s.pem',
      [LDomainPrefix]));
    LKeyFile := TPath.Combine(LStoragePath, Format('private_%s.key',
      [LDomainPrefix]));
    LServerCertFile := TPath.Combine(LStoragePath,
      Format('server_%s.pem', [LDomainPrefix]));
    LChainCertFile := TPath.Combine(LStoragePath,
      Format('chain_%s.pem', [LDomainPrefix]));

    OnLogEvent(Self, 'Checking files:');
    OnLogEvent(Self, '  Bundle: ' + LCertFile);
    OnLogEvent(Self, '  Server: ' + LServerCertFile);
    OnLogEvent(Self, '  Chain: ' + LChainCertFile);
    OnLogEvent(Self, '  Key: ' + LKeyFile);

    // Check existence
    OnLogEvent(Self, 'File existence:');
    OnLogEvent(Self, '  Bundle exists: ' +
      BoolToStr(TFile.Exists(LCertFile), True));
    OnLogEvent(Self, '  Server exists: ' +
      BoolToStr(TFile.Exists(LServerCertFile), True));
    OnLogEvent(Self, '  Chain exists: ' +
      BoolToStr(TFile.Exists(LChainCertFile), True));
    OnLogEvent(Self, '  Key exists: ' +
      BoolToStr(TFile.Exists(LKeyFile), True));

    OnLogEvent(Self, 'Expiry date: ' +
      DateTimeToStr(FACMEIndyHTTPServer.Orders.GetCertificateExpiryDate
      (LServerCertFile)));

    // Verify certificate and key match
    OnLogEvent(Self, 'Verifying certificate and key compatibility...');
    if TFile.Exists(LServerCertFile) then
    begin
      if FACMEIndyHTTPServer.Orders.VerifyCertificateAndKey(LServerCertFile,
        LKeyFile, LErrorMessage) then
        OnLogEvent(Self, 'Server certificate and key are VALID')
      else
        OnLogEvent(Self, 'ERROR: ' + LErrorMessage);
    end
    else
    begin
      OnLogEvent(Self,
        'Server certificate not found - run "Configure SSL" to split bundle');
    end;

    OnLogEvent(Self, 'Verification complete');

  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'ERROR during verification: ' + E.Message);
      ShowMessage('Verification failed: ' + E.Message);
    end;
  end;
end;

procedure THTTPServerDemoForm.ButtonNewCertificateClick(Sender: TObject);
begin
  try
    OnLogEvent(Self, '=== Creating New Certificate ===');
    
    if TACMENewCertificateForm.CreateNewCertificate(FACMEIndyHTTPServer.Orders) then
    begin
      OnLogEvent(Self, 'Certificate creation completed successfully');
      LoadAvailableOrders; // Refresh the orders list
      ShowMessage('Certificate created successfully! ' + 
        'Select it from the dropdown and click "Configure SSL".');
    end
    else
    begin
      OnLogEvent(Self, 'Certificate creation cancelled or failed');
    end;
  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'ERROR creating certificate: ' + E.Message);
      ShowMessage('Failed to create certificate: ' + E.Message);
    end;
  end;
end;

function THTTPServerDemoForm.GetRequestedFileName(const APath: string;
  const AHTMLFolder: string; out AFileName: string): Boolean;
var
  LFilePath: string;
  LFullPath: string;
begin
  Result := False;
  AFileName := '';

  LFilePath := APath;

  // Remove leading slash
  if LFilePath.StartsWith('/') then
    LFilePath := LFilePath.Substring(1);

  // Prevent directory traversal attacks
  if LFilePath.Contains('..') then
    Exit;

  // Build full path
  LFullPath := TPath.Combine(AHTMLFolder, LFilePath);

  // Check if file exists
  if TFile.Exists(LFullPath) then
  begin
    AFileName := LFullPath;
    Result := True;
  end
  else if TDirectory.Exists(LFullPath) then
  begin
    // Try index.html if requesting a directory
    LFullPath := TPath.Combine(LFullPath, 'index.html');
    if TFile.Exists(LFullPath) then
    begin
      AFileName := LFullPath;
      Result := True;
    end;
  end;
end;

function THTTPServerDemoForm.GetMIMEType(const AFileName: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(ExtractFileExt(AFileName));

  // Common MIME types
  if LExt = '.html' then
    Result := 'text/html'
  else if LExt = '.htm' then
    Result := 'text/html'
  else if LExt = '.css' then
    Result := 'text/css'
  else if LExt = '.js' then
    Result := 'application/javascript'
  else if LExt = '.json' then
    Result := 'application/json'
  else if LExt = '.xml' then
    Result := 'text/xml'
  else if LExt = '.txt' then
    Result := 'text/plain'

    // Images
  else if LExt = '.jpg' then
    Result := 'image/jpeg'
  else if LExt = '.jpeg' then
    Result := 'image/jpeg'
  else if LExt = '.png' then
    Result := 'image/png'
  else if LExt = '.gif' then
    Result := 'image/gif'
  else if LExt = '.svg' then
    Result := 'image/svg+xml'
  else if LExt = '.ico' then
    Result := 'image/x-icon'
  else if LExt = '.webp' then
    Result := 'image/webp'

    // Fonts
  else if LExt = '.woff' then
    Result := 'font/woff'
  else if LExt = '.woff2' then
    Result := 'font/woff2'
  else if LExt = '.ttf' then
    Result := 'font/ttf'
  else if LExt = '.otf' then
    Result := 'font/otf'

    // Documents
  else if LExt = '.pdf' then
    Result := 'application/pdf'
  else if LExt = '.zip' then
    Result := 'application/zip'

    // Default
  else
    Result := 'application/octet-stream';
end;

procedure THTTPServerDemoForm.HandleStaticFileRequest
  (ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LPath: string;
  LFilePath: string;
  LHTMLFolder: string;
  LFileName: string;
  LContentType: string;
  LFileStream: TFileStream;
begin
  try
    // Define HTML subfolder path
    LHTMLFolder := IncludeTrailingPathDelimiter(FHTMLFolder);

    LPath := ARequestInfo.Document;
    LFilePath := LPath;
    if LFilePath.StartsWith('/') then
      LFilePath := LFilePath.Substring(1);

    if GetRequestedFileName(LFilePath, LHTMLFolder, LFileName) then
    begin
      LFileStream := nil;
      try
        LContentType := GetMIMEType(LFileName);
        LFileStream := TFileStream.Create(LFileName,
          fmOpenRead + fmShareDenyWrite);
        AResponseInfo.ContentType := LContentType;
        AResponseInfo.ContentStream := LFileStream;
        AResponseInfo.ResponseNo := 200;
        AResponseInfo.ContentLength := LFileStream.Size;
        OnLogEvent(Self, 'Served file: ' + LPath + ' (' + LContentType + ')');
        LFileStream := nil; // Prevent double-free, Indy now owns it
      except
        on E: Exception do
        begin
          FreeAndNil(LFileStream); // Free on exception
          AResponseInfo.ResponseNo := 500;
          AResponseInfo.ResponseText := E.Message;
          AResponseInfo.ContentType := 'text/plain';
          AResponseInfo.ContentText := 'Error loading file: ' + E.Message;
          OnLogEvent(Self, 'Error serving file ' + LPath + ': ' + E.Message +
            ' (FileName: ' + LFileName + ')');
        end;
      end;
    end
    else
    begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ResponseText := 'File Not Found';
      AResponseInfo.ContentType := 'text/plain';
      AResponseInfo.ContentText := 'File not found: ' + LPath;
      OnLogEvent(Self,
        Format('File not found: %s (checked in html subfolder %s)',
        [LPath, LHTMLFolder]));
    end;

  except
    on E: Exception do
    begin
      OnLogEvent(Self, 'Error serving static file: ' + E.Message);
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ResponseText := 'Internal Server Error';
      AResponseInfo.ContentType := 'text/plain';
      AResponseInfo.ContentText := 'Error loading file: ' + E.Message;
    end;
  end;
end;

end.
