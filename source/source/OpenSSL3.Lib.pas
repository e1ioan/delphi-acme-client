unit OpenSSL3.Lib;

interface

uses
  Winapi.Windows, System.SysUtils;

const
{$IFDEF WIN64}
  LIBCRYPTO_DLL_NAME = 'libcrypto-3-x64.dll';
  LIBSSL_DLL_NAME = 'libssl-3-x64.dll';
{$ELSE}
  LIBCRYPTO_DLL_NAME = 'libcrypto-3.dll';
  LIBSSL_DLL_NAME = 'libssl-3.dll';
{$ENDIF}
  // OpenSSL constants
  MBSTRING_ASC = $1001;
  NID_subject_alt_name = 85;
  RSA_F4 = $10001;

  // BIO types
  BIO_CTRL_PENDING = 10;
  BIO_C_SET_BUF_MEM_EOF_RETURN = 130;

type
  // OpenSSL pointer types
  PBIGNUM = Pointer;
  pRSA = Pointer;
  pEVP_PKEY = Pointer;
  pEVP_MD_CTX = Pointer;
  pEVP_MD = Pointer;
  pBIO = Pointer;
  pBIO_METHOD = Pointer;
  pX509 = Pointer;
  pX509_REQ = Pointer;
  pX509_NAME = Pointer;
  pX509_EXTENSION = Pointer;
  pASN1_TIME = Pointer;
  pSSL_CTX = Pointer;
  pSSL = Pointer;
  PSTACK = Pointer;
  pENGINE = Pointer;

  // Callback types
  TPemPasswordCallback = function(ABuf: PAnsiChar; ASize: Integer;
    ARwFlag: Integer; AUserData: Pointer): Integer; cdecl;
  TSkFreeFunc = procedure(AData: Pointer); cdecl;

var
  // Library handles
  hCrypto: HMODULE = 0;
  hSSL: HMODULE = 0;

  // BIGNUM functions
  BN_new: function: PBIGNUM;
cdecl = nil;
BN_free:
procedure(ABn: PBIGNUM);
cdecl = nil;
BN_set_word:
function(ABn: PBIGNUM; AWord: Cardinal): Integer;
cdecl = nil;
BN_num_bits:
function(ABn: PBIGNUM): Integer;
cdecl = nil;
BN_bn2bin:
function(ABn: PBIGNUM; ATo: Pointer): Integer;
cdecl = nil;

// RSA functions
RSA_new:
function: pRSA;
cdecl = nil;
RSA_free:
procedure(ARsa: pRSA);
cdecl = nil;
RSA_generate_key_ex:
function(ARsa: pRSA; ABits: Integer; AE: PBIGNUM; ACb: Pointer): Integer;
cdecl = nil;
RSA_size:
function(ARsa: pRSA): Integer;
cdecl = nil;

// EVP PKEY functions
EVP_PKEY_new:
function: pEVP_PKEY;
cdecl = nil;
EVP_PKEY_free:
procedure(APkey: pEVP_PKEY);
cdecl = nil;
EVP_PKEY_assign_RSA:
function(APkey: pEVP_PKEY; ARsa: pRSA): Integer;
cdecl = nil;
EVP_PKEY_get1_RSA:
function(APkey: pEVP_PKEY): pRSA;
cdecl = nil;
EVP_PKEY_set1_RSA:
function(APkey: pEVP_PKEY; ARsa: pRSA): Integer;
cdecl = nil;

// EVP digest functions
EVP_sha256:
function: pEVP_MD;
cdecl = nil;
EVP_MD_CTX_new:
function: pEVP_MD_CTX;
cdecl = nil;
EVP_MD_CTX_free:
procedure(ACtx: pEVP_MD_CTX);
cdecl = nil;
EVP_DigestSignInit:
function(ACtx: pEVP_MD_CTX; APctx: Pointer; AType: pEVP_MD; AE: pENGINE;
  APkey: pEVP_PKEY): Integer;
cdecl = nil;
EVP_DigestSignUpdate:
function(ACtx: pEVP_MD_CTX; AData: Pointer; ACount: NativeUInt): Integer;
cdecl = nil;
EVP_DigestSignFinal:
function(ACtx: pEVP_MD_CTX; ASig: Pointer; var ASigLen: NativeUInt): Integer;
cdecl = nil;

