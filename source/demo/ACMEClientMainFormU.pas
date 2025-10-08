unit ACMEClientMainFormU;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, System.UITypes,
  ACME.Orders, ACME.Providers, ACME.Types;

type
  TACMEClientMainForm = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelCenter: TPanel;
    ButtonNewCertificate: TButton;
    ButtonResumeCertificate: TButton;
    ButtonRenewCertificate: TButton;
    ButtonAutoRenew: TButton;
    ButtonExit: TButton;
    MemoLog: TMemo;
    PanelBottom: TPanel;
    LabelStoragePath: TLabel;
    StatusBar: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonNewCertificateClick(Sender: TObject);
    procedure ButtonResumeCertificateClick(Sender: TObject);
    procedure ButtonRenewCertificateClick(Sender: TObject);
    procedure ButtonAutoRenewClick(Sender: TObject);
    procedure ButtonExitClick(Sender: TObject);
    procedure ButtonSettingsClick(Sender: TObject);
  private
    FACMEOrders: TACMEOrders;
    procedure OnLogEvent(ASender: TObject; AMessage: string);
    procedure OnHTTPChallengeContinue(ASender: TObject);
    procedure OnDNSChallengeContinue(ASender: TObject;
      const ARecordName, ARecordValue: string);
    procedure InitializeACME;
    function GetACMEProviders: TACMEProviders;
  public
    property ACMEOrders: TACMEOrders read FACMEOrders;
    property ACMEProviders: TACMEProviders read GetACMEProviders;
  end;

var
  ACMEClientMainForm: TACMEClientMainForm;

implementation

{$R *.dfm}

uses
  ACME.NewCertificateForm, ACME.CertificateListForm, ACME.DNSChallengeForm;

procedure TACMEClientMainForm.FormCreate(Sender: TObject);
begin
  InitializeACME;
  LabelStoragePath.Caption := 'Storage: ' + FACMEOrders.StorageFolder;
  MemoLog.Lines.Add('ACME Client GUI initialized');
  MemoLog.Lines.Add('Storage path: ' + FACMEOrders.StorageFolder);
  StatusBar.SimpleText := 'Ready';
end;

procedure TACMEClientMainForm.FormDestroy(Sender: TObject);
begin
  FACMEOrders.Free;
end;

function TACMEClientMainForm.GetACMEProviders: TACMEProviders;
begin
  Result := FACMEOrders.Providers;
end;

procedure TACMEClientMainForm.InitializeACME;
begin
  FACMEOrders := TACMEOrders.Create;
  FACMEOrders.OnLog := OnLogEvent;
  FACMEOrders.OnHTTPChallengeContinue := OnHTTPChallengeContinue;
  FACMEOrders.OnDNSChallengeContinue := OnDNSChallengeContinue;
end;

procedure TACMEClientMainForm.OnHTTPChallengeContinue(ASender: TObject);
begin
  if MessageDlg
    ('HTTP-01 challenge is ready. Press OK when you are ready to start the validation.',
    mtInformation, [mbOK, mbCancel], 0) = mrCancel then
    Abort;
end;

procedure TACMEClientMainForm.OnDNSChallengeContinue(ASender: TObject;
  const ARecordName, ARecordValue: string);
begin
  if not TACMEDNSChallengeForm.ShowDNSChallenge(ARecordName, ARecordValue,
    FACMEOrders) then
    Abort;
end;

procedure TACMEClientMainForm.OnLogEvent(ASender: TObject; AMessage: string);
begin
  MemoLog.Lines.Add(AMessage);
  Application.ProcessMessages;
end;

procedure TACMEClientMainForm.ButtonNewCertificateClick(Sender: TObject);
begin
  TACMENewCertificateForm.CreateNewCertificate(FACMEOrders);
end;

procedure TACMEClientMainForm.ButtonResumeCertificateClick(Sender: TObject);
var
  LSelectedOrderFile: string;
begin
  if TACMECertificateListForm.SelectCertificate(FACMEOrders, clmResume, True,
    LSelectedOrderFile) then
  begin
    MemoLog.Lines.Add('Resuming certificate order...');
    if FACMEOrders.ResumeExistingOrder(LSelectedOrderFile) then
      ShowMessage('Certificate order resumed successfully!')
    else
      ShowMessage('Failed to resume certificate order.');
  end;
end;

procedure TACMEClientMainForm.ButtonRenewCertificateClick(Sender: TObject);
var
  LSelectedOrderFile: string;
begin
  if TACMECertificateListForm.SelectCertificate(FACMEOrders, clmRenew, True,
    LSelectedOrderFile) then
  begin
    MemoLog.Lines.Add('Renewing certificate...');
    if FACMEOrders.RenewExistingCertificate(LSelectedOrderFile) then
      ShowMessage('Certificate renewed successfully!')
    else
      ShowMessage('Failed to renew certificate.');
  end;
end;

procedure TACMEClientMainForm.ButtonAutoRenewClick(Sender: TObject);
var
  LSuccess: TArray<string>;
  LFailed: TArray<string>;
  LMessage: string;
  LFile: string;
begin
  if MessageDlg('This will attempt to renew all valid certificates. Continue?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    MemoLog.Lines.Add('Starting auto-renewal process...');
    StatusBar.SimpleText := 'Processing...';
    Application.ProcessMessages;

    FACMEOrders.AutoRenew(LSuccess, LFailed);

    // Build summary message
    LMessage := Format('Auto-renewal complete:%s%s', [#13#10, #13#10]);
    LMessage := LMessage + Format('Successfully renewed: %d certificate(s)%s',
      [Length(LSuccess), #13#10]);
    LMessage := LMessage + Format('Failed: %d certificate(s)%s',
      [Length(LFailed), #13#10]);

    if Length(LSuccess) > 0 then
    begin
      LMessage := LMessage + #13#10 + 'Success:' + #13#10;
      for LFile in LSuccess do
        LMessage := LMessage + '  - ' + LFile + #13#10;
    end;

    if Length(LFailed) > 0 then
    begin
      LMessage := LMessage + #13#10 + 'Failed:' + #13#10;
      for LFile in LFailed do
        LMessage := LMessage + '  - ' + LFile + #13#10;
    end;

    StatusBar.SimpleText := Format('Complete: %d success, %d failed',
      [Length(LSuccess), Length(LFailed)]);
    ShowMessage(LMessage);
  end;
end;

procedure TACMEClientMainForm.ButtonSettingsClick(Sender: TObject);
begin
  ShowMessage('Settings dialog - To be implemented');
end;

procedure TACMEClientMainForm.ButtonExitClick(Sender: TObject);
begin
  Close;
end;

end.
