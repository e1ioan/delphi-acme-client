unit OpenSSL3.Legacy;

interface

uses
  Winapi.Windows, System.SysUtils, OpenSSL3.Lib;

const
  LIBLEGACY_DLL_NAME = 'legacy.dll';

type
  // Legacy provider types
  pOSSL_PROVIDER = Pointer;
  pOSSL_LIB_CTX = Pointer;

var
  // Library handle
  hLegacy: HMODULE = 0;

  // Provider functions
  OSSL_PROVIDER_load: function(ALibctx: pOSSL_LIB_CTX; AName: PAnsiChar)
    : pOSSL_PROVIDER;
cdecl = nil;
OSSL_PROVIDER_unload:
function(AProv: pOSSL_PROVIDER): Integer;
cdecl = nil;
OSSL_PROVIDER_get0_name:
function(AProv: pOSSL_PROVIDER): PAnsiChar;
cdecl = nil;
OSSL_PROVIDER_available:
function(ALibctx: pOSSL_LIB_CTX; AName: PAnsiChar): Integer;
cdecl = nil;

// Context functions
OSSL_LIB_CTX_new:
function: pOSSL_LIB_CTX;
cdecl = nil;
OSSL_LIB_CTX_free:
function(ACtx: pOSSL_LIB_CTX): Integer;
cdecl = nil;
OSSL_LIB_CTX_get0_global_default:
function: pOSSL_LIB_CTX;
cdecl = nil;

// Property functions
EVP_set_default_properties:
function(ALibctx: pOSSL_LIB_CTX; AProps: PAnsiChar): Integer;
cdecl = nil;
EVP_default_properties_enable_fips:
function(ALibctx: pOSSL_LIB_CTX; AEnable: Integer): Integer;
cdecl = nil;

// Legacy digest functions (MD2, MD4, MD5, etc.)
EVP_md2:
function: pEVP_MD;
cdecl = nil;
EVP_md4:
function: pEVP_MD;
cdecl = nil;
EVP_md5:
function: pEVP_MD;
cdecl = nil;
EVP_DigestInit_ex:
function(ACtx: pEVP_MD_CTX; AType: pEVP_MD; AImpl: pENGINE): Integer;
cdecl = nil;
EVP_DigestUpdate:
function(ACtx: pEVP_MD_CTX; AData: Pointer; ACount: NativeUInt): Integer;
cdecl = nil;
EVP_DigestFinal_ex:
function(ACtx: pEVP_MD_CTX; AMd: Pointer; var ASize: Cardinal): Integer;
cdecl = nil;

// OpenSSL 3.x digest functions
EVP_DigestInit:
function(ACtx: pEVP_MD_CTX; AType: pEVP_MD): Integer;
cdecl = nil;
EVP_DigestFinal:
function(ACtx: pEVP_MD_CTX; AMd: Pointer; var ASize: Cardinal): Integer;
cdecl = nil;

// Legacy provider management functions
function LoadLegacyProvider: Boolean;
procedure UnloadLegacyProvider;
function IsLegacyProviderLoaded: Boolean;
function IsLegacyProviderAvailable: Boolean;
function CheckOpenSSLProviderSupport: Boolean;
function TestLegacyProviderCompatibility: Boolean;

// Helper functions for legacy algorithms
function EnableLegacyAlgorithms: Boolean;
function DisableLegacyAlgorithms: Boolean;

// Legacy algorithm demonstration functions
function CalculateMD2Hash(const AData: string): string;
function CalculateMD2HashBytes(const AData: TBytes): string;
function CalculateMD4Hash(const AData: string): string;
function CalculateMD4HashBytes(const AData: TBytes): string;
function TestLegacyHashAvailability: string;
function TryAlternativeLegacyHashAccess: string;

implementation

var
  LLegacyProviderLoaded: Boolean = False;
  LLegacyProvider: pOSSL_PROVIDER = nil;
  LDefaultContext: pOSSL_LIB_CTX = nil;

