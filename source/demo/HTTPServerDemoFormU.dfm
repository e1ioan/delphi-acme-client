object HTTPServerDemoForm: THTTPServerDemoForm
  Left = 0
  Top = 0
  Caption = 'ACME HTTP Server Demo - TIdHTTPServer with SSL Management'
  ClientHeight = 600
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 13
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object LabelTitle: TLabel
      Left = 16
      Top = 16
      Width = 459
      Height = 23
      Caption = 'ACME HTTP Server Demo with SSL Management'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object PanelCenter: TPanel
    Left = 0
    Top = 60
    Width = 800
    Height = 517
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object GroupBoxServer: TGroupBox
      Left = 8
      Top = 8
      Width = 377
      Height = 121
      Caption = ' Server Configuration '
      TabOrder = 0
      object LabelPort: TLabel
        Left = 16
        Top = 28
        Width = 24
        Height = 13
        Caption = 'Port:'
      end
      object EditPort: TEdit
        Left = 56
        Top = 25
        Width = 73
        Height = 21
        TabOrder = 0
        Text = '8080'
      end
      object ButtonStartServer: TButton
        Left = 16
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Start Server'
        TabOrder = 2
        OnClick = ButtonStartServerClick
      end
      object ButtonStopServer: TButton
        Left = 127
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Stop Server'
        Enabled = False
        TabOrder = 3
        OnClick = ButtonStopServerClick
      end
      object CheckBoxSSL: TCheckBox
        Left = 16
        Top = 56
        Width = 113
        Height = 17
        Caption = 'Enable SSL/HTTPS'
        TabOrder = 1
        OnClick = CheckBoxSSLClick
      end
      object ButtonTestServer: TButton
        Left = 238
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Test Server'
        Enabled = False
        TabOrder = 4
        OnClick = ButtonTestServerClick
      end
    end
    object GroupBoxCertificate: TGroupBox
      Left = 391
      Top = 8
      Width = 401
      Height = 121
      Caption = ' SSL Certificate Management '
      TabOrder = 1
      object LabelOrderFile: TLabel
        Left = 16
        Top = 28
        Width = 51
        Height = 13
        Caption = 'Order File:'
      end
      object ComboBoxOrders: TComboBox
        Left = 88
        Top = 25
        Width = 217
        Height = 21
        Style = csDropDownList
        TabOrder = 1
      end
      object ButtonRefreshOrders: TButton
        Left = 311
        Top = 23
        Width = 75
        Height = 25
        Caption = 'Refresh'
        TabOrder = 0
        OnClick = ButtonRefreshOrdersClick
      end
      object ButtonConfigureSSL: TButton
        Left = 16
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Configure SSL'
        TabOrder = 3
        OnClick = ButtonConfigureSSLClick
      end
      object ButtonClearSSL: TButton
        Left = 127
        Top = 80
        Width = 105
        Height = 25
        Caption = 'Clear SSL'
        TabOrder = 4
        OnClick = ButtonClearSSLClick
      end
      object ButtonRenewCertificate: TButton
        Left = 238
        Top = 80
        Width = 148
        Height = 25
        Caption = 'Renew Certificate Now'
        TabOrder = 5
        OnClick = ButtonRenewCertificateClick
      end
      object ButtonVerifyCert: TButton
        Left = 16
        Top = 52
        Width = 105
        Height = 25
        Caption = 'Verify Certificate'
        TabOrder = 2
        OnClick = ButtonVerifyCertClick
      end
      object ButtonNewCertificate: TButton
        Left = 127
        Top = 52
        Width = 105
        Height = 25
        Caption = 'New Certificate'
        TabOrder = 6
        OnClick = ButtonNewCertificateClick
      end
    end
    object GroupBoxRenewal: TGroupBox
      Left = 8
      Top = 135
      Width = 784
      Height = 80
      Caption = ' Automatic Renewal '
      Enabled = False
      TabOrder = 2
      object LabelRenewalInterval: TLabel
        Left = 16
        Top = 28
        Width = 86
        Height = 13
        Caption = 'Renewal Interval:'
      end
      object LabelHours: TLabel
        Left = 183
        Top = 28
        Width = 27
        Height = 13
        Caption = 'hours'
      end
      object EditRenewalInterval: TEdit
        Left = 120
        Top = 25
        Width = 57
        Height = 21
        TabOrder = 1
        Text = '24'
      end
      object ButtonApplyInterval: TButton
        Left = 216
        Top = 23
        Width = 105
        Height = 25
        Caption = 'Apply Interval'
        TabOrder = 0
        OnClick = ButtonApplyIntervalClick
      end
      object CheckBoxAutoRenewal: TCheckBox
        Left = 16
        Top = 52
        Width = 305
        Height = 17
        Caption = 'Enable Automatic Renewal (runs in background thread)'
        TabOrder = 2
        OnClick = CheckBoxAutoRenewalClick
      end
    end
    object MemoLog: TMemo
      Left = 8
      Top = 221
      Width = 784
      Height = 288
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 3
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 577
    Width = 800
    Height = 23
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object StatusBar: TStatusBar
      Left = 0
      Top = 0
      Width = 800
      Height = 23
      Panels = <>
      SimplePanel = True
      SimpleText = 'Server Stopped'
    end
  end
end
