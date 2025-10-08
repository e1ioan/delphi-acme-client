unit ACME.DNSChallengeForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.UITypes, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Clipbrd, ACME.Orders;

type
  TACMEDNSChallengeForm = class(TForm)
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelCenter: TPanel;
    LabelInstructions: TLabel;
    PanelBottom: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    MemoInstructions: TMemo;
    GridPanel1: TGridPanel;
    Panel1: TPanel;
    Panel3: TPanel;
    ButtonCopyName: TButton;
    ButtonCopyBoth: TButton;
    Panel2: TPanel;
    ButtonCopyValue: TButton;
    Panel4: TPanel;
    ButtonVerifyDNS: TButton;
    LabelRecordName: TLabel;
    EditRecordName: TEdit;
    EditRecordType: TEdit;
    LabelRecordType: TLabel;
    EditRecordValue: TEdit;
    LabelRecordValue: TLabel;
    LabelStatus: TLabel;
    procedure ButtonCopyNameClick(Sender: TObject);
    procedure ButtonCopyValueClick(Sender: TObject);
    procedure ButtonCopyBothClick(Sender: TObject);
    procedure ButtonOKClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure ButtonVerifyDNSClick(Sender: TObject);
  private
    FRecordName: string;
    FRecordValue: string;
    FACMEOrders: TACMEOrders;
    procedure SetStatusMessage(const AMessage: string; ASuccess: Boolean);
    procedure UpdateInstructions;
  public
    class function ShowDNSChallenge(const ARecordName, ARecordValue: string;
      AACMEOrders: TACMEOrders = nil): Boolean;
    procedure SetChallengeDetails(const ARecordName, ARecordValue: string;
      AACMEOrders: TACMEOrders = nil);
  end;

implementation

{$R *.dfm}

class function TACMEDNSChallengeForm.ShowDNSChallenge(const ARecordName,
  ARecordValue: string; AACMEOrders: TACMEOrders = nil): Boolean;
var
  LForm: TACMEDNSChallengeForm;
begin
  LForm := TACMEDNSChallengeForm.Create(nil);
  try
    LForm.SetChallengeDetails(ARecordName, ARecordValue, AACMEOrders);
    Result := LForm.ShowModal = mrOk;
  finally
    LForm.Free;
  end;
end;

procedure TACMEDNSChallengeForm.UpdateInstructions;
begin
  MemoInstructions.Lines.Clear;
  MemoInstructions.Lines.Add('Instructions:');
  MemoInstructions.Lines.Add('');
  MemoInstructions.Lines.Add('1. Go to your DNS provider''s control panel');
  MemoInstructions.Lines.Add
    ('2. Create a new TXT record with the name and value shown above');
  MemoInstructions.Lines.Add
    ('3. Wait for DNS propagation (can take a few minutes to 24 hours)');
  MemoInstructions.Lines.Add
    ('4. Verify the record is active (Command: nslookup -type=TXT ' +
    FRecordName + ')');
  MemoInstructions.Lines.Add('5. Click OK to continue the validation process');
  MemoInstructions.Lines.Add('');
  MemoInstructions.Lines.Add('Click Cancel to abort the certificate creation.');

end;

procedure TACMEDNSChallengeForm.SetChallengeDetails(const ARecordName,
  ARecordValue: string; AACMEOrders: TACMEOrders = nil);
begin
  FRecordName := ARecordName;
  FRecordValue := ARecordValue;
  FACMEOrders := AACMEOrders;

  EditRecordName.Text := ARecordName;
  EditRecordType.Text := 'TXT';
  EditRecordValue.Text := ARecordValue;

  Caption := 'DNS-01 Challenge - ' + ARecordName;

  UpdateInstructions;

  // Enable verify button only if ACMEOrders is provided
  ButtonVerifyDNS.Enabled := Assigned(FACMEOrders);

  if not Assigned(FACMEOrders) then
    SetStatusMessage
      ('DNS validation not available (ACMEOrders not provided)', False)
  else
    SetStatusMessage
      ('Click "Verify DNS" to test your DNS record configuration', False);
