unit OpenSSL3.Helper;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils,
  OpenSSL3.Lib;

type
  TOpenSSLHelper = class
  public
    class function GenerateRSAKey(ABits: Integer = 2048): pEVP_PKEY;
    class procedure SavePrivateKey(APkey: pEVP_PKEY; const AFilePath: string);
    class function LoadPrivateKey(const AFilePath: string): pEVP_PKEY;
    class procedure FreeKey(APkey: pEVP_PKEY);
    class function GetPublicKeyModulus(APkey: pEVP_PKEY): TBytes;
    class function GetPublicKeyExponent(APkey: pEVP_PKEY): TBytes;
    class function SignData(APkey: pEVP_PKEY; const AData: TBytes): TBytes;
    class function CreateCSR(APkey: pEVP_PKEY; const ACommonName: string;
      const ASanDomains: TArray<string> = nil): string;
    class function CreateCSRDer(APkey: pEVP_PKEY; const ACommonName: string;
      const ASanDomains: TArray<string> = nil): TBytes;
    class function CreateCSRDerWithSubject(APkey: pEVP_PKEY;
      const ACountry, AState, ALocality, AOrganization, AOrganizationalUnit,
      ACommonName, AEmailAddress: string;
      const ASanDomains: TArray<string> = nil): TBytes;
    class function GetRsaPublicKeyDer(APkey: pEVP_PKEY): TBytes;

    // Additional functions needed for ACME client
    class function SavePrivateKeyToStream(APkey: pEVP_PKEY): string;
    class function LoadPrivateKeyFromStream(const APemData: string): pEVP_PKEY;
    class function GetKeyPrint(APkey: pEVP_PKEY): string;
    class function IsKeyValid(APkey: pEVP_PKEY): Boolean;

    // X509 Certificate functions
    class function GetCertificateExpiryDate(const AFileName: string): TDateTime;
    class function VerifyCertificateAndKey(const ACertFile, AKeyFile: string;
      out AErrorMessage: string): Boolean;
    class function TryParseASN1TimeString(const ATimeStr: string;
      out AYear, AMonth, ADay, AHour, AMin, ASec: Word): Boolean;
  end;

implementation

uses
  System.IOUtils;

{ TOpenSSLHelper }

class function TOpenSSLHelper.GenerateRSAKey(ABits: Integer): pEVP_PKEY;
var
  LBignumExp: PBIGNUM;
  LRsaKey: pRSA;
  LPKey: pEVP_PKEY;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create
      ('OpenSSL library not loaded. Call LoadOpenSSLLibraryEx first.');

  LBignumExp := BN_new;
  try
    BN_set_word(LBignumExp, RSA_F4);
    LRsaKey := RSA_new;
    try
      if RSA_generate_key_ex(LRsaKey, ABits, LBignumExp, nil) <> 1 then
        raise Exception.Create('Failed to generate RSA key');

      LPKey := EVP_PKEY_new;
      if EVP_PKEY_set1_RSA(LPKey, LRsaKey) <> 1 then
      begin
        EVP_PKEY_free(LPKey);
        raise Exception.Create('Failed to assign RSA key to EVP_PKEY');
      end;

      Result := LPKey;
    finally
      RSA_free(LRsaKey);
    end;
  finally
    BN_free(LBignumExp);
  end;
end;

class procedure TOpenSSLHelper.SavePrivateKey(APkey: pEVP_PKEY;
  const AFilePath: string);
var
  LBio: pBIO;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LBio := BIO_new_file(PAnsiChar(AnsiString(AFilePath)), PAnsiChar('w'));
  if LBio = nil then
    raise Exception.Create('Failed to create file: ' + AFilePath);
  try
    if PEM_write_bio_PrivateKey(LBio, APkey, nil, nil, 0, nil, nil) <> 1 then
      raise Exception.Create('Failed to write private key');
  finally
    BIO_free(LBio);
  end;
end;

class function TOpenSSLHelper.LoadPrivateKey(const AFilePath: string)
  : pEVP_PKEY;
var
  LBio: pBIO;
  LPKey: pEVP_PKEY;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LBio := BIO_new_file(PAnsiChar(AnsiString(AFilePath)), PAnsiChar('r'));
  if LBio = nil then
    raise Exception.Create('Failed to open file: ' + AFilePath);
  try
    LPKey := PEM_read_bio_PrivateKey(LBio, nil, nil, nil);
    if LPKey = nil then
      raise Exception.Create('Failed to read private key');
    Result := LPKey;
  finally
    BIO_free(LBio);
  end;