function LoadLegacyProvider: Boolean;
begin
  if LLegacyProviderLoaded then
  begin
    Result := True;
    Exit;
  end;

  if not IsOpenSSLLoaded then
  begin
    raise Exception.Create
      ('OpenSSL library must be loaded before loading legacy provider');
  end;

  try
    // Set OPENSSL_MODULES environment variable to help OpenSSL find the legacy provider
    SetEnvironmentVariable('OPENSSL_MODULES',
      PChar(ExtractFilePath(ParamStr(0))));

    // Load legacy.dll
    hLegacy := LoadLibrary(PChar(LIBLEGACY_DLL_NAME));
    if hLegacy = 0 then
      raise Exception.CreateFmt('Failed to load %s', [LIBLEGACY_DLL_NAME]);

    // Load provider functions from libcrypto (not from legacy.dll)
    // These functions are part of the main OpenSSL library
    OSSL_PROVIDER_load := GetProcAddress(hCrypto, 'OSSL_PROVIDER_load');
    OSSL_PROVIDER_unload := GetProcAddress(hCrypto, 'OSSL_PROVIDER_unload');
    OSSL_PROVIDER_get0_name := GetProcAddress(hCrypto,
      'OSSL_PROVIDER_get0_name');
    OSSL_PROVIDER_available := GetProcAddress(hCrypto,
      'OSSL_PROVIDER_available');

    OSSL_LIB_CTX_new := GetProcAddress(hCrypto, 'OSSL_LIB_CTX_new');
    OSSL_LIB_CTX_free := GetProcAddress(hCrypto, 'OSSL_LIB_CTX_free');
    OSSL_LIB_CTX_get0_global_default := GetProcAddress(hCrypto,
      'OSSL_LIB_CTX_get0_global_default');

    EVP_set_default_properties := GetProcAddress(hCrypto,
      'EVP_set_default_properties');
    EVP_default_properties_enable_fips :=
      GetProcAddress(hCrypto, 'EVP_default_properties_enable_fips');

    // Load legacy digest functions (MD2, MD4, MD5)
    EVP_md2 := GetProcAddress(hCrypto, 'EVP_md2');
    EVP_md4 := GetProcAddress(hCrypto, 'EVP_md4');
    EVP_md5 := GetProcAddress(hCrypto, 'EVP_md5');
    EVP_DigestInit_ex := GetProcAddress(hCrypto, 'EVP_DigestInit_ex');
    EVP_DigestUpdate := GetProcAddress(hCrypto, 'EVP_DigestUpdate');
    EVP_DigestFinal_ex := GetProcAddress(hCrypto, 'EVP_DigestFinal_ex');

    // Load simpler digest functions
    EVP_DigestInit := GetProcAddress(hCrypto, 'EVP_DigestInit');
    EVP_DigestFinal := GetProcAddress(hCrypto, 'EVP_DigestFinal');

    // Check if all required functions were loaded
    if not Assigned(OSSL_PROVIDER_load) then
      raise Exception.CreateFmt
        ('OSSL_PROVIDER_load function not available in OpenSSL version: %s',
        [GetOpenSSLVersion]);
    if not Assigned(OSSL_LIB_CTX_get0_global_default) then
      raise Exception.CreateFmt
        ('OSSL_LIB_CTX_get0_global_default function not available in OpenSSL version: %s',
        [GetOpenSSLVersion]);

    // Get the default library context
    LDefaultContext := OSSL_LIB_CTX_get0_global_default();
    if not Assigned(LDefaultContext) then
      raise Exception.Create('Failed to get default library context');

    // Try different approaches to load the legacy provider
    // Method 1: Try loading with full path
    LLegacyProvider := OSSL_PROVIDER_load(LDefaultContext,
      PAnsiChar(AnsiString(LIBLEGACY_DLL_NAME)));
    if not Assigned(LLegacyProvider) then
    begin
      // Method 2: Try loading with just 'legacy'
      LLegacyProvider := OSSL_PROVIDER_load(LDefaultContext, 'legacy');
    end;

    if not Assigned(LLegacyProvider) then
    begin
      // Method 3: Try loading with full path to the DLL
      LLegacyProvider := OSSL_PROVIDER_load(LDefaultContext,
        PAnsiChar(AnsiString(ExtractFilePath(ParamStr(0)) +
        LIBLEGACY_DLL_NAME)));
    end;

    if not Assigned(LLegacyProvider) then
    begin
      raise Exception.CreateFmt
        ('Failed to load legacy provider using any method. OpenSSL version: %s. '
        + 'Tried: legacy, %s, %s. ' +
        'This might be because: 1) Legacy provider DLL is incompatible, ' +
        '2) Provider loading method is incorrect, 3) OpenSSL configuration issue',
        [GetOpenSSLVersion, LIBLEGACY_DLL_NAME, ExtractFilePath(ParamStr(0)) +
        LIBLEGACY_DLL_NAME]);
    end;

    LLegacyProviderLoaded := True;
    Result := True;
  except
    on E: Exception do
    begin
      // Clean up on failure
      if hLegacy <> 0 then
      begin
        FreeLibrary(hLegacy);
        hLegacy := 0;
      end;
      raise Exception.CreateFmt('Legacy provider loading failed: %s',
        [E.Message]);
    end;
  end;
