unit OpenSSL3.CSRGenerator;

interface

uses
  System.Classes, System.SysUtils,
  System.NetEncoding,
  OpenSSL3.Types, OpenSSL3.Lib, OpenSSL3.Helper;

type

  TCsrGenerator = class
  private
    FPrivateKey: pEVP_PKEY;
    FSubject: TCsrSubject;
    FSanNames: TArray<string>;
    function BuildAsn1Sequence(const AItems: TArray<TBytes>): TBytes;
    function BuildAsn1Integer(const AValue: TBytes): TBytes;
    function BuildAsn1OctetString(const AData: TBytes): TBytes;
    function BuildAsn1ObjectIdentifier(const AOid: string): TBytes;
    function BuildAsn1PrintableString(const AValue: string): TBytes;
    function BuildAsn1Utf8String(const AValue: string): TBytes;
    function BuildAsn1Set(const AItems: TArray<TBytes>): TBytes;
    function BuildAsn1Tagged(const ATag: Byte; const AData: TBytes): TBytes;
    function BuildAsn1BitString(const AData: TBytes): TBytes;
    function BuildAsn1Length(const ALen: Integer): TBytes;
    function BuildName(const ASubject: TCsrSubject): TBytes;
    function BuildSubjectAlternativeNameExtension(const ASanNames
      : TArray<string>): TBytes;
    function BuildExtensions(const ASanNames: TArray<string>): TBytes;
    function BuildCertificationRequestInfo: TBytes;
    function SignRequest(const ARequestInfo: TBytes): TBytes;
    function CleanSubjectField(const AValue: string): string;
    procedure SetSubject(const ASubject: TCsrSubject);
    procedure SetSubjectAlternativeNames(const ASanNames: TArray<string>);
  protected
    procedure Log(const AMessage: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure GenerateRsaKeyPair(ABits: Integer);
    procedure GenerateRsaKeyPair2048;

    procedure LoadPrivateKeyFromPem(const AFileName: string);
    procedure SavePrivateKeyToPem(const AFileName: string);

    function GenerateCsrDer: TBytes;
    function GenerateCsrPem: string;

    property Subject: TCsrSubject read FSubject write SetSubject;
    property SanNames: TArray<string> read FSanNames
      write SetSubjectAlternativeNames;
  end;

implementation

{ TCsrGenerator }

constructor TCsrGenerator.Create;
begin
  inherited;
  FPrivateKey := nil;

  // Set default subject
  FSubject.Country := '';
  FSubject.State := '';
  FSubject.Locality := '';
  FSubject.Organization := '';
  FSubject.OrganizationalUnit := '';
  FSubject.CommonName := '';
  FSubject.EmailAddress := '';

  SetLength(FSanNames, 0);
end;

destructor TCsrGenerator.Destroy;
begin
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  inherited;
end;

procedure TCsrGenerator.Log(const AMessage: string);
begin

end;

procedure TCsrGenerator.GenerateRsaKeyPair(ABits: Integer);
begin
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  FPrivateKey := TOpenSSLHelper.GenerateRSAKey(ABits);
end;

procedure TCsrGenerator.GenerateRsaKeyPair2048;
begin
  GenerateRsaKeyPair(2048);
end;

procedure TCsrGenerator.LoadPrivateKeyFromPem(const AFileName: string);
begin
  if FPrivateKey <> nil then
    TOpenSSLHelper.FreeKey(FPrivateKey);
  FPrivateKey := TOpenSSLHelper.LoadPrivateKey(AFileName);
end;

procedure TCsrGenerator.SavePrivateKeyToPem(const AFileName: string);
begin
  TOpenSSLHelper.SavePrivateKey(FPrivateKey, AFileName);
end;

procedure TCsrGenerator.SetSubject(const ASubject: TCsrSubject);
begin
  // Clean and validate subject fields
  FSubject.Country := CleanSubjectField(ASubject.Country);
  FSubject.State := CleanSubjectField(ASubject.State);
  FSubject.Locality := CleanSubjectField(ASubject.Locality);
  FSubject.Organization := CleanSubjectField(ASubject.Organization);
  FSubject.OrganizationalUnit := CleanSubjectField(ASubject.OrganizationalUnit);
  FSubject.CommonName := CleanSubjectField(ASubject.CommonName);
  FSubject.EmailAddress := CleanSubjectField(ASubject.EmailAddress);
end;

procedure TCsrGenerator.SetSubjectAlternativeNames(const ASanNames
  : TArray<string>);
begin
  FSanNames := ASanNames;
end;

function TCsrGenerator.BuildAsn1Length(const ALen: Integer): TBytes;
begin
  if ALen < 128 then
  begin
    SetLength(Result, 1);
    Result[0] := ALen;
  end
  else if ALen < 256 then
  begin
    SetLength(Result, 2);
    Result[0] := $81;
    Result[1] := ALen;
  end
  else if ALen < 65536 then
  begin
    SetLength(Result, 3);
    Result[0] := $82;
    Result[1] := (ALen shr 8) and $FF;
    Result[2] := ALen and $FF;
  end
  else
  begin
    SetLength(Result, 4);
    Result[0] := $83;
    Result[1] := (ALen shr 16) and $FF;
    Result[2] := (ALen shr 8) and $FF;
    Result[3] := ALen and $FF;
  end;
end;

function TCsrGenerator.BuildAsn1Sequence(const AItems: TArray<TBytes>): TBytes;
var
  LTotalLen: Integer;
  LItem: TBytes;
  LOffset: Integer;
begin
  LTotalLen := 0;
  for LItem in AItems do
    Inc(LTotalLen, Length(LItem));

  SetLength(Result, 1 + Length(BuildAsn1Length(LTotalLen)) + LTotalLen);
  Result[0] := $30; // SEQUENCE tag
  LOffset := 1;

  var
    LLengthBytes: TBytes;
  LLengthBytes := BuildAsn1Length(LTotalLen);
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  for LItem in AItems do
  begin
    Move(LItem[0], Result[LOffset], Length(LItem));
    Inc(LOffset, Length(LItem));
  end;
end;

function TCsrGenerator.BuildAsn1Integer(const AValue: TBytes): TBytes;
var
  LValue: TBytes;
  LOffset: Integer;
begin
  // Remove leading zeros, but keep at least one byte
  LValue := AValue;
  while (Length(LValue) > 1) and (LValue[0] = 0) and
    ((LValue[1] and $80) = 0) do
    LValue := Copy(LValue, 1, Length(LValue) - 1);

  SetLength(Result, 1 + Length(BuildAsn1Length(Length(LValue))) +
    Length(LValue));
  Result[0] := $02; // INTEGER tag
  LOffset := 1;

  var
    LLengthBytes: TBytes;
  LLengthBytes := BuildAsn1Length(Length(LValue));
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Move(LValue[0], Result[LOffset], Length(LValue));
end;

function TCsrGenerator.BuildAsn1OctetString(const AData: TBytes): TBytes;
var
  LOffset: Integer;
begin
  SetLength(Result, 1 + Length(BuildAsn1Length(Length(AData))) + Length(AData));
  Result[0] := $04; // OCTET STRING tag
  LOffset := 1;

  var
    LLengthBytes: TBytes;
  LLengthBytes := BuildAsn1Length(Length(AData));
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Move(AData[0], Result[LOffset], Length(AData));
end;

function TCsrGenerator.BuildAsn1ObjectIdentifier(const AOid: string): TBytes;
var
  LParts: TArray<string>;
  LValues: TArray<Integer>;
  LEncoded: TBytes;
  LIdx, LVal, LEncodedLen: Integer;
  LTemp: TBytes;
  LByte: Byte;
begin
  LParts := AOid.Split(['.']);
  SetLength(LValues, Length(LParts));
  for LIdx := 0 to High(LParts) do
    LValues[LIdx] := StrToIntDef(LParts[LIdx], 0);

  // Encode OID
  SetLength(LEncoded, 0);
  for LIdx := 0 to High(LValues) do
  begin
    if LIdx = 0 then
      LVal := LValues[0] * 40 + LValues[1]
    else if LIdx = 1 then
      Continue // Already handled above
    else
      LVal := LValues[LIdx];

    if LVal < 128 then
    begin
      SetLength(LEncoded, Length(LEncoded) + 1);
      LEncoded[High(LEncoded)] := LVal;
    end
    else
    begin
      SetLength(LTemp, 0);
      while LVal > 0 do
      begin
        SetLength(LTemp, Length(LTemp) + 1);
        LTemp[High(LTemp)] := (LVal and $7F) or $80;
        LVal := LVal shr 7;
      end;
      LTemp[High(LTemp)] := LTemp[High(LTemp)] and $7F;
      // Clear high bit on last byte

      for LByte in LTemp do
      begin
        SetLength(LEncoded, Length(LEncoded) + 1);
        LEncoded[High(LEncoded)] := LByte;
      end;
    end;
  end;

  SetLength(Result, 1 + Length(BuildAsn1Length(Length(LEncoded))) +
    Length(LEncoded));
  Result[0] := $06; // OBJECT IDENTIFIER tag
  LEncodedLen := 1;

  var
    LLengthBytes: TBytes;
  LLengthBytes := BuildAsn1Length(Length(LEncoded));
  Move(LLengthBytes[0], Result[LEncodedLen], Length(LLengthBytes));
  Inc(LEncodedLen, Length(LLengthBytes));

  Move(LEncoded[0], Result[LEncodedLen], Length(LEncoded));
end;

function TCsrGenerator.BuildAsn1PrintableString(const AValue: string): TBytes;
var
  LBytes: TBytes;
  LOffset: Integer;
  LCleanValue: string;
  LChar: Char;
  LProblematicChars: string;
  LUtf8Bytes: TBytes;
  LByte: Byte;
  LLengthBytes: TBytes;
begin
  // Clean the value to ensure it's ASCII-compatible
  LCleanValue := StringReplace(AValue, #0, '', [rfReplaceAll]);
  // Remove null chars
  LCleanValue := StringReplace(LCleanValue, #13, '', [rfReplaceAll]);
  // Remove CR
  LCleanValue := StringReplace(LCleanValue, #10, '', [rfReplaceAll]);
  // Remove LF
  LCleanValue := StringReplace(LCleanValue, #9, '', [rfReplaceAll]);
  // Remove TAB

  // Check for problematic characters and remove them
  LProblematicChars := '';
  for LChar in LCleanValue do
  begin
    if Ord(LChar) > 127 then // Non-ASCII character
    begin
      LProblematicChars := LProblematicChars + LChar;
    end;
  end;

  if LProblematicChars <> '' then
  begin
    // Remove problematic characters
    for LChar in LProblematicChars do
    begin
      LCleanValue := StringReplace(LCleanValue, LChar, '', [rfReplaceAll]);
    end;
  end;

  // Convert to ASCII, handling any remaining encoding issues
  try
    LBytes := TEncoding.ASCII.GetBytes(LCleanValue);
  except
    on E: EEncodingError do
    begin
      // Final fallback: convert to UTF8 and take only ASCII-compatible bytes
      LUtf8Bytes := TEncoding.UTF8.GetBytes(LCleanValue);
      SetLength(LBytes, 0);
      for LByte in LUtf8Bytes do
      begin
        if LByte < 128 then // ASCII range
        begin
          SetLength(LBytes, Length(LBytes) + 1);
          LBytes[High(LBytes)] := LByte;
        end;
      end;
    end;
  end;

  SetLength(Result, 1 + Length(BuildAsn1Length(Length(LBytes))) +
    Length(LBytes));
  Result[0] := $13; // PrintableString tag
  LOffset := 1;

  LLengthBytes := BuildAsn1Length(Length(LBytes));
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Move(LBytes[0], Result[LOffset], Length(LBytes));
end;

function TCsrGenerator.BuildAsn1Utf8String(const AValue: string): TBytes;
var
  LBytes: TBytes;
  LOffset: Integer;
  LCleanValue: string;
  LCleanStr: string;
  LChar: Char;
  LCharBytes: TBytes;
  LLengthBytes: TBytes;
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

  // Convert to UTF8, handling any encoding issues
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

  SetLength(Result, 1 + Length(BuildAsn1Length(Length(LBytes))) +
    Length(LBytes));
  Result[0] := $0C; // UTF8String tag
  LOffset := 1;

  LLengthBytes := BuildAsn1Length(Length(LBytes));
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Move(LBytes[0], Result[LOffset], Length(LBytes));
end;

function TCsrGenerator.BuildAsn1Set(const AItems: TArray<TBytes>): TBytes;
var
  LTotalLen: Integer;
  LItem: TBytes;
  LOffset: Integer;
begin
  LTotalLen := 0;
  for LItem in AItems do
    Inc(LTotalLen, Length(LItem));

  SetLength(Result, 1 + Length(BuildAsn1Length(LTotalLen)) + LTotalLen);
  Result[0] := $31; // SET tag
  LOffset := 1;

  var
    LLengthBytes: TBytes;
  LLengthBytes := BuildAsn1Length(LTotalLen);
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  for LItem in AItems do
  begin
    Move(LItem[0], Result[LOffset], Length(LItem));
    Inc(LOffset, Length(LItem));
  end;
end;

function TCsrGenerator.BuildAsn1Tagged(const ATag: Byte;
  const AData: TBytes): TBytes;
var
  LOffset: Integer;
  LLengthBytes: TBytes;
begin
  SetLength(Result, 1 + Length(BuildAsn1Length(Length(AData))) + Length(AData));
  Result[0] := ATag;
  LOffset := 1;

  LLengthBytes := BuildAsn1Length(Length(AData));
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Move(AData[0], Result[LOffset], Length(AData));
end;

function TCsrGenerator.BuildAsn1BitString(const AData: TBytes): TBytes;
var
  LOffset: Integer;
  LLengthBytes: TBytes;
begin
  SetLength(Result, 1 + Length(BuildAsn1Length(Length(AData) + 1)) +
    Length(AData) + 1);
  Result[0] := $03; // BIT STRING tag
  LOffset := 1;

  LLengthBytes := BuildAsn1Length(Length(AData) + 1);
  Move(LLengthBytes[0], Result[LOffset], Length(LLengthBytes));
  Inc(LOffset, Length(LLengthBytes));

  Result[LOffset] := 0; // Unused bits
  Inc(LOffset);

  Move(AData[0], Result[LOffset], Length(AData));
end;

function TCsrGenerator.BuildName(const ASubject: TCsrSubject): TBytes;
var
  LAttributes: TArray<TBytes>;
  LAttrCount: Integer;

  procedure AddAttribute(const AOid: string; const AValue: string);
  var
    LAttr: TBytes;
  begin
    if AValue = '' then
      Exit;

    LAttr := BuildAsn1Sequence([BuildAsn1ObjectIdentifier(AOid),
      BuildAsn1Set([BuildAsn1PrintableString(AValue)])]);

    SetLength(LAttributes, LAttrCount + 1);
    LAttributes[LAttrCount] := LAttr;
    Inc(LAttrCount);
  end;

begin
  LAttrCount := 0;
  SetLength(LAttributes, 0);

  AddAttribute('2.5.4.6', ASubject.Country); // C
  AddAttribute('2.5.4.8', ASubject.State); // ST
  AddAttribute('2.5.4.7', ASubject.Locality); // L
  AddAttribute('2.5.4.10', ASubject.Organization); // O
  AddAttribute('2.5.4.11', ASubject.OrganizationalUnit); // OU
  AddAttribute('2.5.4.3', ASubject.CommonName); // CN
  AddAttribute('1.2.840.113549.1.9.1', ASubject.EmailAddress); // emailAddress

  Result := BuildAsn1Sequence(LAttributes);
end;

function TCsrGenerator.BuildSubjectAlternativeNameExtension(const ASanNames
  : TArray<string>): TBytes;
var
  LNames: TArray<TBytes>;
  LNameCount: Integer;
  LIdx: Integer;
begin
  if Length(ASanNames) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LNameCount := 0;
  SetLength(LNames, Length(ASanNames));

  for LIdx := 0 to High(ASanNames) do
  begin
    if ASanNames[LIdx] <> '' then
    begin
      // DNS name (tag 2)
      LNames[LNameCount] := BuildAsn1Tagged($82,
        BuildAsn1Utf8String(ASanNames[LIdx]));
      Inc(LNameCount);
    end;
  end;

  SetLength(LNames, LNameCount);

  // SubjectAltName extension
  Result := BuildAsn1Sequence([BuildAsn1ObjectIdentifier('2.5.29.17'),
    // subjectAltName
    BuildAsn1OctetString(BuildAsn1Sequence(LNames))]);
end;

function TCsrGenerator.BuildExtensions(const ASanNames: TArray<string>): TBytes;
var
  LExtensions: TArray<TBytes>;
  LExtCount: Integer;
begin
  LExtCount := 0;
  SetLength(LExtensions, 0);

  // Add Subject Alternative Name extension if we have SAN names
  if Length(ASanNames) > 0 then
  begin
    SetLength(LExtensions, 1);
    LExtensions[0] := BuildSubjectAlternativeNameExtension(ASanNames);
    LExtCount := 1;
  end;

  if LExtCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  Result := BuildAsn1Tagged($A0, BuildAsn1Sequence(LExtensions));
end;

function TCsrGenerator.BuildCertificationRequestInfo: TBytes;
var
  LVersion: TBytes;
  LSubject: TBytes;
  LSubjectPkInfo: TBytes;
  LAttributes: TBytes;
  LModulus, LExponent: TBytes;
  LPublicKeyDer: TBytes;
begin
  // Version (0)
  LVersion := BuildAsn1Integer([0]);

  // Subject
  LSubject := BuildName(FSubject);

  // Subject Public Key Info
  // Use OpenSSL's built-in function to get the public key in DER format
  if FPrivateKey = nil then
    raise EOpenSSL3CSRError.Create('Private key not loaded');

  try
    // Get the public key in DER format using OpenSSL
    LPublicKeyDer := TOpenSSLHelper.GetRsaPublicKeyDer(FPrivateKey);

    // Build SubjectPublicKeyInfo using the DER-encoded public key
    LSubjectPkInfo := BuildAsn1Sequence
      ([BuildAsn1Sequence([BuildAsn1ObjectIdentifier('1.2.840.113549.1.1.1'),
      // rsaEncryption
      BuildAsn1Sequence([]) // NULL parameters
      ]), BuildAsn1BitString(LPublicKeyDer)]);
  except
    on E: Exception do
    begin
      Log('Failed to get public key DER format: ' + E.Message);
      Log('Falling back to manual modulus/exponent extraction...');

      // Fallback to manual extraction
      try
        LModulus := TOpenSSLHelper.GetPublicKeyModulus(FPrivateKey);
        LExponent := TOpenSSLHelper.GetPublicKeyExponent(FPrivateKey);
      except
        raise EOpenSSL3CSRError.Create
          ('Failed to extract public key components');
      end;

      // Build SubjectPublicKeyInfo manually
      LSubjectPkInfo := BuildAsn1Sequence
        ([BuildAsn1Sequence([BuildAsn1ObjectIdentifier('1.2.840.113549.1.1.1'),
        // rsaEncryption
        BuildAsn1Sequence([]) // NULL parameters
        ]), BuildAsn1BitString(BuildAsn1Sequence([BuildAsn1Integer(LModulus),
        BuildAsn1Integer(LExponent)]))]);
    end;
  end;

  // Attributes
  LAttributes := BuildExtensions(FSanNames);

  // CertificationRequestInfo
  Result := BuildAsn1Sequence([LVersion, LSubject, LSubjectPkInfo,
    LAttributes]);
end;

function TCsrGenerator.SignRequest(const ARequestInfo: TBytes): TBytes;
var
  LSignature: TBytes;
  LSignatureDer: TBytes;
begin
  if FPrivateKey = nil then
    raise EOpenSSL3CSRError.Create('Private key not loaded');

  // Create real RSA signature using OpenSSL3 EVP functions
  LSignature := TOpenSSLHelper.SignData(FPrivateKey, ARequestInfo);

  // RSA signatures should be encoded as BIT STRING, not INTEGER
  LSignatureDer := BuildAsn1BitString(LSignature);

  // CertificationRequest
  Result := BuildAsn1Sequence([ARequestInfo,
    BuildAsn1Sequence([BuildAsn1ObjectIdentifier('1.2.840.113549.1.1.11')
    // sha256WithRSAEncryption
    ]), LSignatureDer]);
end;

function TCsrGenerator.CleanSubjectField(const AValue: string): string;
var
  LChar: Char;
begin
  Result := Trim(AValue);

  // Remove problematic characters that can cause encoding issues
  Result := StringReplace(Result, #0, '', [rfReplaceAll]); // Null chars
  Result := StringReplace(Result, #13, '', [rfReplaceAll]); // CR
  Result := StringReplace(Result, #10, '', [rfReplaceAll]); // LF
  Result := StringReplace(Result, #9, '', [rfReplaceAll]); // TAB

  // Remove other control characters (0x01-0x1F except space)
  for LChar := #1 to #31 do
  begin
    if LChar <> ' ' then
      Result := StringReplace(Result, LChar, '', [rfReplaceAll]);
  end;

  // Limit length to prevent issues
  if Length(Result) > 64 then
    Result := Copy(Result, 1, 64);
end;

function TCsrGenerator.GenerateCsrDer: TBytes;
var
  LRequestInfo: TBytes;
begin
  if FSubject.CommonName = '' then
    raise EOpenSSL3CSRError.Create('Common Name (CN) is required');

  if FPrivateKey = nil then
    raise EOpenSSL3CSRError.Create('Private key not loaded');

  // Use OpenSSL's built-in CSR generation with all subject fields
  try
    Log('Attempting OpenSSL CSR generation with all subject fields...');
    Result := TOpenSSLHelper.CreateCSRDerWithSubject(FPrivateKey,
      FSubject.Country, FSubject.State, FSubject.Locality,
      FSubject.Organization, FSubject.OrganizationalUnit, FSubject.CommonName,
      FSubject.EmailAddress, FSanNames);
    Log('CSR generated successfully using OpenSSL with all subject fields');
  except
    on E: Exception do
    begin
      Log('OpenSSL CSR generation with SAN failed: ' + E.Message);
      Log('Trying OpenSSL CSR generation without SAN extensions...');
      try
        // Try without SAN extensions
        Result := TOpenSSLHelper.CreateCSRDerWithSubject(FPrivateKey,
          FSubject.Country, FSubject.State, FSubject.Locality,
          FSubject.Organization, FSubject.OrganizationalUnit,
          FSubject.CommonName, FSubject.EmailAddress, nil);
        Log('CSR generated successfully using OpenSSL without SAN extensions');
      except
        on E2: Exception do
        begin
          Log('OpenSSL CSR generation without SAN also failed: ' + E2.Message);
          Log('Falling back to manual ASN.1 construction...');
          // Fallback to manual CSR generation if OpenSSL CSR generation fails
          LRequestInfo := BuildCertificationRequestInfo;
          Result := SignRequest(LRequestInfo);
        end;
      end;
    end;
  end;
end;

function TCsrGenerator.GenerateCsrPem: string;
var
  LDer: TBytes;
  LBase64: string;
  LLineLen: Integer;
  LPos: Integer;
  LLine: string;
begin
  LDer := GenerateCsrDer;
  LBase64 := TNetEncoding.Base64.EncodeBytesToString(LDer);

  // Format as PEM
  Result := '-----BEGIN CERTIFICATE REQUEST-----' + #13#10;
  LLineLen := 64;
  LPos := 0;
  while LPos < Length(LBase64) do
  begin
    LLine := Copy(LBase64, LPos + 1, LLineLen);
    Result := Result + LLine + #13#10;
    Inc(LPos, LLineLen);
  end;
  Result := Result + '-----END CERTIFICATE REQUEST-----' + #13#10;
end;

end.