end;

class procedure TOpenSSLHelper.FreeKey(APkey: pEVP_PKEY);
begin
  if APkey <> nil then
    EVP_PKEY_free(APkey);
end;

class function TOpenSSLHelper.GetPublicKeyModulus(APkey: pEVP_PKEY): TBytes;
var
  LPrint: string;
  LLines: TArray<string>;
  LI: Integer;
  LModHex: string;
  LHexLine: string;
  LCleanHex: string;
  LIdx: Integer;
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
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  // Use the key printing approach to extract modulus
  LPrint := GetKeyPrint(APkey);

  // Parse the printed output to extract modulus
  LPrint := StringReplace(LPrint, #13#10, #10, [rfReplaceAll]);
  LPrint := StringReplace(LPrint, #13, #10, [rfReplaceAll]);
  LLines := LPrint.Split([#10]);
  LModHex := '';

  for LI := 0 to Length(LLines) - 1 do
  begin
    if (LModHex = '') and (Pos('modulus:', LowerCase(LLines[LI])) = 1) then
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
      Break;
    end;
  end;

  if LModHex = '' then
    raise Exception.Create('Failed to extract modulus from key print');

  // Remove any non-hex characters defensively
  LCleanHex := '';
  for LI := 1 to Length(LModHex) do
    if CharInSet(LModHex[LI], ['0' .. '9', 'a' .. 'f', 'A' .. 'F']) then
      LCleanHex := LCleanHex + LModHex[LI];

  if Odd(Length(LCleanHex)) then
    LCleanHex := '0' + LCleanHex;

  SetLength(Result, Length(LCleanHex) div 2);
  for LIdx := 0 to (Length(LCleanHex) div 2) - 1 do
    Result[LIdx] := Byte(StrToInt('$' + Copy(LCleanHex, LIdx * 2 + 1, 2)));

  // Trim leading 0x00 padding if present
  while (Length(Result) > 0) and (Result[0] = $00) do
    Result := Copy(Result, 2 - 1, Length(Result) - 1);
end;

class function TOpenSSLHelper.GetPublicKeyExponent(APkey: pEVP_PKEY): TBytes;
var
  LPrint: string;
  LLines: TArray<string>;
  LI: Integer;
  LExpDec: string;
  LPos: Integer;
  LLineTrim, LLineLower: string;
  LValue: UInt64;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  // Use the key printing approach to extract exponent
  LPrint := GetKeyPrint(APkey);

  // Parse the printed output to extract exponent
  LPrint := StringReplace(LPrint, #13#10, #10, [rfReplaceAll]);
  LPrint := StringReplace(LPrint, #13, #10, [rfReplaceAll]);
  LLines := LPrint.Split([#10]);
  LExpDec := '';

  for LI := 0 to Length(LLines) - 1 do
  begin
    LLineTrim := LLines[LI].Trim;
    LLineLower := LowerCase(LLineTrim);
    if (Pos('publicexponent:', LLineLower) = 1) or
      (Pos('exponent:', LLineLower) = 1) then
    begin
      LPos := Pos(':', LLineTrim);
      if LPos > 0 then
        LExpDec := Trim(Copy(LLineTrim, LPos + 1, MaxInt));
      LPos := Pos(' ', LExpDec);
      if LPos > 0 then
        LExpDec := Copy(LExpDec, 1, LPos - 1);
      Break;
    end;
  end;

  if LExpDec = '' then
    raise Exception.Create('Failed to extract exponent from key print');

  if not TryStrToUInt64(LExpDec, LValue) then
    raise Exception.Create('Invalid exponent value: ' + LExpDec);

  // Convert to bytes
  if LValue <= $FF then
  begin
    SetLength(Result, 1);
    Result[0] := Byte(LValue);
  end
  else if LValue <= $FFFF then
  begin
    SetLength(Result, 2);
    Result[0] := Byte((LValue shr 8) and $FF);
    Result[1] := Byte(LValue and $FF);
  end
  else
  begin
    SetLength(Result, 3);
    Result[0] := Byte((LValue shr 16) and $FF);
    Result[1] := Byte((LValue shr 8) and $FF);
    Result[2] := Byte(LValue and $FF);
  end;
end;

class function TOpenSSLHelper.SignData(APkey: pEVP_PKEY;
  const AData: TBytes): TBytes;
var
  LCtx: pEVP_MD_CTX;
  LSignature: TBytes;
  LSignatureLen: NativeUInt;
  LMd: pEVP_MD;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  if APkey = nil then
    raise Exception.Create('Private key is nil');

  LMd := EVP_sha256;
  if LMd = nil then
    raise Exception.Create
      ('EVP_sha256 function not available - OpenSSL may not be fully initialized');

  LCtx := EVP_MD_CTX_new;
  if LCtx = nil then
    raise Exception.Create('Failed to create EVP_MD_CTX');

  try
    if EVP_DigestSignInit(LCtx, nil, LMd, nil, APkey) <> 1 then
      raise Exception.Create
        ('Failed to initialize signing - check if OpenSSL is properly initialized and key is valid');

    if EVP_DigestSignUpdate(LCtx, @AData[0], Length(AData)) <> 1 then
      raise Exception.Create('Failed to update signing');

    LSignatureLen := 0;
    if EVP_DigestSignFinal(LCtx, nil, LSignatureLen) <> 1 then
      raise Exception.Create('Failed to get signature length');

    SetLength(LSignature, LSignatureLen);
    if EVP_DigestSignFinal(LCtx, @LSignature[0], LSignatureLen) <> 1 then
      raise Exception.Create('Failed to finalize signing');

    SetLength(LSignature, LSignatureLen);
    Result := LSignature;
  finally
    EVP_MD_CTX_free(LCtx);
  end;
end;

class function TOpenSSLHelper.CreateCSR(APkey: pEVP_PKEY;
  const ACommonName: string; const ASanDomains: TArray<string>): string;
var
  LReq: pX509_REQ;
  LName: pX509_NAME;
  LExtStack: PSTACK;
  LSanExtension: pX509_EXTENSION;
  LSanValue: string;
  LDomain: string;
  LBio: pBIO;
  LLen: Integer;
  LBuffer: TBytes;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LReq := X509_REQ_new;
  try
    LName := X509_REQ_get_subject_name(LReq);
    X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('CN')), MBSTRING_ASC,
      PAnsiChar(AnsiString(ACommonName)), -1, -1, 0);

    if Length(ASanDomains) > 0 then
    begin
      LSanValue := '';
      for LDomain in ASanDomains do
      begin
        if LSanValue <> '' then
          LSanValue := LSanValue + ',';
        LSanValue := LSanValue + 'DNS:' + LDomain;
      end;

      LExtStack := OPENSSL_sk_new_null;
      LSanExtension := X509V3_EXT_conf_nid(nil, nil, NID_subject_alt_name,
        PAnsiChar(AnsiString(LSanValue)));
      OPENSSL_sk_push(LExtStack, LSanExtension);
      X509_REQ_add_extensions(LReq, LExtStack);
      OPENSSL_sk_pop_free(LExtStack, @X509_EXTENSION_free);
    end;

    X509_REQ_set_pubkey(LReq, APkey);
    X509_REQ_sign(LReq, APkey, EVP_sha256);

    LBio := BIO_new(BIO_s_mem);
    try
      PEM_write_bio_X509_REQ(LBio, LReq);
      LLen := BIOCtrlPending(LBio);
      SetLength(LBuffer, LLen);
      BIO_read(LBio, @LBuffer[0], LLen);
      Result := TEncoding.ANSI.GetString(LBuffer);
    finally
      BIO_free(LBio);
    end;
  finally
    X509_REQ_free(LReq);
  end;
end;

class function TOpenSSLHelper.CreateCSRDer(APkey: pEVP_PKEY;
  const ACommonName: string; const ASanDomains: TArray<string>): TBytes;
var
  LReq: pX509_REQ;
  LName: pX509_NAME;
  LExtStack: PSTACK;
  LSanExtension: pX509_EXTENSION;
  LSanValue: string;
  LDomain: string;
  LDerLen: Integer;
  LDerPtr: Pointer;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LReq := X509_REQ_new;
  try
    LName := X509_REQ_get_subject_name(LReq);
    X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('CN')), MBSTRING_ASC,
      PAnsiChar(AnsiString(ACommonName)), -1, -1, 0);

    if Length(ASanDomains) > 0 then
    begin
      LSanValue := '';
      for LDomain in ASanDomains do
      begin
        if LSanValue <> '' then
          LSanValue := LSanValue + ',';
        LSanValue := LSanValue + 'DNS:' + LDomain;
      end;

      LExtStack := OPENSSL_sk_new_null;
      LSanExtension := X509V3_EXT_conf_nid(nil, nil, NID_subject_alt_name,
        PAnsiChar(AnsiString(LSanValue)));
      OPENSSL_sk_push(LExtStack, LSanExtension);
      X509_REQ_add_extensions(LReq, LExtStack);
      OPENSSL_sk_pop_free(LExtStack, @X509_EXTENSION_free);
    end;

    X509_REQ_set_pubkey(LReq, APkey);
    X509_REQ_sign(LReq, APkey, EVP_sha256);

    // Convert to DER format
    LDerLen := i2d_X509_REQ(LReq, nil);
    if LDerLen <= 0 then
      raise Exception.Create('Failed to get CSR DER length');

    SetLength(Result, LDerLen);
    LDerPtr := @Result[0];
    if i2d_X509_REQ(LReq, @LDerPtr) <> LDerLen then
      raise Exception.Create('Failed to convert CSR to DER');
  finally
    X509_REQ_free(LReq);
  end;
end;

class function TOpenSSLHelper.GetRsaPublicKeyDer(APkey: pEVP_PKEY): TBytes;
var
  LBio: pBIO;
  LLen: Integer;
  LBuffer: TBytes;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LBio := BIO_new(BIO_s_mem);
  try
    // Write the public key in DER format
    if i2d_PUBKEY_bio(LBio, APkey) <> 1 then
      raise Exception.Create('Failed to write public key to DER');

    LLen := BIOCtrlPending(LBio);
    SetLength(LBuffer, LLen);
    BIO_read(LBio, @LBuffer[0], LLen);
    Result := LBuffer;
  finally
    BIO_free(LBio);
  end;
end;

class function TOpenSSLHelper.CreateCSRDerWithSubject(APkey: pEVP_PKEY;
  const ACountry, AState, ALocality, AOrganization, AOrganizationalUnit,
  ACommonName, AEmailAddress: string;
  const ASanDomains: TArray<string>): TBytes;
var
  LReq: pX509_REQ;
  LName: pX509_NAME;
  LExtStack: PSTACK;
  LSanExtension: pX509_EXTENSION;
  LSanValue: string;
  LDomain: string;
  LDerLen: Integer;
  LDerPtr: Pointer;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LReq := X509_REQ_new;
  try
    LName := X509_REQ_get_subject_name(LReq);

    // Add all subject fields
    if ACountry <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('C')),
        MBSTRING_ASC, PAnsiChar(AnsiString(ACountry)), -1, -1, 0);
    if AState <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('ST')),
        MBSTRING_ASC, PAnsiChar(AnsiString(AState)), -1, -1, 0);
    if ALocality <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('L')),
        MBSTRING_ASC, PAnsiChar(AnsiString(ALocality)), -1, -1, 0);
    if AOrganization <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('O')),
        MBSTRING_ASC, PAnsiChar(AnsiString(AOrganization)), -1, -1, 0);
    if AOrganizationalUnit <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('OU')),
        MBSTRING_ASC, PAnsiChar(AnsiString(AOrganizationalUnit)), -1, -1, 0);
    if ACommonName <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('CN')),
        MBSTRING_ASC, PAnsiChar(AnsiString(ACommonName)), -1, -1, 0);
    if AEmailAddress <> '' then
      X509_NAME_add_entry_by_txt(LName, PAnsiChar(AnsiString('emailAddress')),
        MBSTRING_ASC, PAnsiChar(AnsiString(AEmailAddress)), -1, -1, 0);

    if Length(ASanDomains) > 0 then
    begin
      LSanValue := '';
      for LDomain in ASanDomains do
      begin
        if LSanValue <> '' then
          LSanValue := LSanValue + ',';
        LSanValue := LSanValue + 'DNS:' + LDomain;
      end;

      LExtStack := OPENSSL_sk_new_null;
      LSanExtension := X509V3_EXT_conf_nid(nil, nil, NID_subject_alt_name,
        PAnsiChar(AnsiString(LSanValue)));
      OPENSSL_sk_push(LExtStack, LSanExtension);
      X509_REQ_add_extensions(LReq, LExtStack);
      OPENSSL_sk_pop_free(LExtStack, @X509_EXTENSION_free);
    end;

    X509_REQ_set_pubkey(LReq, APkey);
    X509_REQ_sign(LReq, APkey, EVP_sha256);

    // Convert to DER format
    LDerLen := i2d_X509_REQ(LReq, nil);
    if LDerLen <= 0 then
      raise Exception.Create('Failed to get CSR DER length');

    SetLength(Result, LDerLen);
    LDerPtr := @Result[0];
    if i2d_X509_REQ(LReq, @LDerPtr) <> LDerLen then
      raise Exception.Create('Failed to convert CSR to DER format');
  finally
    X509_REQ_free(LReq);
  end;