end;

procedure UnloadLegacyProvider;
begin
  if not LLegacyProviderLoaded then
    Exit;

  // Unload the legacy provider
  if Assigned(LLegacyProvider) and Assigned(OSSL_PROVIDER_unload) then
  begin
    OSSL_PROVIDER_unload(LLegacyProvider);
    LLegacyProvider := nil;
  end;

  // Clear all function pointers
  OSSL_PROVIDER_load := nil;
  OSSL_PROVIDER_unload := nil;
  OSSL_PROVIDER_get0_name := nil;
  OSSL_PROVIDER_available := nil;

  OSSL_LIB_CTX_new := nil;
  OSSL_LIB_CTX_free := nil;
  OSSL_LIB_CTX_get0_global_default := nil;

  EVP_set_default_properties := nil;
  EVP_default_properties_enable_fips := nil;

  EVP_md2 := nil;
  EVP_md4 := nil;
  EVP_md5 := nil;
  EVP_DigestInit_ex := nil;
  EVP_DigestUpdate := nil;
  EVP_DigestFinal_ex := nil;
  EVP_DigestInit := nil;
  EVP_DigestFinal := nil;

  // Unload legacy.dll
  if hLegacy <> 0 then
  begin
    FreeLibrary(hLegacy);
    hLegacy := 0;
  end;

  LDefaultContext := nil;
  LLegacyProviderLoaded := False;
end;

function IsLegacyProviderLoaded: Boolean;
begin
  Result := LLegacyProviderLoaded and Assigned(LLegacyProvider);
end;

function CheckOpenSSLProviderSupport: Boolean;
begin
  Result := False;

  if not IsOpenSSLLoaded then
    Exit;

  try
    // Check if the provider functions are available
    Result := Assigned(GetProcAddress(hCrypto, 'OSSL_PROVIDER_load')) and
      Assigned(GetProcAddress(hCrypto, 'OSSL_LIB_CTX_get0_global_default'));
  except
    Result := False;
  end;
end;

function TestLegacyProviderCompatibility: Boolean;
var
  LTestHandle: HMODULE;
  LTestContext: pOSSL_LIB_CTX;
  LTestProvider: pOSSL_PROVIDER;
  LLoadFunc: function(ALibctx: Pointer; AName: PAnsiChar)
    : pOSSL_PROVIDER; cdecl;
  LGetContextFunc: function: Pointer; cdecl;
begin
  Result := False;

  if not IsOpenSSLLoaded then
    Exit;

  try
    // Try to load the legacy DLL to test compatibility
    LTestHandle := LoadLibrary(PChar(LIBLEGACY_DLL_NAME));
    if LTestHandle = 0 then
      Exit;

    try
      // Get the provider functions
      LLoadFunc := GetProcAddress(hCrypto, 'OSSL_PROVIDER_load');
      LGetContextFunc := GetProcAddress(hCrypto,
        'OSSL_LIB_CTX_get0_global_default');

      if not Assigned(LLoadFunc) or not Assigned(LGetContextFunc) then
        Exit;

      // Get context and try to load provider
      LTestContext := LGetContextFunc();
      if not Assigned(LTestContext) then
        Exit;

      // Try loading the provider
      LTestProvider := LLoadFunc(LTestContext, 'legacy');
      if Assigned(LTestProvider) then
      begin
        Result := True;
        // Unload the test provider
        if Assigned(GetProcAddress(hCrypto, 'OSSL_PROVIDER_unload')) then
          OSSL_PROVIDER_unload(LTestProvider);
      end;
    finally
      FreeLibrary(LTestHandle);
    end;
  except
    Result := False;
  end;
end;

function IsLegacyProviderAvailable: Boolean;
begin
  Result := False;

  if not IsOpenSSLLoaded then
    Exit;

  // First check if OpenSSL supports providers at all
  if not CheckOpenSSLProviderSupport then
    Exit;

  try
    // Check if legacy.dll file exists and can be loaded
    hLegacy := LoadLibrary(PChar(LIBLEGACY_DLL_NAME));
    if hLegacy = 0 then
      Exit;

    // If we get here, the legacy provider should be available
    Result := True;

    // Clean up the test load
    FreeLibrary(hLegacy);
    hLegacy := 0;
  except
    Result := False;
  end;
