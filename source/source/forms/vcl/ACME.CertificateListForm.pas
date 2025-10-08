unit ACME.CertificateListForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, System.UITypes,
  ACME.Orders, ACME.Types;

type
  TCertificateListMode = (clmResume, clmRenew, clmAll);

  TACMECertificateListForm = class(TForm)
    ListView: TListView;
    PanelTop: TPanel;
    LabelTitle: TLabel;
    PanelBottom: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    ButtonDelete: TButton;
    LabelInstructions: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ButtonOKClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure ButtonDeleteClick(Sender: TObject);
    procedure ListViewDblClick(Sender: TObject);
    procedure ListViewCustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      var DefaultDraw: Boolean);
  private
    FACMEOrders: TACMEOrders;
    FMode: TCertificateListMode;
    FSelectedOrderFile: string;
    FAllowDelete: Boolean;
    procedure LoadCertificates;
  protected
    property ACMEOrders: TACMEOrders read FACMEOrders write FACMEOrders;
    property Mode: TCertificateListMode read FMode write FMode;
    property AllowDelete: Boolean read FAllowDelete write FAllowDelete;
    property SelectedOrderFile: string read FSelectedOrderFile;
  public
    class function SelectCertificate(AACMEOrders: TACMEOrders;
      AMode: TCertificateListMode; AAllowDelete: Boolean;
      out ASelectedOrderFile: string): Boolean;

  end;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.DateUtils;

class function TACMECertificateListForm.SelectCertificate
  (AACMEOrders: TACMEOrders; AMode: TCertificateListMode; AAllowDelete: Boolean;
  out ASelectedOrderFile: string): Boolean;
var
  LForm: TACMECertificateListForm;
begin
  Result := False;
  ASelectedOrderFile := '';

  LForm := TACMECertificateListForm.Create(nil);
  try
    LForm.ACMEOrders := AACMEOrders;
    LForm.Mode := AMode;
    LForm.AllowDelete := AAllowDelete;

    if LForm.ShowModal = mrOk then
    begin
      ASelectedOrderFile := LForm.SelectedOrderFile;
      Result := True;
    end;
  finally
    LForm.Free;
  end;
end;

procedure TACMECertificateListForm.FormCreate(Sender: TObject);
begin
  FMode := clmResume;
  FSelectedOrderFile := '';
  FAllowDelete := True;
end;

procedure TACMECertificateListForm.FormShow(Sender: TObject);
begin
  case FMode of
    clmResume:
      begin
        LabelTitle.Caption := 'Resume Certificate Order';
        LabelInstructions.Caption := 'Select an order to resume:';
      end;
    clmRenew:
      begin
        LabelTitle.Caption := 'Renew Certificate';
        LabelInstructions.Caption := 'Select a certificate to renew:';
      end;
  else
    begin
      LabelTitle.Caption := 'Certificates';
      LabelInstructions.Caption := 'Select a certificate:';
    end;
  end;

  // Show/hide delete button based on AllowDelete property
  ButtonDelete.Visible := FAllowDelete;

  LoadCertificates;
end;

procedure TACMECertificateListForm.LoadCertificates;
var
  LFiles: TArray<string>;
  LFile: string;
  LOrderState: TAcmeOrderState;
  LItem: TListItem;
  LCertFile: string;
  LCertExpiry: TDateTime;
  LExpiryStr: string;
  LDomainPrefix: string;