end;

class function TOpenSSLHelper.SavePrivateKeyToStream(APkey: pEVP_PKEY): string;
var
  LBio: pBIO;
  LLen: Integer;
  LBuffer: TBytes;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LBio := BIO_new(BIO_s_mem);
  try
    if PEM_write_bio_PrivateKey(LBio, APkey, nil, nil, 0, nil, nil) <> 1 then
      raise Exception.Create('Failed to write private key to memory');

    LLen := BIOCtrlPending(LBio);
    SetLength(LBuffer, LLen);
    BIO_read(LBio, @LBuffer[0], LLen);
    Result := TEncoding.ANSI.GetString(LBuffer);
  finally
    BIO_free(LBio);
  end;
end;

class function TOpenSSLHelper.LoadPrivateKeyFromStream(const APemData: string)
  : pEVP_PKEY;
var
  LBio: pBIO;
  LPemBytes: TBytes;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LPemBytes := TEncoding.ANSI.GetBytes(APemData);
  LBio := BIO_new_mem_buf(@LPemBytes[0], Length(LPemBytes));
  try
    Result := PEM_read_bio_PrivateKey(LBio, nil, nil, nil);
    if Result = nil then
      raise Exception.Create('Failed to read private key from memory');
  finally
    BIO_free(LBio);
  end;
