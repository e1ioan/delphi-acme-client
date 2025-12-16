unit ACME.Types;

interface

uses
  System.Classes, System.SysUtils, System.JSON,
  System.Math, Winapi.Windows,
  IdSSLOpenSSL, IdSSLOpenSSLHeaders;

const
  ACME_DEFAULT_STORAGE_FOLDER = 'ACMEClient';
  ACME_DEFAULT_HTTP_PORT = 80;

type
  EAcmeError = class(Exception);

  TAcmeDirectory = record
  public
    NewNonce: string;
    NewAccount: string;
    NewOrder: string;
    RevokeCert: string;
    KeyChange: string;
  end;

  TAcmeProvider = record
    Id: string;
    Name: string;
    DirectoryUrl: string;
    Description: string;
    class function Create(const AId, AName, ADirectoryUrl, ADescription: string)
      : TAcmeProvider; static;
  end;

  TChallengeType = (ctHttp01, ctDns01);

  TChallengeOptions = record
    ChallengeType: TChallengeType;
    HTTPPort: integer;
  end;

  TWriteChallengeEvent = procedure(const AToken: string;
    const AKeyAuthorization: string; out AChallengeUrlPath: string) of object;

  TOnLog = procedure(ASender: TObject; AMessage: string) of object;
  TOnDNSChallenge = procedure(ASender: TObject;
    const ARecordName, ARecordValue: string) of object;

  TAcmeOrderState = record
    OrderUrl: string;
    FinalizeUrl: string;
    Status: string;
    Expires: string;
    Domains: TArray<string>;
    ChallengeType: TChallengeType;
    AuthUrls: TArray<string>;
    CertificateUrl: string;
    Created: TDateTime;
    HTTPPort: integer; // Port for HTTP-01 challenge (default 80)
    // Provider information
    ProviderId: string;
    ProviderDirectoryUrl: string;
    // CSR Subject details for seamless renewal
    CsrCountry: string;
    CsrState: string;
    CsrLocality: string;
    CsrOrganization: string;
    CsrOrganizationalUnit: string;
    CsrEmailAddress: string;
    CsrCommonName: string;
  end;

  TAcmeAccountState = record
    ProviderId: string;
    Email: string;
    Kid: string;
    DirectoryUrl: string;
    Created: TDateTime;
    PrivateKey: string; // Base64 encoded private key
  end;

  TAcmeObject = class(TObject)
  private
    FOnLog: TOnLog;
    procedure SetOnLog(const Value: TOnLog);
  protected
    procedure Log(AMessage: string);
    procedure Debug(AMessage: string);
  public
    property OnLog: TOnLog read FOnLog write SetOnLog;
  end;

function GetDefaultStorageFolder(AFolder: string = ''): string;
function CheckFolderExists(ADirectory: string; ACreate: boolean): boolean;

implementation

uses
  System.IOUtils;

{ TAcmeProvider }

function CheckFolderExists(ADirectory: string; ACreate: boolean): boolean;
begin
  try
    if ACreate then
    begin
      if not DirectoryExists(ADirectory) then
      begin
        ForceDirectories(ADirectory);
      end;
    end;
  finally
    Result := DirectoryExists(ADirectory);
  end;
end;

function GetDefaultStorageFolder(AFolder: string): string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, if AFolder.IsEmpty then ACME_DEFAULT_STORAGE_FOLDER else AFolder);
  Result := IncludeTrailingPathDelimiter(Result);
  CheckFolderExists(Result, true);
end;

class function TAcmeProvider.Create(const AId, AName, ADirectoryUrl,
  ADescription: string): TAcmeProvider;
begin
  Result.Id := AId;
  Result.Name := AName;
  Result.DirectoryUrl := ADirectoryUrl;
  Result.Description := ADescription;
end;

{ TAcmeObject }

procedure TAcmeObject.Debug(AMessage: string);
begin
{$IFDEF DEBUG}
  Log('[DEBUG]: ' + AMessage);
{$ENDIF}
end;

procedure TAcmeObject.Log(AMessage: string);
begin
  if ASsigned(FOnLog) then
    FOnLog(Self, AMessage);
end;

procedure TAcmeObject.SetOnLog(const Value: TOnLog);
begin
  FOnLog := Value;
end;

end.