// BIO functions
BIO_new:
function(AMethod: pBIO_METHOD): pBIO;
cdecl = nil;
BIO_free:
function(ABio: pBIO): Integer;
cdecl = nil;
BIO_s_mem:
function: pBIO_METHOD;
cdecl = nil;
BIO_new_file:
function(AFileName: PAnsiChar; AMode: PAnsiChar): pBIO;
cdecl = nil;
BIO_new_mem_buf:
function(ABuf: Pointer; ALen: Integer): pBIO;
cdecl = nil;
BIO_read:
function(ABio: pBIO; AData: Pointer; ALen: Integer): Integer;
cdecl = nil;
BIO_write:
function(ABio: pBIO; AData: Pointer; ALen: Integer): Integer;
cdecl = nil;
BIO_ctrl:
function(ABio: pBIO; ACmd: Integer; ALarg: LongInt; AParg: Pointer): LongInt;
cdecl = nil;

// PEM functions
PEM_write_bio_PrivateKey:
function(ABio: pBIO; APkey: pEVP_PKEY; AEnc: pEVP_MD; AKstr: PAnsiChar;
  AKlen: Integer; ACb: TPemPasswordCallback; AU: Pointer): Integer;
cdecl = nil;
PEM_read_bio_PrivateKey:
function(ABio: pBIO; AX: Pointer; ACb: TPemPasswordCallback; AU: Pointer)
  : pEVP_PKEY;
cdecl = nil;
PEM_write_bio_X509_REQ:
function(ABio: pBIO; AReq: pX509_REQ): Integer;
cdecl = nil;
PEM_read_bio_X509_REQ:
function(ABio: pBIO; AReq: Pointer; ACb: TPemPasswordCallback; AU: Pointer)
  : pX509_REQ;
cdecl = nil;

// X509 Certificate functions
PEM_read_bio_X509:
function(ABio: pBIO; AX: Pointer; ACb: TPemPasswordCallback;
  AU: Pointer): pX509;
cdecl = nil;
X509_free:
procedure(AX: pX509);
cdecl = nil;
X509_get0_notBefore:
function(AX: pX509): pASN1_TIME;
cdecl = nil;
X509_get0_notAfter:
function(AX: pX509): pASN1_TIME;
cdecl = nil;

// ASN1_TIME functions
ASN1_TIME_to_tm:
function(ATime: pASN1_TIME; ATm: Pointer): Integer;
cdecl = nil;
ASN1_TIME_print:
function(ABio: pBIO; ATime: pASN1_TIME): Integer;
cdecl = nil;

// X509 functions
X509_REQ_new:
function: pX509_REQ;
cdecl = nil;
X509_REQ_free:
procedure(AReq: pX509_REQ);
cdecl = nil;
X509_REQ_get_subject_name:
function(AReq: pX509_REQ): pX509_NAME;
cdecl = nil;
X509_REQ_set_pubkey:
function(AReq: pX509_REQ; APkey: pEVP_PKEY): Integer;
cdecl = nil;
X509_REQ_sign:
function(AReq: pX509_REQ; APkey: pEVP_PKEY; AMd: pEVP_MD): Integer;
cdecl = nil;
X509_REQ_add_extensions:
function(AReq: pX509_REQ; AExts: PSTACK): Integer;
cdecl = nil;
X509_NAME_add_entry_by_txt:
function(AName: pX509_NAME; AField: PAnsiChar; AType: Integer;
  ABytes: PAnsiChar; ALen: Integer; ALoc: Integer; ASet: Integer): Integer;
cdecl = nil;
X509_EXTENSION_free:
procedure(AExt: pX509_EXTENSION);
cdecl = nil;
X509V3_EXT_conf_nid:
function(AConf: Pointer; ACtx: Pointer; AExtNid: Integer; AValue: PAnsiChar)
  : pX509_EXTENSION;
cdecl = nil;
i2d_X509_REQ:
function(AReq: pX509_REQ; APpout: Pointer): Integer;
cdecl = nil;
i2d_PUBKEY_bio:
function(ABio: pBIO; APkey: pEVP_PKEY): Integer;
cdecl = nil;