end;

class function TOpenSSLHelper.GetKeyPrint(APkey: pEVP_PKEY): string;
var
  LBio: pBIO;
  LLen: Integer;
  LBuffer: TBytes;
begin
  if not IsOpenSSLLoaded then
    raise Exception.Create('OpenSSL library not loaded');

  LBio := BIO_new(BIO_s_mem);
  try
    // For OpenSSL 3.x, we need to use EVP_PKEY_print_private
    // This is a simplified version - in production you might need to handle this differently
    if EVP_PKEY_print_private(LBio, APkey, 0, nil) <> 1 then
      raise Exception.Create('Failed to print private key');

    LLen := BIOCtrlPending(LBio);
    SetLength(LBuffer, LLen);
    BIO_read(LBio, @LBuffer[0], LLen);
    Result := TEncoding.ANSI.GetString(LBuffer);
  finally
    BIO_free(LBio);
  end;
end;

class function TOpenSSLHelper.IsKeyValid(APkey: pEVP_PKEY): Boolean;
begin
  Result := (APkey <> nil) and IsOpenSSLLoaded;
end;

class function TOpenSSLHelper.GetCertificateExpiryDate(const AFileName: string)
  : TDateTime;
var
  LBio: pBIO;
  LX509: pX509;
  LNotAfter: pASN1_TIME;
  LTimeBio: pBIO;
  LBuffer: TBytes;
  LLen: Integer;
  LYear, LMonth, LDay, LHour, LMin, LSec: Word;
  LTimeText: string;
