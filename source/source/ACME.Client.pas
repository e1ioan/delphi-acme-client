unit ACME.Client;

interface

uses
  System.Classes, System.SysUtils, System.JSON, System.Generics.Collections,
  System.NetEncoding, System.Hash, System.Math,
  IdHTTP, IdSSLOpenSSL, IdSSLOpenSSLHeaders, IdCustomHTTPServer,
  IdHTTPServer, IdContext, ACME.Types, OpenSSL3.Lib, OpenSSL3.Helper,
  OpenSSL3.Legacy;

type

  TAcmeClient = class(TAcmeObject)
  private
    FHttp: TIdHTTP;
    FDirectoryUrl: string;
    FDirectory: TAcmeDirectory;
    FNonce: string;
    FAccountKid: string;
    FPrivateKey: pEVP_PKEY;
    FOnWriteChallenge: TWriteChallengeEvent;
    FHttpServer: TIdHTTPServer;
    FChallengeData: TDictionary<string, string>;
    FServerPort: Integer;
    FServerStarted: Boolean;
    function Base64UrlEncodeBytes(const AData: TBytes): string;
    function Base64UrlEncodeString(const AValue: string): string;
    function BuildJwkFromPublicKey(out AJwkJsonCanonical: string): Boolean;
    function GetJwkThumbprint: string;
    function EnsureNonce: string;
    procedure HttpHead(const AUrl: string);
    function HttpGetJson(const AUrl: string): TJSONObject;
    procedure UpdateNonceFromHeaders;
    function SignRS256(const AData: TBytes): TBytes;
    function ExtractModExpFromPrint(out ANBytes: TBytes;
      out AEBytes: TBytes): Boolean;
    function ExtractModExpFromSpki(out ANBytes: TBytes;
      out AEBytes: TBytes): Boolean;
    function HexToBytes(const AHex: string): TBytes;
    procedure OnHttpServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    function FinalizeOrder(const AFinalizeUrl: string; const ACsrDer: TBytes)
      : TJSONObject;
  public
    constructor Create(AOnLog: TOnLog = nil);
    destructor Destroy; override;

    procedure Initialize(const ADirectoryUrl: string);
    procedure GenerateRsaKeyPair2048;
    procedure LoadPrivateKeyFromPem(const AFileName: string);
    procedure SavePrivateKeyToPem(const AFileName: string);

    procedure CreateOrLoadAccount(const AEmail: string;
      const ATosAgreed: Boolean);
    function NewOrder(const ADomains: TArray<string>): TJSONObject;
    function GetAuthorization(const AAuthUrl: string): TJSONObject;
    function TriggerHttp01AndValidate(const AAuthUrl: string;
      const APollTimeoutMs: Integer = 120000;
      const APollIntervalMs: Integer = 2000): Boolean;
    function TriggerDns01AndValidate(const AAuthUrl: string;
      const APollTimeoutMs: Integer = 300000;
      const APollIntervalMs: Integer = 10000): Boolean;
    function GetDns01ChallengeDetails(const AAuthUrl: string;
      out AToken: string; out AKeyAuth: string; out ARecordName: string;
      out ARecordValue: string): Boolean;
    function PostAsJws(const AUrl: string; const APayload: TJSONObject;
      const AUseKid: Boolean): string;
    function GetResponseHeader(const AHeaderName: string): string;
    function DownloadCertificateChainPem(const ACerUrl: string): string;
    function FinalizeAndDownloadWithCsr(const AFinalizeUrl: string;
      const ACsrDer: TBytes; out ACertificateUrl: string;
      const APollTimeoutMs: Integer = 180000;
      const APollIntervalMs: Integer = 2000): string;

    // HTTP Server for HTTP-01 challenges
    procedure StartHttpServer(const APort: Integer = 80);
    procedure StopHttpServer;
    function IsHttpServerRunning: Boolean;

    // State management
    function ValidateAccount: Boolean;
    function IsOpenSSLLoaded: Boolean;

    property OnWriteChallenge: TWriteChallengeEvent read FOnWriteChallenge
      write FOnWriteChallenge;
    property AccountKid: string read FAccountKid write FAccountKid;
    property DirectoryUrl: string read FDirectoryUrl write FDirectoryUrl;
  end;

implementation

{ TAcmeClient }

constructor TAcmeClient.Create(AOnLog: TOnLog = nil);
var
  LSSL: TIdSSLIOHandlerSocketOpenSSL;