// Stack (OPENSSL_sk) functions
OPENSSL_sk_new_null:
function: PSTACK;
cdecl = nil;
OPENSSL_sk_push:
function(ASt: PSTACK; AData: Pointer): Integer;
cdecl = nil;
OPENSSL_sk_pop_free:
procedure(ASt: PSTACK; AFunc: TSkFreeFunc);
cdecl = nil;
OPENSSL_sk_free:
procedure(ASt: PSTACK);
cdecl = nil;

// Additional EVP PKEY functions
EVP_PKEY_print_private:
function(ABio: pBIO; APkey: pEVP_PKEY; AIndent: Integer;
  APctx: Pointer): Integer;
cdecl = nil;
EVP_PKEY_get_bn_param:
function(APkey: pEVP_PKEY; AKeyName: PAnsiChar; ABn: Pointer): Integer;
cdecl = nil;

// Library management functions
function LoadOpenSSLLibraryEx: Boolean;
procedure UnLoadOpenSSLLibraryEx;
function IsOpenSSLLoaded: Boolean;
function GetOpenSSLVersion: string;

// Helper functions
function BIOPending(ABio: pBIO): Integer; inline;
function BIOCtrlPending(ABio: pBIO): Integer; inline;
function BN_num_bytes(ABn: PBIGNUM): Integer; inline;

implementation

var
  LOpenSSLLoaded: Boolean = False;

function BIOPending(ABio: pBIO): Integer;
begin
  Result := Integer(BIO_ctrl(ABio, BIO_CTRL_PENDING, 0, nil));
end;

function BIOCtrlPending(ABio: pBIO): Integer;
begin
  Result := BIOPending(ABio);
end;

function BN_num_bytes(ABn: PBIGNUM): Integer;
begin
  // Implementation of BN_num_bytes macro: ((BN_num_bits(a)+7)/8)
  Result := (BN_num_bits(ABn) + 7) div 8;
end;

function GetProcAddr(AModule: HMODULE; const AProcName: string): Pointer;
begin
  Result := GetProcAddress(AModule, PChar(AProcName));
  if Result = nil then
    raise Exception.CreateFmt('Failed to load function: %s', [AProcName]);
end;