begin
  ListView.Items.Clear;

  if not Assigned(FACMEOrders) then
    Exit;

  if FMode = clmResume then
    LFiles := FACMEOrders.FindCertificateFiles(False) // All orders
  else
    LFiles := FACMEOrders.FindCertificateFiles(True); // Valid only

  for LFile in LFiles do
  begin
    try
      LOrderState := FACMEOrders.LoadOrderState
        (TPath.Combine(FACMEOrders.StorageFolder, LFile));

      LItem := ListView.Items.Add;
      LItem.Caption := string.Join(', ', LOrderState.Domains);
      LItem.SubItems.Add(LOrderState.Status);
      LItem.SubItems.Add(DateTimeToStr(LOrderState.Created));
      
      // Get actual certificate expiry from the certificate file (if it exists)
      LExpiryStr := 'N/A';
      if LowerCase(LOrderState.Status) = 'valid' then
      begin
        LDomainPrefix := StringReplace(LFile, 'order_', '', [rfIgnoreCase]);
        LDomainPrefix := StringReplace(LDomainPrefix, '.json', '', [rfIgnoreCase]);
        LCertFile := TPath.Combine(FACMEOrders.StorageFolder, 
          Format('certificate_%s.pem', [LDomainPrefix]));
        
        if TFile.Exists(LCertFile) then
        begin
          try
            LCertExpiry := FACMEOrders.GetCertificateExpiryDate(LCertFile);
            if LCertExpiry > 0 then
              LExpiryStr := DateTimeToStr(LCertExpiry);
          except
            // If we can't read the expiry, just show N/A
            LExpiryStr := 'Error';
          end;
        end;
      end;
      
      LItem.SubItems.Add(LExpiryStr);
      LItem.SubItems.Add(LOrderState.ProviderId);
      LItem.Data := Pointer(StrNew(PChar(LFile)));

      // Color code by status - store color as tag
      case LowerCase(LOrderState.Status).Chars[0] of
        'v':
          LItem.SubItems.Objects[0] := TObject(Integer(clWebMediumAquamarine));
        // valid
        'p':
          LItem.SubItems.Objects[0] := TObject(Integer(clWebTan)); // pending
        'r':
          LItem.SubItems.Objects[0] := TObject(Integer(clWebOrange)); // ready
        'i':
          LItem.SubItems.Objects[0] := TObject(Integer(clWebCrimson));
        // invalid
      else
        LItem.SubItems.Objects[0] := TObject(Integer(clGray));
      end;
    except
      on E: Exception do
      begin
        // Skip invalid order files
        Continue;
      end;
    end;
  end;

  ButtonOK.Enabled := ListView.Items.Count > 0;

  if ListView.Items.Count = 0 then
  begin
    if FMode = clmResume then
      ShowMessage('No orders available to resume.')
    else
      ShowMessage('No valid certificates available to renew.');
  end
  else if ListView.Items.Count > 0 then
    ListView.ItemIndex := 0;
end;

procedure TACMECertificateListForm.ButtonOKClick(Sender: TObject);
begin
  if ListView.ItemIndex >= 0 then
  begin
    FSelectedOrderFile :=
      StrPas(PChar(ListView.Items[ListView.ItemIndex].Data));
    ModalResult := mrOk;
  end
  else
    ShowMessage('Please select an order.');
end;

procedure TACMECertificateListForm.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TACMECertificateListForm.ButtonDeleteClick(Sender: TObject);
var
  LOrderFile: string;
  LOrderState: TAcmeOrderState;
  LDomainList: string;
begin
  if ListView.ItemIndex >= 0 then
  begin
    LOrderFile := StrPas(PChar(ListView.Items[ListView.ItemIndex].Data));

    // Load order to get domain info
    try
      LOrderState := FACMEOrders.LoadOrderState
        (TPath.Combine(FACMEOrders.StorageFolder, LOrderFile));
      LDomainList := string.Join(', ', LOrderState.Domains);
    except
      LDomainList := LOrderFile;
    end;

    if MessageDlg
      ('Are you sure you want to delete this order and all associated files?' +
      #13#10#13#10 + 'Domains: ' + LDomainList + #13#10 + 'Order: ' + LOrderFile
      + #13#10#13#10 + 'This will delete:' + #13#10 + '- Order file' + #13#10 +
      '- Private key' + #13#10 + '- Certificate (if exists)' + #13#10 +
      '- CSR file', mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      try
        FACMEOrders.DeleteOrder(LOrderFile);
        ShowMessage('Order deleted successfully.');
        LoadCertificates; // Reload the list
      except
        on E: Exception do
          ShowMessage('Failed to delete order: ' + E.Message);
      end;
    end;
  end
  else
    ShowMessage('Please select an order to delete.');
end;

procedure TACMECertificateListForm.ListViewDblClick(Sender: TObject);
begin
  if ListView.ItemIndex >= 0 then
    ButtonOKClick(Sender);
end;

procedure TACMECertificateListForm.ListViewCustomDrawSubItem
  (Sender: TCustomListView; Item: TListItem; SubItem: Integer;
  State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  // Color code the Status column (SubItem = 1 in the event, which is SubItems[0])
  if SubItem = 1 then
  begin
    if Item.SubItems.Count > 0 then
    begin
      if not(cdsFocused in State) then
      begin
        Sender.Canvas.Font.Color := TColor(Integer(Item.SubItems.Objects[0]));
        Sender.Canvas.Font.Style := [fsBold];
      end;
    end;
  end;
  DefaultDraw := True;
end;

end.
