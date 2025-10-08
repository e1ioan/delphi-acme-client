unit OpenSSL3.Types;

interface

uses
  System.Classes, System.SysUtils, System.JSON,
  System.Math, Winapi.Windows;

type
  EOpenSSL3Error = class(Exception);

  EOpenSSL3CsrError = class(EOpenSSL3Error);

  TCsrSubject = record
    Country: string; // C
    State: string; // ST
    Locality: string; // L
    Organization: string; // O
    OrganizationalUnit: string; // OU
    CommonName: string; // CN
    EmailAddress: string; // emailAddress
  end;

  TOnLog = procedure(ASender: TObject; AMessage: string) of object;

  TOpenSSL3Object = class(TObject)
  private
    FOnLog: TOnLog;
    procedure SetOnLog(const Value: TOnLog);
  protected
    procedure Log(AMessage: string);
    procedure Debug(AMessage: string);
  public
    property OnLog: TOnLog read FOnLog write SetOnLog;
  end;

implementation

{ TOpenSSL3Object }

procedure TOpenSSL3Object.Debug(AMessage: string);
begin
{$IFDEF DEBUG}
  Log('[DEBUG]: ' + AMessage);
{$ENDIF}
end;

procedure TOpenSSL3Object.Log(AMessage: string);
begin
  if ASsigned(FOnLog) then
    FOnLog(Self, AMessage);
end;

procedure TOpenSSL3Object.SetOnLog(const Value: TOnLog);
begin
  FOnLog := Value;
end;

end.