begin
  Result := 0;

  if not IsOpenSSLLoaded then
    Exit;

  if not FileExists(AFileName) then
    Exit;

  try
    // Load certificate from file
    LBio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), PAnsiChar('r'));
    if LBio = nil then
      Exit;

    try
      LX509 := PEM_read_bio_X509(LBio, nil, nil, nil);
      if LX509 = nil then
        Exit;

      try
        // Get NotAfter time (OpenSSL 3.x uses X509_get0_notAfter)
        LNotAfter := X509_get0_notAfter(LX509);
        if LNotAfter = nil then
          Exit;

        // Convert ASN1_TIME to string using BIO
        LTimeBio := BIO_new(BIO_s_mem);
        if LTimeBio <> nil then
        begin
          try
            if ASN1_TIME_print(LTimeBio, LNotAfter) = 1 then
            begin
              LLen := BIOCtrlPending(LTimeBio);
              SetLength(LBuffer, LLen);
              BIO_read(LTimeBio, @LBuffer[0], LLen);
              LTimeText := TEncoding.ANSI.GetString(LBuffer);

              // Parse ASN1 time format: "MMM DD HH:MM:SS YYYY GMT"
              // Example: "Jan  6 14:30:00 2026 GMT"
              if TryParseASN1TimeString(LTimeText, LYear, LMonth, LDay, LHour,
                LMin, LSec) then
                Result := EncodeDateTime(LYear, LMonth, LDay, LHour,
                  LMin, LSec, 0);
            end;
          finally
            BIO_free(LTimeBio);
          end;
        end;
      finally
        X509_free(LX509);
      end;
    finally
      BIO_free(LBio);
    end;
  except
    Result := 0;
  end;