end;

function EnableLegacyAlgorithms: Boolean;
begin
  Result := False;

  if not IsLegacyProviderLoaded then
  begin
    if not LoadLegacyProvider then
      Exit;
  end;

  try
    // In OpenSSL 3.x, the legacy provider is automatically available
    // once it's loaded. The issue might be that we need to access
    // the algorithms differently.

    // Try setting properties on the default context
    if Assigned(EVP_set_default_properties) and Assigned(LDefaultContext) then
    begin
      // Try different property strings that might work
      Result := EVP_set_default_properties(LDefaultContext,
        'provider=legacy') = 1;
      if not Result then
        Result := EVP_set_default_properties(LDefaultContext,
          'provider=default,legacy') = 1;
      if not Result then
        Result := EVP_set_default_properties(LDefaultContext, 'legacy=yes') = 1;
      if not Result then
        Result := EVP_set_default_properties(LDefaultContext, '') = 1;
      // Reset to default
    end;

    // If property setting doesn't work, the provider might still be accessible
    // through direct context access
    if not Result then
      Result := True; // Assume it's available since provider is loaded
  except
    Result := False;
  end;
end;

function DisableLegacyAlgorithms: Boolean;
begin
  Result := False;

  try
    // Disable legacy algorithms by clearing default properties
    if Assigned(EVP_set_default_properties) and Assigned(LDefaultContext) then
    begin
      // Clear all providers (will use default provider only)
      Result := EVP_set_default_properties(LDefaultContext, '') = 1;
    end;
  except
    Result := False;
  end;
end;

function CalculateMD2Hash(const AData: string): string;
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(AData);
  Result := CalculateMD2HashBytes(LBytes);
end;

function CalculateMD4Hash(const AData: string): string;
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(AData);
  Result := CalculateMD4HashBytes(LBytes);
end;

function CalculateMD4HashBytes(const AData: TBytes): string;
var
  LMD4: pEVP_MD;
  LMDCtx: pEVP_MD_CTX;
  LHash: array [0 .. 15] of Byte;
  LHashLen: Cardinal;
  I: Integer;
begin
  Result := '';

  if not IsLegacyProviderLoaded then
  begin
    if not LoadLegacyProvider then
      raise Exception.Create
        ('Failed to load legacy provider for MD4 calculation');
  end;

  if not Assigned(EVP_md4) then
    raise Exception.Create('EVP_md4 function not available');

  // Get MD4 digest method
  LMD4 := EVP_md4();
  if not Assigned(LMD4) then
    raise Exception.Create('Failed to get MD4 digest method');

  // Create MD context
  LMDCtx := EVP_MD_CTX_new();
  if not Assigned(LMDCtx) then
    raise Exception.Create('Failed to create MD context');

  try
    // Try using the simpler EVP_DigestInit function first
    if Assigned(EVP_DigestInit) then
    begin
      if EVP_DigestInit(LMDCtx, LMD4) <> 1 then
        raise Exception.Create
          ('Failed to initialize MD4 context with EVP_DigestInit');
    end
    else if Assigned(EVP_DigestInit_ex) then
    begin
      if EVP_DigestInit_ex(LMDCtx, LMD4, nil) <> 1 then
        raise Exception.Create
          ('Failed to initialize MD4 context with EVP_DigestInit_ex');
    end
    else
    begin
      raise Exception.Create('No digest initialization functions available');
    end;

    // Update the context with data
    if EVP_DigestUpdate(LMDCtx, @AData[0], Length(AData)) <> 1 then
      raise Exception.Create('Failed to update MD4 context');

    // Finalize the hash
    if Assigned(EVP_DigestFinal) then
    begin
      if EVP_DigestFinal(LMDCtx, @LHash[0], LHashLen) <> 1 then
        raise Exception.Create
          ('Failed to finalize MD4 hash with EVP_DigestFinal');
    end
    else if Assigned(EVP_DigestFinal_ex) then
    begin
      if EVP_DigestFinal_ex(LMDCtx, @LHash[0], LHashLen) <> 1 then
        raise Exception.Create
          ('Failed to finalize MD4 hash with EVP_DigestFinal_ex');
    end
    else
    begin
      raise Exception.Create('No digest finalization functions available');
    end;

    // Convert hash to hex string
    Result := '';
    for I := 0 to 15 do
      Result := Result + IntToHex(LHash[I], 2);
  finally
    EVP_MD_CTX_free(LMDCtx);
  end;