begin
  inherited Create;

  OnLog := AOnLog;

  IsOpenSSLLoaded;

  FHttp := TIdHTTP.Create(nil);
  FHttp.Request.UserAgent := 'Delphi-ACME-Client/1.0';
  LSSL := TIdSSLIOHandlerSocketOpenSSL.Create(FHttp);
  LSSL.SSLOptions.Method := sslvTLSv1_2;
  LSSL.SSLOptions.SSLVersions := [sslvTLSv1_2];
  LSSL.SSLOptions.Mode := sslmUnassigned;
  FHttp.IOHandler := LSSL;
  FPrivateKey := nil;

  // Initialize HTTP server components
  FHttpServer := TIdHTTPServer.Create(nil);
  FHttpServer.OnCommandGet := OnHttpServerCommandGet;
  FChallengeData := TDictionary<string, string>.Create;
  FServerPort := 80;
  FServerStarted := False;
end;

destructor TAcmeClient.Destroy;
begin
  StopHttpServer;
  FChallengeData.Free;
  FHttpServer.Free;
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  FHttp.Free;
  inherited;
end;

procedure TAcmeClient.Initialize(const ADirectoryUrl: string);
var
  LDirJson: TJSONObject;
  LMeta: TJSONValue;
begin
  FDirectoryUrl := ADirectoryUrl;
  LDirJson := HttpGetJson(FDirectoryUrl);
  try
    FDirectory.NewNonce := LDirJson.GetValue<string>('newNonce');
    FDirectory.NewAccount := LDirJson.GetValue<string>('newAccount');
    FDirectory.NewOrder := LDirJson.GetValue<string>('newOrder');
    LMeta := LDirJson.GetValue('revokeCert');
    if Assigned(LMeta) then
      FDirectory.RevokeCert := LMeta.Value;
    LMeta := LDirJson.GetValue('keyChange');
    if Assigned(LMeta) then
      FDirectory.KeyChange := LMeta.Value;
  finally
    LDirJson.Free;
  end;
  EnsureNonce;
end;

procedure TAcmeClient.GenerateRsaKeyPair2048;
begin
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  FPrivateKey := TOpenSSLHelper.GenerateRSAKey(2048);
end;

procedure TAcmeClient.LoadPrivateKeyFromPem(const AFileName: string);
begin
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  FPrivateKey := TOpenSSLHelper.LoadPrivateKey(AFileName);
end;

procedure TAcmeClient.SavePrivateKeyToPem(const AFileName: string);
begin
  TOpenSSLHelper.SavePrivateKey(FPrivateKey, AFileName);
end;

function TAcmeClient.Base64UrlEncodeBytes(const AData: TBytes): string;
var
  LBase64: string;
