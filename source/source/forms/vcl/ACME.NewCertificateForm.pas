unit ACME.NewCertificateForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, System.UITypes,
  ACME.Orders, ACME.Providers, ACME.Types, OpenSSL3.Types, ACME.DNSChallengeForm;

type
  TACMENewCertificateForm = class(TForm)
    PageControl: TPageControl;
    TabSheetProvider: TTabSheet;
    TabSheetDomains: TTabSheet;
    TabSheetSubject: TTabSheet;
    TabSheetChallenge: TTabSheet;
    PanelBottom: TPanel;
    ButtonBack: TButton;
    ButtonNext: TButton;
    ButtonCancel: TButton;
    ComboBoxProvider: TComboBox;
    LabelProvider: TLabel;
    EditEmail: TEdit;
    LabelEmail: TLabel;
    CheckBoxTOS: TCheckBox;
    MemoDomains: TMemo;
    LabelDomains: TLabel;
    LabelDomainsHelp: TLabel;
    EditCountry: TEdit;
    LabelCountry: TLabel;
    EditState: TEdit;
    LabelState: TLabel;
    EditLocality: TEdit;
    LabelLocality: TLabel;
    EditOrganization: TEdit;
    LabelOrganization: TLabel;
    EditOrgUnit: TEdit;
    LabelOrgUnit: TLabel;
    EditSubjectEmail: TEdit;
    LabelSubjectEmail: TLabel;
    RadioGroupChallengeType: TRadioGroup;
    EditHTTPPort: TEdit;
    LabelHTTPPort: TLabel;
    LabelChallengeHelp: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ButtonNextClick(Sender: TObject);
    procedure ButtonBackClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure RadioGroupChallengeTypeClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
    procedure EditEmailExit(Sender: TObject);
  private
    FACMEOrders: TACMEOrders;
    procedure LoadProviders;
    function ValidateCurrentPage: Boolean;
    function GetSelectedProvider: TAcmeProvider;
    function GetDomains: TArray<string>;
    function GetCsrSubject: TCsrSubject;
    function GetChallengeOptions: TChallengeOptions;
    procedure ProcessNewCertificate;
    procedure OnHTTPChallengeContinue(ASender: TObject);
    procedure OnDNSChallengeContinue(ASender: TObject;
      const ARecordName, ARecordValue: string);
    function GetACMEProviders : TACMEProviders;
  public
    class function CreateNewCertificate(AACMEOrders: TACMEOrders): Boolean;
    property ACMEOrders: TACMEOrders read FACMEOrders write FACMEOrders;
    property ACMEProviders: TACMEProviders read GetACMEProviders;
  end;

implementation

{$R *.dfm}

class function TACMENewCertificateForm.CreateNewCertificate(AACMEOrders: TACMEOrders): Boolean;
var
  LForm: TACMENewCertificateForm;
begin
  LForm := TACMENewCertificateForm.Create(nil);
  try
    LForm.ACMEOrders := AACMEOrders;
    Result := LForm.ShowModal = mrOk;
  finally
    LForm.Free;
  end;
end;

procedure TACMENewCertificateForm.FormCreate(Sender: TObject);
begin
  PageControl.ActivePageIndex := 0;
  ButtonBack.Enabled := False;
  EditHTTPPort.Text := '80';
  EditHTTPPort.Enabled := True;
  MemoDomains.Lines.Clear;
end;

procedure TACMENewCertificateForm.FormShow(Sender: TObject);
begin
  LoadProviders;
end;

function TACMENewCertificateForm.GetACMEProviders : TACMEProviders;
begin
  Result := nil;
  if ASsigned(FACMEOrders) then
    begin
    Result := FACMEOrders.Providers;
    end;
end;

procedure TACMENewCertificateForm.LoadProviders;
var
  LProviders: TArray<TAcmeProvider>;
  LProvider: TAcmeProvider;
