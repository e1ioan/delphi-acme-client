object ACMEClientMainForm: TACMEClientMainForm
  Left = 0
  Top = 0
  Caption = 'Delphi ACME Certificate Manager'
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
    Height = 80
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object LabelTitle: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 794
      Height = 29
      Align = alTop
      Caption = 'Delphi ACME Certificate Manager'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -24
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitLeft = 16
      ExplicitTop = 16
      ExplicitWidth = 392
    end
    object LabelStoragePath: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 38
      Width = 794
      Height = 13
      Align = alTop
      Caption = 'Storage: ...'
      ExplicitLeft = 16
      ExplicitTop = 51
      ExplicitWidth = 57
    end
  end
  object PanelCenter: TPanel
    Left = 0
    Top = 80
    Width = 200
    Height = 497
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object ButtonNewCertificate: TButton
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 194
      Height = 41
      Align = alTop
      Caption = 'New Certificate'
      TabOrder = 0
      OnClick = ButtonNewCertificateClick
      ExplicitLeft = 16
      ExplicitTop = 24
      ExplicitWidth = 169
    end
    object ButtonResumeCertificate: TButton
      AlignWithMargins = True
      Left = 3
      Top = 50
      Width = 194
      Height = 41
      Align = alTop
      Caption = 'Resume Order'
      TabOrder = 1
      OnClick = ButtonResumeCertificateClick
      ExplicitLeft = 16
      ExplicitTop = 80
      ExplicitWidth = 169
    end
    object ButtonRenewCertificate: TButton
      AlignWithMargins = True
      Left = 3
      Top = 97
      Width = 194
      Height = 41
      Align = alTop
      Caption = 'Renew Certificate'
      TabOrder = 2
      OnClick = ButtonRenewCertificateClick
      ExplicitLeft = 16
      ExplicitTop = 136
      ExplicitWidth = 169
    end
    object ButtonAutoRenew: TButton
      AlignWithMargins = True
      Left = 3
      Top = 144
      Width = 194
      Height = 41
      Align = alTop
      Caption = 'Auto Renew All'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 3
      OnClick = ButtonAutoRenewClick
      ExplicitLeft = 16
      ExplicitTop = 192
      ExplicitWidth = 169
    end
    object ButtonExit: TButton
      AlignWithMargins = True
      Left = 3
      Top = 191
      Width = 194
      Height = 41
      Align = alTop
      Caption = 'Exit'
      TabOrder = 4
      OnClick = ButtonExitClick
      ExplicitLeft = 16
      ExplicitTop = 440
      ExplicitWidth = 169
    end
  end
  object MemoLog: TMemo
    Left = 200
    Top = 80
    Width = 600
    Height = 497
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Courier New'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 577
    Width = 800
    Height = 23
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object StatusBar: TStatusBar
      Left = 0
      Top = 0
      Width = 800
      Height = 23
      Panels = <>
      SimplePanel = True
    end
  end
end