end;

procedure TACMEDNSChallengeForm.SetStatusMessage(const AMessage: string;
  ASuccess: Boolean);
begin
  LabelStatus.Caption := AMessage;
  if ASuccess then
  begin
    LabelStatus.Font.Color := clGreen;
    LabelStatus.Font.Style := [fsBold];
  end
  else if Pos('ERROR', UpperCase(AMessage)) > 0 then
  begin
    LabelStatus.Font.Color := clRed;
    LabelStatus.Font.Style := [fsBold];
  end
  else
  begin
    LabelStatus.Font.Color := clWindowText;
    LabelStatus.Font.Style := [];
  end;
  Application.ProcessMessages;
end;

procedure TACMEDNSChallengeForm.ButtonVerifyDNSClick(Sender: TObject);
var
  LMessage: string;
begin
  if not Assigned(FACMEOrders) then
  begin
    SetStatusMessage('ERROR: DNS validation not available', False);
    Exit;
  end;

  SetStatusMessage('Verifying DNS record... Please wait...', False);
  ButtonVerifyDNS.Enabled := False;
  try
    if FACMEOrders.DNSChallengeValidate(FRecordName, FRecordValue) then
    begin
      SetStatusMessage
        ('SUCCESS: DNS TXT record is correctly configured!', True);
      ShowMessage('DNS validation successful!' + #13#10 +
        'The TXT record is correctly configured and propagated.' + #13#10#13#10
        + 'You can now click OK to continue with the ACME validation.');
    end
    else
    begin
      SetStatusMessage
        ('ERROR: DNS TXT record not found or incorrect value', False);

      LMessage := 'DNS validation failed!' + #13#10#13#10 +
        'The TXT record was not found or has an incorrect value.' + #13#10#13#10
        + 'Please check:' + #13#10 + '1. The record name is exactly: ' +
        FRecordName + #13#10 + '2. The record value is exactly: ' + FRecordValue
        + #13#10 + '3. DNS has propagated (can take up to 24 hours)' +
        #13#10#13#10 + 'You can manually test with: nslookup -type=TXT ' +
        FRecordName;

      MessageDlg(LMessage, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
    end;
  finally
    ButtonVerifyDNS.Enabled := True;
  end;
end;

procedure TACMEDNSChallengeForm.ButtonCopyNameClick(Sender: TObject);
begin
  Clipboard.AsText := FRecordName;
  ButtonCopyName.Caption := 'Copied!';

  // Reset button text after 1 second
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(1000);
      TThread.Synchronize(nil,
        procedure
        begin
          if Assigned(ButtonCopyName) then
            ButtonCopyName.Caption := 'Copy Name';
        end);
    end).Start;
end;

procedure TACMEDNSChallengeForm.ButtonCopyValueClick(Sender: TObject);
begin
  Clipboard.AsText := FRecordValue;
  ButtonCopyValue.Caption := 'Copied!';

  // Reset button text after 1 second
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(1000);
      TThread.Synchronize(nil,
        procedure
        begin
          if Assigned(ButtonCopyValue) then
            ButtonCopyValue.Caption := 'Copy Value';
        end);
    end).Start;
end;

procedure TACMEDNSChallengeForm.ButtonCopyBothClick(Sender: TObject);
var
  LText: string;
begin
  LText := 'Record Name: ' + FRecordName + #13#10 + 'Record Type: TXT' + #13#10
    + 'Record Value: ' + FRecordValue;

  Clipboard.AsText := LText;
  ButtonCopyBoth.Caption := 'Copied!';

  // Reset button text after 1 second
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(1000);
      TThread.Synchronize(nil,
        procedure
        begin
          if Assigned(ButtonCopyBoth) then
            ButtonCopyBoth.Caption := 'Copy All';
        end);
    end).Start;
end;

procedure TACMEDNSChallengeForm.ButtonOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TACMEDNSChallengeForm.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