begin
  ComboBoxProvider.Items.Clear;
  if Assigned(ACMEProviders) then
  begin
    LProviders := ACMEProviders.GetKnownProviders;
    for LProvider in LProviders do
      ComboBoxProvider.Items.AddObject(LProvider.Name,
        TObject(Pointer(LProvider.Id)));

    if ComboBoxProvider.Items.Count > 0 then
      ComboBoxProvider.ItemIndex := 1; // Default to staging
  end;
end;

function TACMENewCertificateForm.ValidateCurrentPage: Boolean;
var
  LDomains: TArray<string>;
begin
  Result := True;

  case PageControl.ActivePageIndex of
    0: // Provider page
      begin
        if ComboBoxProvider.ItemIndex < 0 then
        begin
          ShowMessage('Please select an ACME provider');
          Result := False;
        end
        else if Trim(EditEmail.Text) = '' then
        begin
          ShowMessage('Please enter an email address');
          Result := False;
        end
        else if not CheckBoxTOS.Checked then
        begin
          ShowMessage('You must agree to the Terms of Service');
          Result := False;
        end;
      end;

    1: // Domains page
      begin
        LDomains := GetDomains;
        if Length(LDomains) = 0 then
        begin
          ShowMessage('Please enter at least one domain name');
          Result := False;
        end;
      end;

    2: // Subject page
      begin
        if Trim(EditCountry.Text) = '' then
        begin
          ShowMessage('Country is required');
          Result := False;
        end
        else if Trim(EditState.Text) = '' then
        begin
          ShowMessage('State/Province is required');
          Result := False;
        end
        else if Trim(EditLocality.Text) = '' then
        begin
          ShowMessage('City/Locality is required');
          Result := False;
        end
        else if Trim(EditOrganization.Text) = '' then
        begin
          ShowMessage('Organization is required');
          Result := False;
        end;
      end;

    3: // Challenge page
      begin
        if RadioGroupChallengeType.ItemIndex < 0 then
        begin
          ShowMessage('Please select a challenge type');
          Result := False;
        end
        else if (RadioGroupChallengeType.ItemIndex = 0) and
          (StrToIntDef(EditHTTPPort.Text, 0) <= 0) then
        begin
          ShowMessage('Please enter a valid HTTP port number');
          Result := False;
        end;
      end;
  end;
end;

procedure TACMENewCertificateForm.ButtonNextClick(Sender: TObject);
begin
  if not ValidateCurrentPage then
    Exit;

  if PageControl.ActivePageIndex < PageControl.PageCount - 1 then
  begin
    PageControl.ActivePageIndex := PageControl.ActivePageIndex + 1;
    ButtonBack.Enabled := True;

    if PageControl.ActivePageIndex = PageControl.PageCount - 1 then
      ButtonNext.Caption := 'Create Certificate';
  end
  else
  begin
    // Final page - process the certificate request
    ProcessNewCertificate;
  end;
end;

procedure TACMENewCertificateForm.EditEmailExit(Sender: TObject);
begin
  if (EditSubjectEmail.Text = '') then
    EditSubjectEmail.Text := EditEmail.Text;
end;

procedure TACMENewCertificateForm.PageControlChange(Sender: TObject);
begin
  // Update button states based on current page
  ButtonBack.Enabled := PageControl.ActivePageIndex > 0;

  if PageControl.ActivePageIndex = PageControl.PageCount - 1 then
    ButtonNext.Caption := 'Create Certificate'
  else
    ButtonNext.Caption := 'Next >';
end;

procedure TACMENewCertificateForm.ButtonBackClick(Sender: TObject);
begin
  if PageControl.ActivePageIndex > 0 then
  begin
    PageControl.ActivePageIndex := PageControl.ActivePageIndex - 1;
    ButtonNext.Caption := 'Next >';

    if PageControl.ActivePageIndex = 0 then
      ButtonBack.Enabled := False;
  end;
end;

