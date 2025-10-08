program ACMEHTTPServerDemo;

uses
  Vcl.Forms,
  HTTPServerDemoFormU in 'HTTPServerDemoFormU.pas' {HTTPServerDemoForm},
  ACME.Client in '..\source\ACME.Client.pas',
  ACME.IndyHTTPServer in '..\source\ACME.IndyHTTPServer.pas',
  ACME.Orders in '..\source\ACME.Orders.pas',
  ACME.Providers in '..\source\ACME.Providers.pas',
  ACME.Types in '..\source\ACME.Types.pas',
  OpenSSL3.CSRGenerator in '..\source\OpenSSL3.CSRGenerator.pas',
  OpenSSL3.Helper in '..\source\OpenSSL3.Helper.pas',
  OpenSSL3.Legacy in '..\source\OpenSSL3.Legacy.pas',
  OpenSSL3.Lib in '..\source\OpenSSL3.Lib.pas',
  OpenSSL3.Types in '..\source\OpenSSL3.Types.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(THTTPServerDemoForm, HTTPServerDemoForm);
  Application.Run;
end.

