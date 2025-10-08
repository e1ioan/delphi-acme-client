program ACMEClientGUI;

{$R 'version.res' 'version.rc'}

uses
  Vcl.Forms,
  ACMEClientMainFormU in 'ACMEClientMainFormU.pas' {ACMEClientMainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TACMEClientMainForm, ACMEClientMainForm);
  Application.Run;
end.