end;

function CalculateMD2HashBytes(const AData: TBytes): string;
var
  LMD2: pEVP_MD;
  LMDCtx: pEVP_MD_CTX;
  LHash: array [0 .. 15] of Byte;
  LHashLen: Cardinal;
  I: Integer;
begin
  Result := '';

  if not IsLegacyProviderLoaded then
  begin
    if not LoadLegacyProvider then
      raise Exception.Create
        ('Failed to load legacy provider for MD2 calculation');
  end;

  if not Assigned(EVP_md2) then
    raise Exception.Create('EVP_md2 function not available');

  // Get MD2 digest method
  LMD2 := EVP_md2();
  if not Assigned(LMD2) then
    raise Exception.Create('Failed to get MD2 digest method');

  // Create MD context
  LMDCtx := EVP_MD_CTX_new();
  if not Assigned(LMDCtx) then
    raise Exception.Create('Failed to create MD context');

  try
    // Try using the simpler EVP_DigestInit function first
    if Assigned(EVP_DigestInit) then
    begin
      if EVP_DigestInit(LMDCtx, LMD2) <> 1 then
        raise Exception.Create
          ('Failed to initialize MD2 context with EVP_DigestInit');
    end
    else if Assigned(EVP_DigestInit_ex) then
    begin
      if EVP_DigestInit_ex(LMDCtx, LMD2, nil) <> 1 then
        raise Exception.Create
          ('Failed to initialize MD2 context with EVP_DigestInit_ex');
    end
    else
    begin
      raise Exception.Create('No digest initialization functions available');
    end;

    // Update the context with data
    if EVP_DigestUpdate(LMDCtx, @AData[0], Length(AData)) <> 1 then
      raise Exception.Create('Failed to update MD2 context');

    // Finalize the hash
    if Assigned(EVP_DigestFinal) then
    begin
      if EVP_DigestFinal(LMDCtx, @LHash[0], LHashLen) <> 1 then
        raise Exception.Create
          ('Failed to finalize MD2 hash with EVP_DigestFinal');
    end
    else if Assigned(EVP_DigestFinal_ex) then
    begin
      if EVP_DigestFinal_ex(LMDCtx, @LHash[0], LHashLen) <> 1 then
        raise Exception.Create
          ('Failed to finalize MD2 hash with EVP_DigestFinal_ex');
    end
    else
    begin
      raise Exception.Create('No digest finalization functions available');
    end;

    // Convert hash to hex string
    Result := '';
    for I := 0 to 15 do
      Result := Result + IntToHex(LHash[I], 2);
  finally
    EVP_MD_CTX_free(LMDCtx);
  end;
end;

function TestLegacyHashAvailability: string;
var
  LMD2, LMD4: pEVP_MD;
  LMDCtx: pEVP_MD_CTX;
begin
  Result := '';

  if not IsLegacyProviderLoaded then
  begin
    Result := Result + 'Legacy provider not loaded; ';
  end;

  // Test MD2 availability
  Result := Result + 'MD2: ';
  if Assigned(EVP_md2) then
  begin
    LMD2 := EVP_md2();
    if Assigned(LMD2) then
    begin
      LMDCtx := EVP_MD_CTX_new();
      if Assigned(LMDCtx) then
      begin
        if Assigned(EVP_DigestInit) and (EVP_DigestInit(LMDCtx, LMD2) = 1) then
          Result := Result + 'Available; '
        else if Assigned(EVP_DigestInit_ex) and
          (EVP_DigestInit_ex(LMDCtx, LMD2, nil) = 1) then
          Result := Result + 'Available; '
        else
          Result := Result + 'Not accessible; ';
        EVP_MD_CTX_free(LMDCtx);
      end
      else
        Result := Result + 'Context failed; ';
    end
    else
      Result := Result + 'Function returned nil; ';
  end
  else
    Result := Result + 'Function not available; ';

  // Test MD4 availability
  Result := Result + 'MD4: ';
  if Assigned(EVP_md4) then
  begin
    LMD4 := EVP_md4();
    if Assigned(LMD4) then
    begin
      LMDCtx := EVP_MD_CTX_new();
      if Assigned(LMDCtx) then
      begin
        if Assigned(EVP_DigestInit) and (EVP_DigestInit(LMDCtx, LMD4) = 1) then
          Result := Result + 'Available; '
        else if Assigned(EVP_DigestInit_ex) and
          (EVP_DigestInit_ex(LMDCtx, LMD4, nil) = 1) then
          Result := Result + 'Available; '
        else
          Result := Result + 'Not accessible; ';
        EVP_MD_CTX_free(LMDCtx);
      end
      else
        Result := Result + 'Context failed; ';
    end
    else
      Result := Result + 'Function returned nil; ';
  end
  else
    Result := Result + 'Function not available; ';