end;

class function TOpenSSLHelper.VerifyCertificateAndKey(const ACertFile,
  AKeyFile: string; out AErrorMessage: string): Boolean;
var
  LCertContent: string;
  LKeyContent: string;
  LKey: pEVP_PKEY;
begin
  Result := False;
  AErrorMessage := '';

  try
    // Check files exist
    if not TFile.Exists(ACertFile) then
    begin
      AErrorMessage := 'Certificate file not found: ' + ACertFile;
      Exit;
    end;

    if not TFile.Exists(AKeyFile) then
    begin
      AErrorMessage := 'Key file not found: ' + AKeyFile;
      Exit;
    end;

    // Read certificate
    LCertContent := TFile.ReadAllText(ACertFile, TEncoding.ASCII);
    if not LCertContent.Contains('-----BEGIN CERTIFICATE-----') then
    begin
      AErrorMessage :=
        'Invalid certificate format (no BEGIN CERTIFICATE marker)';
      Exit;
    end;

    // Read and verify private key
    LKeyContent := TFile.ReadAllText(AKeyFile, TEncoding.ASCII);
    if not LKeyContent.Contains('-----BEGIN') then
    begin
      AErrorMessage := 'Invalid key format (no BEGIN marker)';
      Exit;
    end;

    // Try to load the private key with OpenSSL
    try
      LKey := TOpenSSLHelper.LoadPrivateKey(AKeyFile);
      try
        if LKey = nil then
        begin
          AErrorMessage := 'Failed to load private key with OpenSSL';
          Exit;
        end;

        // Key loaded successfully
        Result := True;
      finally
        if LKey <> nil then
          TOpenSSLHelper.FreeKey(LKey);
      end;
    except
      on E: Exception do
      begin
        AErrorMessage := 'OpenSSL error loading key: ' + E.Message;
        Exit;
      end;
    end;

  except
    on E: Exception do
    begin
      AErrorMessage := 'Verification error: ' + E.Message;
      Result := False;
    end;
  end;
end;

// Helper function to parse ASN1 time string
class function TOpenSSLHelper.TryParseASN1TimeString(const ATimeStr: string;
  out AYear, AMonth, ADay, AHour, AMin, ASec: Word): Boolean;
var
  LParts: TArray<string>;
  LMonthStr: string;
  LTimeParts: TArray<string>;
begin
  Result := False;

  try
    // Format: "Jan  6 14:30:00 2026 GMT"
    // Split by spaces
    LParts := ATimeStr.Split([' '], TStringSplitOptions.ExcludeEmpty);

    if Length(LParts) < 5 then
      Exit;

    // Month
    LMonthStr := LParts[0];
    if SameText(LMonthStr, 'Jan') then
      AMonth := 1
    else if SameText(LMonthStr, 'Feb') then
      AMonth := 2
    else if SameText(LMonthStr, 'Mar') then
      AMonth := 3
    else if SameText(LMonthStr, 'Apr') then
      AMonth := 4
    else if SameText(LMonthStr, 'May') then
      AMonth := 5
    else if SameText(LMonthStr, 'Jun') then
      AMonth := 6
    else if SameText(LMonthStr, 'Jul') then
      AMonth := 7
    else if SameText(LMonthStr, 'Aug') then
      AMonth := 8
    else if SameText(LMonthStr, 'Sep') then
      AMonth := 9
    else if SameText(LMonthStr, 'Oct') then
      AMonth := 10
    else if SameText(LMonthStr, 'Nov') then
      AMonth := 11
    else if SameText(LMonthStr, 'Dec') then
      AMonth := 12
    else
      Exit;

    // Day
    ADay := StrToIntDef(LParts[1], 0);
    if ADay = 0 then
      Exit;

    // Time (HH:MM:SS)
    LTimeParts := LParts[2].Split([':']);
    if Length(LTimeParts) <> 3 then
      Exit;

    AHour := StrToIntDef(LTimeParts[0], 0);
    AMin := StrToIntDef(LTimeParts[1], 0);
    ASec := StrToIntDef(LTimeParts[2], 0);

    // Year
    AYear := StrToIntDef(LParts[3], 0);
    if AYear = 0 then
      Exit;

    Result := True;
  except
    Result := False;
  end;
end;

end.
