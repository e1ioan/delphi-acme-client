object ACMENewCertificateForm: TACMENewCertificateForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'New Certificate'
  ClientHeight = 450
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 13
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 600
    Height = 400
    ActivePage = TabSheetProvider
    Align = alClient
    TabOrder = 0
    OnChange = PageControlChange
    object TabSheetProvider: TTabSheet
      Caption = '1. Provider && Account'
      object LabelProvider: TLabel
        Left = 24
        Top = 24
        Width = 75
        Height = 13
        Caption = 'ACME Provider:'
      end
      object LabelEmail: TLabel
        Left = 24
        Top = 88
        Width = 70
        Height = 13
        Caption = 'Email Address:'
      end
      object ComboBoxProvider: TComboBox
        Left = 24
        Top = 43
        Width = 537
        Height = 21
        Style = csDropDownList
        TabOrder = 0
      end
      object EditEmail: TEdit
        Left = 24
        Top = 107
        Width = 537
        Height = 21
        TabOrder = 1
        OnExit = EditEmailExit
      end
      object CheckBoxTOS: TCheckBox
        Left = 24
        Top = 152
        Width = 537
        Height = 17
        Caption = 'I agree to the Terms of Service'
        TabOrder = 2
      end
    end
    object TabSheetDomains: TTabSheet
      Caption = '2. Domains'
      ImageIndex = 1
      object LabelDomains: TLabel
        Left = 24
        Top = 24
        Width = 141
        Height = 13
        Caption = 'Domain Names (one per line):'
      end
      object LabelDomainsHelp: TLabel
        Left = 24
        Top = 320
        Width = 336
        Height = 13
        Caption = 'Enter domain names (e.g., example.com or subdomain.example.com).'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
      end
      object MemoDomains: TMemo
        Left = 24
        Top = 43
        Width = 537
        Height = 262
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object TabSheetSubject: TTabSheet
      Caption = '3. Certificate Subject'
      ImageIndex = 2
      object LabelCountry: TLabel
        Left = 24
        Top = 24
        Width = 85
        Height = 13
        Caption = 'Country (2-char):'
      end
      object LabelState: TLabel
        Left = 24
        Top = 72
        Width = 75
        Height = 13
        Caption = 'State/Province:'
      end
      object LabelLocality: TLabel
        Left = 24
        Top = 120
        Width = 63
        Height = 13
        Caption = 'City/Locality:'
      end
      object LabelOrganization: TLabel
        Left = 24
        Top = 168
        Width = 65
        Height = 13
        Caption = 'Organization:'
      end
      object LabelOrgUnit: TLabel
        Left = 24
        Top = 216
        Width = 95
        Height = 13
        Caption = 'Organizational Unit:'
      end
      object LabelSubjectEmail: TLabel
        Left = 24
        Top = 264
        Width = 70
        Height = 13
        Caption = 'Email Address:'
      end
      object EditCountry: TEdit
        Left = 24
        Top = 43
        Width = 100
        Height = 21
        MaxLength = 2
        TabOrder = 0
      end
      object EditState: TEdit
        Left = 24
        Top = 91
        Width = 537
        Height = 21
        TabOrder = 1
      end
      object EditLocality: TEdit
        Left = 24
        Top = 139
        Width = 537
        Height = 21
        TabOrder = 2
      end
      object EditOrganization: TEdit
        Left = 24
        Top = 187
        Width = 537
        Height = 21
        TabOrder = 3
      end
      object EditOrgUnit: TEdit
        Left = 24
        Top = 235
        Width = 537
        Height = 21
        TabOrder = 4
      end
      object EditSubjectEmail: TEdit
        Left = 24
        Top = 283
        Width = 537
        Height = 21
        TabOrder = 5
      end
    end
    object TabSheetChallenge: TTabSheet
      Caption = '4. Challenge Type'
      ImageIndex = 3
      object LabelHTTPPort: TLabel
        Left = 24
        Top = 200
        Width = 52
        Height = 13
        Caption = 'HTTP Port:'
      end
      object LabelChallengeHelp: TLabel
        Left = 24
        Top = 280
        Width = 462
        Height = 26
        Caption = 
          'HTTP-01: Requires a web server on port 80 (or specified port) to' +
          ' serve a validation file.'#13#10'DNS-01: Requires adding a TXT record ' +
          'to your DNS zone. More flexible but requires DNS access.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
      object RadioGroupChallengeType: TRadioGroup
        Left = 24
        Top = 24
        Width = 537
        Height = 153
        Caption = ' Challenge Type '
        ItemIndex = 0
        Items.Strings = (
          'HTTP-01 Challenge (requires web server access)'
          'DNS-01 Challenge (requires DNS record creation)')
        TabOrder = 0
        OnClick = RadioGroupChallengeTypeClick
      end
      object EditHTTPPort: TEdit
        Left = 24
        Top = 219
        Width = 121
        Height = 21
        TabOrder = 1
        Text = '80'
      end
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 400
    Width = 600
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object ButtonBack: TButton
      AlignWithMargins = True
      Left = 260
      Top = 3
      Width = 90
      Height = 44
      Align = alRight
      Caption = '< Back'
      TabOrder = 0
      OnClick = ButtonBackClick
    end
    object ButtonNext: TButton
      AlignWithMargins = True
      Left = 356
      Top = 3
      Width = 145
      Height = 44
      Align = alRight
      Caption = 'Next >'
      Default = True
      TabOrder = 1
      OnClick = ButtonNextClick
    end
    object ButtonCancel: TButton
      AlignWithMargins = True
      Left = 507
      Top = 3
      Width = 90
      Height = 44
      Align = alRight
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 2
      OnClick = ButtonCancelClick
    end
  end
end