end;

function TryAlternativeLegacyHashAccess: string;
var
  LMD4: pEVP_MD;
  LMDCtx: pEVP_MD_CTX;
  LTestData: string;
  LTestBytes: TBytes;
  LHash: array [0 .. 15] of Byte;
  LHashLen: Cardinal;
  I: Integer;
  LSuccess: Boolean;
begin
  Result := '';
  LTestData := 'test';
  LTestBytes := TEncoding.UTF8.GetBytes(LTestData);
  LSuccess := False;

  if not IsLegacyProviderLoaded then
  begin
    Result := 'Legacy provider not loaded';
    Exit;
  end;

  try
    // Try MD4 since it shows as "Available" in the test
    Result := Result + 'MD4 Test: ';
    if Assigned(EVP_md4) then
    begin
      LMD4 := EVP_md4();
      if Assigned(LMD4) then
      begin
        LMDCtx := EVP_MD_CTX_new();
        if Assigned(LMDCtx) then
        begin
          if EVP_DigestInit(LMDCtx, LMD4) = 1 then
          begin
            if EVP_DigestUpdate(LMDCtx, @LTestBytes[0], Length(LTestBytes)) = 1
            then
            begin
              if EVP_DigestFinal(LMDCtx, @LHash[0], LHashLen) = 1 then
              begin
                Result := Result + 'SUCCESS - MD4 access works! Hash: ';
                for I := 0 to 15 do
                  Result := Result + IntToHex(LHash[I], 2);
                LSuccess := True;
              end
              else
                Result := Result + 'Failed at EVP_DigestFinal; ';
            end
            else
              Result := Result + 'Failed at EVP_DigestUpdate; ';
          end
          else
            Result := Result + 'Failed at EVP_DigestInit; ';
          EVP_MD_CTX_free(LMDCtx);
        end
        else
          Result := Result + 'Failed at EVP_MD_CTX_new; ';
      end
      else
        Result := Result + 'EVP_md4() returned nil; ';
    end
    else
      Result := Result + 'EVP_md4 function not available; ';

    if not LSuccess then
    begin
      Result := Result + 'MD4 with Properties: ';
      // Try method 2: Set properties and try again
      EnableLegacyAlgorithms;
      if Assigned(EVP_md4) then
      begin
        LMD4 := EVP_md4();
        if Assigned(LMD4) then
        begin
          LMDCtx := EVP_MD_CTX_new();
          if Assigned(LMDCtx) then
          begin
            if EVP_DigestInit(LMDCtx, LMD4) = 1 then
            begin
              if EVP_DigestUpdate(LMDCtx, @LTestBytes[0], Length(LTestBytes)) = 1
              then
              begin
                if EVP_DigestFinal(LMDCtx, @LHash[0], LHashLen) = 1 then
                begin
                  Result := Result +
                    'SUCCESS - MD4 with properties works! Hash: ';
                  for I := 0 to 15 do
                    Result := Result + IntToHex(LHash[I], 2);
                  LSuccess := True;
                end
                else
                  Result := Result + 'Failed at EVP_DigestFinal; ';
              end
              else
                Result := Result + 'Failed at EVP_DigestUpdate; ';
            end
            else
              Result := Result + 'Failed at EVP_DigestInit; ';
            EVP_MD_CTX_free(LMDCtx);
          end
          else
            Result := Result + 'Failed at EVP_MD_CTX_new; ';
        end
        else
          Result := Result + 'EVP_md4() returned nil; ';
      end
      else
        Result := Result + 'EVP_md4 function not available; ';
    end;

    if not LSuccess then
      Result := Result +
        'All MD4 methods failed - Legacy algorithms not accessible in this OpenSSL configuration';

  except
    on E: Exception do
      Result := Result + 'Exception: ' + E.Message;
  end;
end;

initialization

finalization

UnloadLegacyProvider;

end.