function LoadOpenSSLLibraryEx: Boolean;
begin

  if LOpenSSLLoaded then
  begin
    Result := True;
    Exit;
  end;

  try
    // Load libcrypto-3.dll
    hCrypto := LoadLibrary(PChar(LIBCRYPTO_DLL_NAME));
    if hCrypto = 0 then
      raise Exception.CreateFmt('Failed to load %s', [LIBCRYPTO_DLL_NAME]);

    // Load libssl-3.dll
    hSSL := LoadLibrary(PChar(LIBSSL_DLL_NAME));
    if hSSL = 0 then
    begin
      FreeLibrary(hCrypto);
      hCrypto := 0;
      raise Exception.CreateFmt('Failed to load %s', [LIBSSL_DLL_NAME]);
    end;

    // Load BIGNUM functions
    BN_new := GetProcAddr(hCrypto, 'BN_new');
    BN_free := GetProcAddr(hCrypto, 'BN_free');
    BN_set_word := GetProcAddr(hCrypto, 'BN_set_word');
    BN_num_bits := GetProcAddr(hCrypto, 'BN_num_bits');
    BN_bn2bin := GetProcAddr(hCrypto, 'BN_bn2bin');

    // Load RSA functions
    RSA_new := GetProcAddr(hCrypto, 'RSA_new');
    RSA_free := GetProcAddr(hCrypto, 'RSA_free');
    RSA_generate_key_ex := GetProcAddr(hCrypto, 'RSA_generate_key_ex');
    RSA_size := GetProcAddr(hCrypto, 'RSA_size');

    // Load EVP PKEY functions
    EVP_PKEY_new := GetProcAddr(hCrypto, 'EVP_PKEY_new');
    EVP_PKEY_free := GetProcAddr(hCrypto, 'EVP_PKEY_free');
    EVP_PKEY_assign_RSA := GetProcAddr(hCrypto, 'EVP_PKEY_assign');
    EVP_PKEY_get1_RSA := GetProcAddr(hCrypto, 'EVP_PKEY_get1_RSA');
    EVP_PKEY_set1_RSA := GetProcAddr(hCrypto, 'EVP_PKEY_set1_RSA');
    EVP_PKEY_print_private := GetProcAddr(hCrypto, 'EVP_PKEY_print_private');
    EVP_PKEY_get_bn_param := GetProcAddr(hCrypto, 'EVP_PKEY_get_bn_param');

    // Load EVP digest functions
    EVP_sha256 := GetProcAddr(hCrypto, 'EVP_sha256');
    EVP_MD_CTX_new := GetProcAddr(hCrypto, 'EVP_MD_CTX_new');
    EVP_MD_CTX_free := GetProcAddr(hCrypto, 'EVP_MD_CTX_free');
    EVP_DigestSignInit := GetProcAddr(hCrypto, 'EVP_DigestSignInit');
    EVP_DigestSignUpdate := GetProcAddr(hCrypto, 'EVP_DigestSignUpdate');
    EVP_DigestSignFinal := GetProcAddr(hCrypto, 'EVP_DigestSignFinal');

    // Load BIO functions
    BIO_new := GetProcAddr(hCrypto, 'BIO_new');
    BIO_free := GetProcAddr(hCrypto, 'BIO_free');
    BIO_s_mem := GetProcAddr(hCrypto, 'BIO_s_mem');
    BIO_new_file := GetProcAddr(hCrypto, 'BIO_new_file');
    BIO_new_mem_buf := GetProcAddr(hCrypto, 'BIO_new_mem_buf');
    BIO_read := GetProcAddr(hCrypto, 'BIO_read');
    BIO_write := GetProcAddr(hCrypto, 'BIO_write');
    BIO_ctrl := GetProcAddr(hCrypto, 'BIO_ctrl');

    // Load PEM functions
    PEM_write_bio_PrivateKey := GetProcAddr(hCrypto,
      'PEM_write_bio_PrivateKey');
    PEM_read_bio_PrivateKey := GetProcAddr(hCrypto, 'PEM_read_bio_PrivateKey');
    PEM_write_bio_X509_REQ := GetProcAddr(hCrypto, 'PEM_write_bio_X509_REQ');
    PEM_read_bio_X509_REQ := GetProcAddr(hCrypto, 'PEM_read_bio_X509_REQ');

    // Load X509 certificate functions
    PEM_read_bio_X509 := GetProcAddr(hCrypto, 'PEM_read_bio_X509');
    X509_free := GetProcAddr(hCrypto, 'X509_free');
    X509_get0_notBefore := GetProcAddr(hCrypto, 'X509_get0_notBefore');
    X509_get0_notAfter := GetProcAddr(hCrypto, 'X509_get0_notAfter');

    // Load ASN1_TIME functions
    ASN1_TIME_to_tm := GetProcAddr(hCrypto, 'ASN1_TIME_to_tm');
    ASN1_TIME_print := GetProcAddr(hCrypto, 'ASN1_TIME_print');

    // Load X509 REQ functions
    X509_REQ_new := GetProcAddr(hCrypto, 'X509_REQ_new');
    X509_REQ_free := GetProcAddr(hCrypto, 'X509_REQ_free');
    X509_REQ_get_subject_name := GetProcAddr(hCrypto,
      'X509_REQ_get_subject_name');
    X509_REQ_set_pubkey := GetProcAddr(hCrypto, 'X509_REQ_set_pubkey');
    X509_REQ_sign := GetProcAddr(hCrypto, 'X509_REQ_sign');
    X509_REQ_add_extensions := GetProcAddr(hCrypto, 'X509_REQ_add_extensions');
    X509_NAME_add_entry_by_txt := GetProcAddr(hCrypto,
      'X509_NAME_add_entry_by_txt');
    X509_EXTENSION_free := GetProcAddr(hCrypto, 'X509_EXTENSION_free');
    X509V3_EXT_conf_nid := GetProcAddr(hCrypto, 'X509V3_EXT_conf_nid');
    i2d_X509_REQ := GetProcAddr(hCrypto, 'i2d_X509_REQ');
    i2d_PUBKEY_bio := GetProcAddr(hCrypto, 'i2d_PUBKEY_bio');

    // Load Stack functions
    OPENSSL_sk_new_null := GetProcAddr(hCrypto, 'OPENSSL_sk_new_null');
    OPENSSL_sk_push := GetProcAddr(hCrypto, 'OPENSSL_sk_push');
    OPENSSL_sk_pop_free := GetProcAddr(hCrypto, 'OPENSSL_sk_pop_free');
    OPENSSL_sk_free := GetProcAddr(hCrypto, 'OPENSSL_sk_free');

    LOpenSSLLoaded := True;
    Result := True;
  except
    on E: Exception do
    begin
      // Clean up on failure
      if hSSL <> 0 then
      begin
        FreeLibrary(hSSL);
        hSSL := 0;
      end;
      if hCrypto <> 0 then
      begin
        FreeLibrary(hCrypto);
        hCrypto := 0;
      end;
      raise Exception.CreateFmt('OpenSSL loading failed: %s', [E.Message]);
    end;
  end;