procedure TACMENewCertificateForm.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TACMENewCertificateForm.RadioGroupChallengeTypeClick(Sender: TObject);
begin
  EditHTTPPort.Enabled := RadioGroupChallengeType.ItemIndex = 0; // HTTP-01
end;

function TACMENewCertificateForm.GetSelectedProvider: TAcmeProvider;
var
  LProviderId: string;
begin
  if ComboBoxProvider.ItemIndex >= 0 then
  begin
    LProviderId := string(ComboBoxProvider.Items.Objects
      [ComboBoxProvider.ItemIndex]);
    Result := ACMEProviders.GetProviderById(LProviderId);
  end
  else
  begin
    Result.Id := '';
    Result.Name := '';
    Result.DirectoryUrl := '';
    Result.Description := '';
  end;
end;

function TACMENewCertificateForm.GetDomains: TArray<string>;
var
  LI: Integer;
  LDomain: string;
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    for LI := 0 to MemoDomains.Lines.Count - 1 do
    begin
      LDomain := Trim(MemoDomains.Lines[LI]);
      if LDomain <> '' then
        LList.Add(LDomain);
    end;
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

function TACMENewCertificateForm.GetCsrSubject: TCsrSubject;
begin
  Result.Country := Trim(EditCountry.Text);
  Result.State := Trim(EditState.Text);
  Result.Locality := Trim(EditLocality.Text);
  Result.Organization := Trim(EditOrganization.Text);
  Result.OrganizationalUnit := Trim(EditOrgUnit.Text);
  Result.EmailAddress := Trim(EditSubjectEmail.Text);
  Result.CommonName := ''; // Will be auto-set to first domain by ACME.Orders
end;

function TACMENewCertificateForm.GetChallengeOptions: TChallengeOptions;
begin
  if RadioGroupChallengeType.ItemIndex = 0 then
    Result.ChallengeType := ctHttp01
  else
    Result.ChallengeType := ctDns01;

  Result.HTTPPort := StrToIntDef(EditHTTPPort.Text, 80);
end;

procedure TACMENewCertificateForm.OnHTTPChallengeContinue(ASender: TObject);
begin
  if MessageDlg
    ('HTTP-01 challenge is ready. Press OK when you are ready to start the validation.',
    mtInformation, [mbOK, mbCancel], 0) = mrCancel then
    Abort;
end;

procedure TACMENewCertificateForm.OnDNSChallengeContinue(ASender: TObject;
  const ARecordName, ARecordValue: string);
begin
  if not TACMEDNSChallengeForm.ShowDNSChallenge(ARecordName, ARecordValue, FACMEOrders) then
    Abort;
end;

procedure TACMENewCertificateForm.ProcessNewCertificate;
var
  LProvider: TAcmeProvider;
  LDomains: TArray<string>;
  LCsrSubject: TCsrSubject;
  LChallengeOptions: TChallengeOptions;
  LOrderFile: string;
begin
  LProvider := GetSelectedProvider;
  LDomains := GetDomains;
  LCsrSubject := GetCsrSubject;
  LChallengeOptions := GetChallengeOptions;

  // Set up temporary event handlers for this operation
  FACMEOrders.OnHTTPChallengeContinue := OnHTTPChallengeContinue;
  FACMEOrders.OnDNSChallengeContinue := OnDNSChallengeContinue;

  try
    if FACMEOrders.NewOrder(LProvider, Trim(EditEmail.Text), LDomains,
      LChallengeOptions, LCsrSubject, LOrderFile) then
    begin
      ShowMessage('Certificate created successfully!' + #13#10 + 'Order file: '
        + LOrderFile);
      ModalResult := mrOk;
    end
    else
    begin
      ShowMessage
        ('Failed to create certificate. Check the main window log for details.');
    end;
  finally
    // Clear event handlers
    FACMEOrders.OnHTTPChallengeContinue := nil;
    FACMEOrders.OnDNSChallengeContinue := nil;
  end;
end;

end.