begin
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(AData);
  LBase64 := StringReplace(LBase64, #13, '', [rfReplaceAll]);
  LBase64 := StringReplace(LBase64, #10, '', [rfReplaceAll]);
  LBase64 := LBase64.Replace('+', '-').Replace('/', '_');
  while LBase64.EndsWith('=') do
    Delete(LBase64, Length(LBase64), 1);
  Result := LBase64;
end;

function TAcmeClient.Base64UrlEncodeString(const AValue: string): string;
var
  LBytes: TBytes;
  LCleanValue: string;
  LChar: Char;
  LCleanStr: string;
  LCharBytes: TBytes;
begin
  // Clean the value to ensure it's safe for UTF8 encoding
  LCleanValue := StringReplace(AValue, #0, '', [rfReplaceAll]);
  // Remove null chars
  LCleanValue := StringReplace(LCleanValue, #13, '', [rfReplaceAll]);
  // Remove CR
  LCleanValue := StringReplace(LCleanValue, #10, '', [rfReplaceAll]);
  // Remove LF
  LCleanValue := StringReplace(LCleanValue, #9, '', [rfReplaceAll]);
  // Remove TAB

  // Check for problematic characters and remove them
  for LChar in LCleanValue do
  begin
    if Ord(LChar) > 127 then // Non-ASCII character
    begin
      LCleanValue := StringReplace(LCleanValue, LChar, '', [rfReplaceAll]);
    end;
  end;

  // Convert to UTF8 with error handling
  try
    LBytes := TEncoding.UTF8.GetBytes(LCleanValue);
  except
    on E: EEncodingError do
    begin
      // Fallback: convert character by character, skipping problematic ones
      LCleanStr := '';
      for LChar in LCleanValue do
      begin
        try
          LCharBytes := TEncoding.UTF8.GetBytes(LChar);
          LCleanStr := LCleanStr + LChar;
        except
          // Skip problematic characters
        end;
      end;
      LBytes := TEncoding.UTF8.GetBytes(LCleanStr);
    end;
  end;

  Result := Base64UrlEncodeBytes(LBytes);
end;

function TAcmeClient.HexToBytes(const AHex: string): TBytes;
var
  LI: Integer;
  LHex: string;
begin
  LHex := StringReplace(AHex, ' ', '', [rfReplaceAll]);
  LHex := StringReplace(LHex, '-', '', [rfReplaceAll]);
  LHex := StringReplace(LHex, ':', '', [rfReplaceAll]);

  if Odd(Length(LHex)) then
    LHex := '0' + LHex;

  SetLength(Result, Length(LHex) div 2);
  for LI := 0 to Length(Result) - 1 do
  begin
    Result[LI] := Byte(StrToInt('$' + Copy(LHex, LI * 2 + 1, 2)));
  end;
end;

function TAcmeClient.ExtractModExpFromPrint(out ANBytes: TBytes;
  out AEBytes: TBytes): Boolean;
var
  LPrint: string;
  LLines: TArray<string>;
  LI: Integer;
  LIdx: Integer;
  LModHex: string;
  LExpDec: string;
  LPos: Integer;
  LHexLine: string;
  LCleanHex: string;
  LValue: UInt64;
  LLineTrim, LLineLower: string;
  function IsHexBytesLine(const ALine: string): Boolean;
  var
    S: string;
    J: Integer;
    HasColon, HasHex: Boolean;
  begin
    S := Trim(ALine);
    if S = '' then
      Exit(False);
    HasColon := Pos(':', S) > 0;
    HasHex := False;
    for J := 1 to Length(S) do
    begin
      case S[J] of
        '0' .. '9', 'a' .. 'f', 'A' .. 'F', ':':
          if S[J] <> ':' then
            HasHex := True;
      else
        Exit(False);
      end;
    end;
    Result := HasColon and HasHex;
  end;

begin
  SetLength(ANBytes, 0);
  SetLength(AEBytes, 0);
  if FPrivateKey <> nil then
    LPrint := TOpenSSLHelper.GetKeyPrint(FPrivateKey)
  else
    Exit(False);
  // Normalize line endings to LF for robust splitting
  LPrint := StringReplace(LPrint, #13#10, #10, [rfReplaceAll]);
  LPrint := StringReplace(LPrint, #13, #10, [rfReplaceAll]);
  LLines := LPrint.Split([#10]);
  LModHex := '';
  LExpDec := '';
  for LI := 0 to Length(LLines) - 1 do
  begin
    LLineTrim := LLines[LI].Trim;
    LLineLower := LowerCase(LLineTrim);
    if LExpDec = '' then
    begin
      if (Pos('publicexponent:', LLineLower) = 1) or
        (Pos('exponent:', LLineLower) = 1) then
      begin
        LPos := Pos(':', LLineTrim);
        if LPos > 0 then
          LExpDec := Trim(Copy(LLineTrim, LPos + 1, MaxInt));
        LPos := Pos(' ', LExpDec);
        if LPos > 0 then
          LExpDec := Copy(LExpDec, 1, LPos - 1);
      end;
    end;
    if (LModHex = '') and (Pos('modulus:', LLineLower) = 1) then
    begin
      LIdx := LI + 1;
      while (LIdx < Length(LLines)) and IsHexBytesLine(LLines[LIdx]) do
      begin
        LHexLine := Trim(LLines[LIdx]);
        LHexLine := StringReplace(LHexLine, ':', '', [rfReplaceAll]);
        LHexLine := StringReplace(LHexLine, ' ', '', [rfReplaceAll]);
        LModHex := LModHex + LHexLine;
        Inc(LIdx);
      end;
      // do not modify loop variable LI
    end;
  end;
  if (LModHex = '') or (LExpDec = '') then
    Exit(False);

  // Remove any non-hex characters defensively
  LCleanHex := '';
  for LI := 1 to Length(LModHex) do
    if CharInSet(LModHex[LI], ['0' .. '9', 'a' .. 'f', 'A' .. 'F']) then
      LCleanHex := LCleanHex + LModHex[LI];
  if Odd(Length(LCleanHex)) then
    LCleanHex := '0' + LCleanHex;
  SetLength(ANBytes, Length(LCleanHex) div 2);
  for LIdx := 0 to (Length(LCleanHex) div 2) - 1 do
    ANBytes[LIdx] := Byte(StrToInt('$' + Copy(LCleanHex, LIdx * 2 + 1, 2)));
  // Trim leading 0x00 padding if present (OpenSSL print often prefixes for positive integers)
  while (Length(ANBytes) > 0) and (ANBytes[0] = $00) do
    ANBytes := Copy(ANBytes, 2 - 1, Length(ANBytes) - 1);

  // Extract decimal number before optional space and hex in parentheses
  LPos := Pos(' ', LExpDec);
  if LPos > 0 then
    LExpDec := Copy(LExpDec, 1, LPos - 1);
  if not TryStrToUInt64(LExpDec, LValue) then
    Exit(False);

  if LValue <= $FF then
  begin
    SetLength(AEBytes, 1);
    AEBytes[0] := Byte(LValue);
  end
  else if LValue <= $FFFF then
  begin
    SetLength(AEBytes, 2);
    AEBytes[0] := Byte((LValue shr 8) and $FF);
    AEBytes[1] := Byte(LValue and $FF);
  end
  else
  begin
    SetLength(AEBytes, 3);
    AEBytes[0] := Byte((LValue shr 16) and $FF);
    AEBytes[1] := Byte((LValue shr 8) and $FF);
    AEBytes[2] := Byte(LValue and $FF);
  end;

  Result := (Length(ANBytes) > 0) and (Length(AEBytes) > 0);
end;

function TAcmeClient.GetJwkThumbprint: string;
var
  LJwk: string;
  LDigest: TBytes;
begin
  if not BuildJwkFromPublicKey(LJwk) then
    raise EAcmeError.Create('Unable to build JWK');
  LDigest := THashSHA2.GetHashBytes(LJwk);
  Result := Base64UrlEncodeBytes(LDigest);
end;

function TAcmeClient.EnsureNonce: string;
begin
  if FNonce <> '' then
  begin
    Result := FNonce;
    Exit;
  end;
  HttpHead(FDirectory.NewNonce);
  UpdateNonceFromHeaders;
  Result := FNonce;
end;

procedure TAcmeClient.HttpHead(const AUrl: string);
begin
  FHttp.Head(AUrl);
end;

function TAcmeClient.HttpGetJson(const AUrl: string): TJSONObject;
var
  LText: string;
begin
  LText := FHttp.Get(AUrl);
  Result := TJSONObject.ParseJSONValue(LText) as TJSONObject;
  if not Assigned(Result) then
    raise EAcmeError.Create('Invalid JSON response');
end;

function TAcmeClient.GetResponseHeader(const AHeaderName: string): string;
begin
  Result := FHttp.Response.RawHeaders.Values[AHeaderName];
end;

procedure TAcmeClient.UpdateNonceFromHeaders;
var
  LVal: string;
begin
  LVal := GetResponseHeader('Replay-Nonce');
  if LVal <> '' then
    FNonce := LVal;
end;

function TAcmeClient.SignRS256(const AData: TBytes): TBytes;
begin
  if FPrivateKey = nil then
    raise EAcmeError.Create('Private key not loaded');
  Result := TOpenSSLHelper.SignData(FPrivateKey, AData);
end;

function TAcmeClient.PostAsJws(const AUrl: string; const APayload: TJSONObject;
  const AUseKid: Boolean): string;
var
  LProtected, LPayload, LSignature: string;
  LProtectedObj: TJSONObject;
  LBodyObj: TJSONObject;
  LToSign: TBytes;
  LSig: TBytes;
  LReq: TStringStream;
  LJwk: string;
  LCleanStr: string;
  LCombinedStr: string;
  LChar: Char;
  LCharBytes: TBytes;
begin
  EnsureNonce;

  LProtectedObj := TJSONObject.Create;
  try
    LProtectedObj.AddPair('alg', 'RS256');
    LProtectedObj.AddPair('nonce', FNonce);
    LProtectedObj.AddPair('url', AUrl);
    if AUseKid then
      LProtectedObj.AddPair('kid', FAccountKid)
    else
    begin
      if not BuildJwkFromPublicKey(LJwk) then
        raise EAcmeError.Create('Unable to build JWK');
      LProtectedObj.AddPair('jwk', TJSONObject.ParseJSONValue(LJwk)
        as TJSONObject);
    end;
    LProtected := Base64UrlEncodeString(LProtectedObj.ToJSON);
  finally
    LProtectedObj.Free;
  end;

  if Assigned(APayload) then
    LPayload := Base64UrlEncodeString(APayload.ToJSON)
  else
    LPayload := '';

  // Convert to UTF8 with error handling
  try
    LToSign := TEncoding.UTF8.GetBytes(LProtected + '.' + LPayload);
  except
    on E: EEncodingError do
    begin
      // Fallback: convert character by character, skipping problematic ones
      LCleanStr := '';
      LCombinedStr := LProtected + '.' + LPayload;
      for LChar in LCombinedStr do
      begin
        try
          LCharBytes := TEncoding.UTF8.GetBytes(LChar);
          LCleanStr := LCleanStr + LChar;
        except
          // Skip problematic characters
        end;
      end;
      LToSign := TEncoding.UTF8.GetBytes(LCleanStr);
    end;
  end;
  LSig := SignRS256(LToSign);
  LSignature := Base64UrlEncodeBytes(LSig);

  LBodyObj := TJSONObject.Create;
  try
    LBodyObj.AddPair('protected', LProtected);
    LBodyObj.AddPair('payload', LPayload);
    LBodyObj.AddPair('signature', LSignature);
    LReq := TStringStream.Create(LBodyObj.ToJSON, TEncoding.UTF8);
    try
      FHttp.Request.ContentType := 'application/jose+json';
      FHttp.Request.Accept := 'application/json';
      try
        Result := FHttp.Post(AUrl, LReq);
      except
        on E: EIdHTTPProtocolException do
        begin
          UpdateNonceFromHeaders;
          if Pos('badNonce', LowerCase(E.ErrorMessage)) > 0 then
          begin
            EnsureNonce;
            Result := FHttp.Post(AUrl, LReq);
          end
          else
            raise EAcmeError.CreateFmt('ACME error %d: %s',
              [E.ErrorCode, E.ErrorMessage]);
        end;
      end;
      UpdateNonceFromHeaders;
    finally
      LReq.Free;
    end;
  finally
    LBodyObj.Free;
  end;
end;

procedure TAcmeClient.CreateOrLoadAccount(const AEmail: string;
  const ATosAgreed: Boolean);
var
  LPayload: TJSONObject;
  LText: string;
  LLoc: string;
begin
  Debug('Creating or loading account for: ' + AEmail);
  LPayload := TJSONObject.Create;
  try
    LPayload.AddPair('termsOfServiceAgreed', TJSONBool.Create(ATosAgreed));
    if AEmail <> '' then
      LPayload.AddPair('contact',
        TJSONArray.Create(TJSONString.Create('mailto:' + AEmail)));
    LText := PostAsJws(FDirectory.NewAccount, LPayload, False);
  finally
    LPayload.Free;
  end;
  LLoc := GetResponseHeader('Location');
  if LLoc = '' then
    raise EAcmeError.Create('Account Location (kid) not provided');
  FAccountKid := LLoc;
  Log('Account created/loaded successfully. KID: ' + FAccountKid);
end;

function TAcmeClient.NewOrder(const ADomains: TArray<string>): TJSONObject;
var
  LIdentifiers: TJSONArray;
  LI: Integer;
  LObj: TJSONObject;
  LText: string;
  LDomainList: string;
begin
  LDomainList := string.Join(', ', ADomains);
  Log('Creating new order for domains: ' + LDomainList);

  LObj := nil;
  LIdentifiers := TJSONArray.Create;
  try
    for LI := 0 to Length(ADomains) - 1 do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('type', 'dns');
      LObj.AddPair('value', ADomains[LI]);
      LIdentifiers.AddElement(LObj);
    end;
    LObj := TJSONObject.Create;
    LObj.AddPair('identifiers', LIdentifiers);
    LText := PostAsJws(FDirectory.NewOrder, LObj, True);
  finally
    LObj.Free;
  end;
  Result := TJSONObject.ParseJSONValue(LText) as TJSONObject;
  Log('Order created successfully');
end;

function TAcmeClient.GetAuthorization(const AAuthUrl: string): TJSONObject;
var
  LText: string;
begin
  LText := PostAsJws(AAuthUrl, nil, True);
  Result := TJSONObject.ParseJSONValue(LText) as TJSONObject;
end;

function TAcmeClient.TriggerHttp01AndValidate(const AAuthUrl: string;
  const APollTimeoutMs, APollIntervalMs: Integer): Boolean;
var
  LAuth: TJSONObject;
  LChallenges: TJSONArray;
  LChObj: TJSONObject;
  LType, LToken, LUrl: string;
  LI: Integer;
  LPayload: TJSONObject;
  LStart, LNow: Cardinal;
  LStatus: string;
  LKeyAuth: string;
  LPath: string;
begin
  Result := False;
  Log('Starting HTTP-01 challenge validation');

  LAuth := GetAuthorization(AAuthUrl);
  try
    LChallenges := LAuth.GetValue<TJSONArray>('challenges');
    if not Assigned(LChallenges) then
      raise EAcmeError.Create('No challenges');
    LChObj := nil;
    for LI := 0 to LChallenges.Count - 1 do
    begin
      LType := (LChallenges.Items[LI] as TJSONObject).GetValue<string>('type');
      if SameText(LType, 'http-01') then
      begin
        LChObj := (LChallenges.Items[LI] as TJSONObject);
        Break;
      end;
    end;
    if not Assigned(LChObj) then
      raise EAcmeError.Create('http-01 challenge not available');
    LToken := LChObj.GetValue<string>('token');
    LUrl := LChObj.GetValue<string>('url');

    LKeyAuth := LToken + '.' + GetJwkThumbprint;

    // Store challenge data for HTTP server
    FChallengeData.AddOrSetValue(LToken, LKeyAuth);

    // If HTTP server is running, use it; otherwise fall back to file-based approach
    if IsHttpServerRunning then
    begin
      Log('HTTP-01 challenge available at: http://localhost:' +
        IntToStr(FServerPort) + '/.well-known/acme-challenge/' + LToken);
    end
    else if Assigned(FOnWriteChallenge) then
    begin
      Debug('Calling OnWriteChallenge handler');
      FOnWriteChallenge(LToken, LKeyAuth, LPath);
    end
    else
    begin
      Log('WARNING: No HTTP server running and no OnWriteChallenge handler set');
      Debug('Challenge token: ' + LToken);
      Debug('Challenge response: ' + LKeyAuth);
    end;

    Log('Triggering HTTP-01 challenge');
    LPayload := TJSONObject.Create;
    try
      PostAsJws(LUrl, LPayload, True);
    finally
      LPayload.Free;
    end;

    Debug('Polling for challenge validation');
    LStart := TThread.GetTickCount;
    repeat
      Sleep(APollIntervalMs);
      LAuth.Free;
      LAuth := GetAuthorization(AAuthUrl);
      LStatus := LAuth.GetValue<string>('status');
      Debug('Challenge status: ' + LStatus);
      if SameText(LStatus, 'valid') then
      begin
        Log('HTTP-01 challenge validated successfully');
        Result := True;
        Exit;
      end;
      if SameText(LStatus, 'invalid') then
        raise EAcmeError.Create('Challenge invalid');
      LNow := TThread.GetTickCount;
    until (LNow - LStart) >= Cardinal(APollTimeoutMs);

    Log('HTTP-01 challenge validation timeout');

  finally
    LAuth.Free;
  end;
end;

function TAcmeClient.FinalizeOrder(const AFinalizeUrl: string;
  const ACsrDer: TBytes): TJSONObject;
var
  LPayload: TJSONObject;
  LCsrB64: string;
  LText: string;
begin

  LCsrB64 := Base64UrlEncodeBytes(ACsrDer);

  LPayload := TJSONObject.Create;
  try
    LPayload.AddPair('csr', LCsrB64);
    LText := PostAsJws(AFinalizeUrl, LPayload, True);
  finally
    LPayload.Free;
  end;
  Result := TJSONObject.ParseJSONValue(LText) as TJSONObject;
end;

function TAcmeClient.DownloadCertificateChainPem(const ACerUrl: string): string;
begin
  Result := PostAsJws(ACerUrl, nil, True);
end;

function TAcmeClient.FinalizeAndDownloadWithCsr(const AFinalizeUrl: string;
  const ACsrDer: TBytes; out ACertificateUrl: string;
  const APollTimeoutMs: Integer = 180000;
  const APollIntervalMs: Integer = 2000): string;
var
  LOrder: TJSONObject;
  LStart, LNow: Cardinal;
  LStatus: string;
  LCertUrl: string;
  LOrderUrl: string;
begin
  Result := '';
  ACertificateUrl := '';

  Debug('Starting finalize and download process');

  // Extract order URL from finalize URL
  LOrderUrl := StringReplace(AFinalizeUrl, '/finalize/', '/order/', []);

  // First, check the current order status using the order URL
  Debug('Checking order status');
  LOrder := TJSONObject.ParseJSONValue(PostAsJws(LOrderUrl, nil, True))
    as TJSONObject;
  try
    LStatus := LOrder.GetValue<string>('status');
    Debug('Order status: ' + LStatus);
    if SameText(LStatus, 'valid') then
    begin
      // Order is already valid, just download the certificate
      Log('Order already valid, downloading certificate');
      LCertUrl := LOrder.GetValue<string>('certificate');
      if LCertUrl = '' then
        raise EAcmeError.Create('Order valid but certificate URL missing');
      ACertificateUrl := LCertUrl;
      Result := DownloadCertificateChainPem(LCertUrl);
      Exit;
    end
    else if SameText(LStatus, 'ready') then
    begin
      // Order is ready for finalization
      Log('Order ready for finalization');
      LOrder.Free;
      LOrder := FinalizeOrder(AFinalizeUrl, ACsrDer);
    end
    else
    begin
      raise EAcmeError.Create('Order is not ready for finalization. Status: '
        + LStatus);
    end;

    // Poll for completion
    Debug('Polling for order completion');
    LStart := TThread.GetTickCount;
    repeat
      Sleep(APollIntervalMs);
      LOrder.Free;
      LOrder := TJSONObject.ParseJSONValue(PostAsJws(LOrderUrl, nil, True))
        as TJSONObject;
      try
        LStatus := LOrder.GetValue<string>('status');
        Debug('Polling status: ' + LStatus);

        if SameText(LStatus, 'valid') then
        begin
          Log('Order finalized successfully');
          LCertUrl := LOrder.GetValue<string>('certificate');
          if LCertUrl = '' then
            raise EAcmeError.Create('Order valid but certificate URL missing');
          ACertificateUrl := LCertUrl;
          Result := DownloadCertificateChainPem(LCertUrl);
          LOrder.Free; // Free before exit
          LOrder := nil; // Prevent double-free
          Exit;
        end;
        if SameText(LStatus, 'invalid') then
          raise EAcmeError.Create('Order became invalid during finalize');
        LNow := TThread.GetTickCount;
      except
        LOrder.Free;
        raise;
      end;
    until (LNow - LStart) >= Cardinal(APollTimeoutMs);
    Log('Timeout waiting for order to finalize');
    raise EAcmeError.Create('Timeout waiting for order to finalize');
  finally
    if LOrder <> nil then
      LOrder.Free;
  end;
end;

function TAcmeClient.BuildJwkFromPublicKey(out AJwkJsonCanonical
  : string): Boolean;
var
  LN, LE: TBytes;
  Lkty, LnB64, LeB64: string;
begin
  Result := ExtractModExpFromSpki(LN, LE);
  if not Result then
    Result := ExtractModExpFromPrint(LN, LE);
  if not Result then
    Exit(False);
  Lkty := 'RSA';
  LnB64 := Base64UrlEncodeBytes(LN);
  LeB64 := Base64UrlEncodeBytes(LE);
  // Canonical key order per RFC 7638: e, kty, n, without extra spaces
  AJwkJsonCanonical := '{' + '"e":"' + LeB64 + '","kty":"' + Lkty + '","n":"' +
    LnB64 + '"}';
end;

function TAcmeClient.ExtractModExpFromSpki(out ANBytes: TBytes;
  out AEBytes: TBytes): Boolean;
begin
  SetLength(ANBytes, 0);
  SetLength(AEBytes, 0);
  if FPrivateKey = nil then
    Exit(False);

  try
    ANBytes := TOpenSSLHelper.GetPublicKeyModulus(FPrivateKey);
    AEBytes := TOpenSSLHelper.GetPublicKeyExponent(FPrivateKey);
    Result := (Length(ANBytes) > 0) and (Length(AEBytes) > 0);
  except
    Result := False;
  end;
end;

// DNS-01 Challenge Methods

function TAcmeClient.GetDns01ChallengeDetails(const AAuthUrl: string;
  out AToken: string; out AKeyAuth: string; out ARecordName: string;
  out ARecordValue: string): Boolean;
var
  LAuth: TJSONObject;
  LChallenges: TJSONArray;
  LChObj: TJSONObject;
  LType: string;
  LI: Integer;
  LDomain: string;
  LKeyAuthBytes: TBytes;
  LKeyAuthHash: string;
  LIdentifier: TJSONValue;
  LHashBytes: TBytes;
begin
  AToken := '';
  AKeyAuth := '';
  ARecordName := '';
  ARecordValue := '';

  LAuth := GetAuthorization(AAuthUrl);
  try
    LChallenges := LAuth.GetValue<TJSONArray>('challenges');
    if not Assigned(LChallenges) then
      raise EAcmeError.Create('No challenges');

    // Find DNS-01 challenge
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

    if not Assigned(LChObj) then
      raise EAcmeError.Create('dns-01 challenge not available');

    AToken := LChObj.GetValue<string>('token');
    AKeyAuth := AToken + '.' + GetJwkThumbprint;

    // Get domain from authorization
    LIdentifier := LAuth.GetValue('identifier');
    if Assigned(LIdentifier) and (LIdentifier is TJSONObject) then
      LDomain := (LIdentifier as TJSONObject).GetValue<string>('value')
    else
      raise EAcmeError.Create('No domain identifier found');

    // Calculate DNS record name and value
    ARecordName := '_acme-challenge.' + LDomain;

    // Calculate SHA256 hash of key authorization
    LKeyAuthBytes := TEncoding.UTF8.GetBytes(AKeyAuth);
    LKeyAuthHash := THashSHA2.GetHashString(AKeyAuth);
    // Convert hex string to bytes, then to base64url
    LHashBytes := HexToBytes(LKeyAuthHash);
    ARecordValue := Base64UrlEncodeBytes(LHashBytes);

    Result := True;
  finally
    LAuth.Free;
  end;
end;

function TAcmeClient.TriggerDns01AndValidate(const AAuthUrl: string;
  const APollTimeoutMs: Integer = 300000;
  const APollIntervalMs: Integer = 10000): Boolean;
var
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
begin
  Result := False;

  // Get challenge details
  if not GetDns01ChallengeDetails(AAuthUrl, LToken, LKeyAuth, LRecordName,
    LRecordValue) then
    Exit;

  Log('DNS-01 Challenge Details:');
  Log('Record Name: ' + LRecordName);
  Log('Record Type: TXT');
  Log('Record Value: ' + LRecordValue);
  Log('Please create this DNS record and press ENTER when ready...');

  // Find the challenge URL
  LAuth := GetAuthorization(AAuthUrl);
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

    if not Assigned(LChObj) then
      raise EAcmeError.Create('dns-01 challenge not available');

    LUrl := LChObj.GetValue<string>('url');
  finally
    LAuth.Free;
  end;

  // Trigger the challenge
  LPayload := TJSONObject.Create;
  try
    PostAsJws(LUrl, LPayload, True);
  finally
    LPayload.Free;
  end;

  // Poll for validation
  LStart := TThread.GetTickCount;
  repeat
    Sleep(APollIntervalMs);
    LAuth := GetAuthorization(AAuthUrl);
    try
      LStatus := LAuth.GetValue<string>('status');
      if SameText(LStatus, 'valid') then
      begin
        Result := True;
        Exit;
      end;
      if SameText(LStatus, 'invalid') then
        raise EAcmeError.Create('DNS-01 challenge invalid');
      LNow := TThread.GetTickCount;
    finally
      LAuth.Free;
    end;
  until (LNow - LStart) >= Cardinal(APollTimeoutMs);
end;

// HTTP Server Methods

procedure TAcmeClient.StartHttpServer(const APort: Integer = 80);
begin
  if FServerStarted then
    Exit;

  FServerPort := APort;
  FHttpServer.DefaultPort := APort;
  FHttpServer.Active := True;
  FServerStarted := True;
  Log('HTTP server started on port ' + IntToStr(APort));
end;

procedure TAcmeClient.StopHttpServer;
begin
  if not FServerStarted then
    Exit;

  FHttpServer.Active := False;
  FServerStarted := False;
  FChallengeData.Clear;
  Log('HTTP server stopped');
end;

function TAcmeClient.IsHttpServerRunning: Boolean;
begin
  Result := FServerStarted and FHttpServer.Active;
end;

function TAcmeClient.IsOpenSSLLoaded: Boolean;
begin
  if not OpenSSL3.Lib.IsOpenSSLLoaded then
  begin
    Log('ERROR: OpenSSL library not loaded - attempting to load...');
    try
      if OpenSSL3.Lib.LoadOpenSSLLibraryEx then
      begin
        Log('OpenSSL loaded successfully');
        Log('OpenSSL version: ' + OpenSSL3.Lib.GetOpenSSLVersion);
      end
      else
      begin
        Log('ERROR: Failed to load OpenSSL library');
      end;
    except
      on E: Exception do
      begin
        Log('ERROR loading OpenSSL: ' + E.Message);
      end;
    end;
  end;
  Result := OpenSSL3.Lib.IsOpenSSLLoaded;
end;

procedure TAcmeClient.OnHttpServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LPath: string;
  LToken: string;
  LKeyAuth: string;
begin
  LPath := ARequestInfo.Document;

  // Check if this is an ACME challenge request
  if LPath.StartsWith('/.well-known/acme-challenge/') then
  begin
    LToken := Copy(LPath, Length('/.well-known/acme-challenge/') + 1, MaxInt);

    if FChallengeData.TryGetValue(LToken, LKeyAuth) then
    begin
      AResponseInfo.ContentText := LKeyAuth;
      AResponseInfo.ContentType := 'text/plain';
      AResponseInfo.ResponseNo := 200;
      Log('Served challenge for token: ' + LToken);
    end
    else
    begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentText := 'Challenge not found';
      Log('Challenge not found for token: ' + LToken);
    end;
  end
  else
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentText := 'Not found';
  end;
end;


// State Management Methods

function TAcmeClient.ValidateAccount: Boolean;
var
  LAccountJson: TJSONObject;
begin
  if FAccountKid = '' then
  begin
    Log('Account validation failed: KID is empty');
    Exit(False);
  end;

  try
    Debug('Validating account KID: ' + FAccountKid);
    // Try to query the account to see if it's still valid
    LAccountJson := TJSONObject.ParseJSONValue(PostAsJws(FAccountKid, nil, True)
      ) as TJSONObject;
    try
      // If we get here without an exception, the account is valid
      Log('Account validation successful');
      Result := True;
    finally
      LAccountJson.Free;
    end;
  except
    on E: EAcmeError do
    begin
      // Account might be invalid or expired
      Log('Account validation failed: ' + E.Message);
      Result := False;
    end;
    on E: Exception do
    begin
      Log('Account validation error: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