end;

procedure UnLoadOpenSSLLibraryEx;
begin
  if not LOpenSSLLoaded then
    Exit;

  // Clear all function pointers
  BN_new := nil;
  BN_free := nil;
  BN_set_word := nil;
  BN_num_bits := nil;
  BN_bn2bin := nil;

  RSA_new := nil;
  RSA_free := nil;
  RSA_generate_key_ex := nil;
  RSA_size := nil;

  EVP_PKEY_new := nil;
  EVP_PKEY_free := nil;
  EVP_PKEY_assign_RSA := nil;
  EVP_PKEY_get1_RSA := nil;
  EVP_PKEY_set1_RSA := nil;
  EVP_PKEY_print_private := nil;
  EVP_PKEY_get_bn_param := nil;

  EVP_sha256 := nil;
  EVP_MD_CTX_new := nil;
  EVP_MD_CTX_free := nil;
  EVP_DigestSignInit := nil;
  EVP_DigestSignUpdate := nil;
  EVP_DigestSignFinal := nil;

  BIO_new := nil;
  BIO_free := nil;
  BIO_s_mem := nil;
  BIO_new_file := nil;
  BIO_new_mem_buf := nil;
  BIO_read := nil;
  BIO_write := nil;
  BIO_ctrl := nil;

  PEM_write_bio_PrivateKey := nil;
  PEM_read_bio_PrivateKey := nil;
  PEM_write_bio_X509_REQ := nil;
  PEM_read_bio_X509_REQ := nil;

  PEM_read_bio_X509 := nil;
  X509_free := nil;
  X509_get0_notBefore := nil;
  X509_get0_notAfter := nil;
  ASN1_TIME_to_tm := nil;
  ASN1_TIME_print := nil;

  X509_REQ_new := nil;
  X509_REQ_free := nil;
  X509_REQ_get_subject_name := nil;
  X509_REQ_set_pubkey := nil;
  X509_REQ_sign := nil;
  X509_REQ_add_extensions := nil;
  X509_NAME_add_entry_by_txt := nil;
  X509_EXTENSION_free := nil;
  X509V3_EXT_conf_nid := nil;
  i2d_X509_REQ := nil;
  i2d_PUBKEY_bio := nil;

  OPENSSL_sk_new_null := nil;
  OPENSSL_sk_push := nil;
  OPENSSL_sk_pop_free := nil;
  OPENSSL_sk_free := nil;

  // Unload libraries
  if hSSL <> 0 then
  begin
    FreeLibrary(hSSL);
    hSSL := 0;
  end;

  if hCrypto <> 0 then
  begin
    FreeLibrary(hCrypto);
    hCrypto := 0;
  end;

  LOpenSSLLoaded := False;
end;

function IsOpenSSLLoaded: Boolean;
begin
  Result := LOpenSSLLoaded;
end;

function GetOpenSSLVersion: string;
type
  TOpenSSL_version_num = function: Cardinal; cdecl;
  TOpenSSL_version = function(AType: Integer): PAnsiChar; cdecl;
var
  LVersion: TOpenSSL_version;
  LVersionStr: PAnsiChar;
begin
  Result := 'Unknown';

  if not LOpenSSLLoaded then
    Exit;

  try
    LVersion := GetProcAddr(hCrypto, 'OpenSSL_version');
    if Assigned(LVersion) then
    begin
      LVersionStr := LVersion(0); // OPENSSL_VERSION
      Result := string(AnsiString(LVersionStr));
    end;
  except
    Result := 'Error retrieving version';
  end;
end;

initialization

finalization

UnLoadOpenSSLLibraryEx;

end.
