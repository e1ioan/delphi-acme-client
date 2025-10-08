object ACMEDNSChallengeForm: TACMEDNSChallengeForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  Caption = 'DNS-01 Challenge Required'
  ClientHeight = 499
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 13
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object LabelTitle: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 594
      Height = 23
      Align = alTop
      Caption = 'DNS-01 Challenge Setup'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitLeft = 16
      ExplicitTop = 16
      ExplicitWidth = 234
    end
    object LabelInstructions: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 32
      Width = 594
      Height = 13
      Align = alTop
      Caption = 'Create the following DNS TXT record to verify domain ownership.'
      ExplicitLeft = 16
      ExplicitTop = 45
      ExplicitWidth = 312
    end
  end
  object PanelCenter: TPanel
    Left = 0
    Top = 70
    Width = 600
    Height = 390
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 67
    object MemoInstructions: TMemo
      AlignWithMargins = True
      Left = 3
      Top = 258
      Width = 594
      Height = 129
      Align = alBottom
      Color = clInfoBk
      Lines.Strings = (
        'Instructions:'
        ''
        '1. Go to your DNS provider'#39's control panel'
        '2. Create a new TXT record with the name and value shown above'
        '3. Wait for DNS propagation (can take a few minutes to 24 hours)'
        
          '4. Verify the record is active using: nslookup -type=TXT <record' +
          ' name>'
        '5. Click OK to continue the validation process'
        ''
        'Click Cancel to abort the certificate creation.')
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
      ExplicitLeft = 16
      ExplicitTop = 237
      ExplicitWidth = 568
    end
    object GridPanel1: TGridPanel
      Left = 0
      Top = 0
      Width = 600
      Height = 255
      Align = alClient
      BevelOuter = bvNone
      ColumnCollection = <
        item
          Value = 100.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 150.000000000000000000
        end>
      ControlCollection = <
        item
          Column = 0
          Control = Panel1
          Row = 0
        end
        item
          Column = 0
          Control = Panel3
          Row = 1
        end
        item
          Column = 1
          Control = ButtonCopyName
          Row = 0
        end
        item
          Column = 1
          Control = ButtonCopyBoth
          Row = 1
        end
        item
          Column = 0
          Control = Panel2
          Row = 2
        end
        item
          Column = 1
          Control = ButtonCopyValue
          Row = 2
        end
        item
          Column = 0
          Control = Panel4
          Row = 3
        end
        item
          Column = 1
          Control = ButtonVerifyDNS
          Row = 3
        end>
      RowCollection = <
        item
          Value = 25.000000000000000000
        end
        item
          Value = 25.000000000000000000
        end
        item
          Value = 25.000000000000000000
        end
        item
          Value = 25.000000000000000000
        end>
      TabOrder = 0
      ExplicitLeft = 128
      ExplicitTop = 92
      ExplicitWidth = 481
      ExplicitHeight = 121
      object Panel1: TPanel
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 444
        Height = 58
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitLeft = 32
        ExplicitTop = 16
        ExplicitWidth = 185
        ExplicitHeight = 41
        object LabelRecordName: TLabel
          Left = 0
          Top = 21
          Width = 444
          Height = 13
          Align = alTop
          Caption = 'Record Name:'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
          ExplicitTop = 37
        end
        object EditRecordName: TEdit
          Left = 0
          Top = 0
          Width = 444
          Height = 21
          Align = alTop
          ReadOnly = True
          TabOrder = 0
          ExplicitTop = 37
        end
      end
      object Panel3: TPanel
        AlignWithMargins = True
        Left = 3
        Top = 67
        Width = 444
        Height = 58
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitLeft = 32
        ExplicitTop = 16
        ExplicitWidth = 185
        ExplicitHeight = 41
        object LabelRecordType: TLabel
          Left = 0
          Top = 0
          Width = 444
          Height = 13
          Align = alTop
          Caption = 'Record Type:'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
          ExplicitLeft = 20
          ExplicitTop = 11
          ExplicitWidth = 74
        end
        object EditRecordType: TEdit
          Left = 0
          Top = 13
          Width = 444
          Height = 21
          Align = alTop
          ReadOnly = True
          TabOrder = 0
          Text = 'TXT'
          ExplicitTop = 40
        end
      end
      object ButtonCopyName: TButton
        AlignWithMargins = True
        Left = 453
        Top = 3
        Width = 144
        Height = 58
        Align = alClient
        Caption = 'Copy Name'
        TabOrder = 1
        OnClick = ButtonCopyNameClick
        ExplicitLeft = 368
        ExplicitTop = 2
        ExplicitWidth = 75
        ExplicitHeight = 25
      end
      object ButtonCopyBoth: TButton
        AlignWithMargins = True
        Left = 453
        Top = 67
        Width = 144
        Height = 58
        Align = alClient
        Caption = 'Copy All'
        TabOrder = 3
        OnClick = ButtonCopyBothClick
        ExplicitLeft = 368
        ExplicitTop = 32
        ExplicitWidth = 75
        ExplicitHeight = 25
      end
      object Panel2: TPanel
        AlignWithMargins = True
        Left = 3
        Top = 131
        Width = 444
        Height = 57
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 4
        ExplicitLeft = 32
        ExplicitTop = 16
        ExplicitWidth = 185
        ExplicitHeight = 41
        object LabelRecordValue: TLabel
          Left = 0
          Top = 0
          Width = 444
          Height = 13
          Align = alTop
          Caption = 'Record Value:'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
          ExplicitLeft = 16
          ExplicitTop = 12
          ExplicitWidth = 77
        end
        object EditRecordValue: TEdit
          Left = 0
          Top = 13
          Width = 444
          Height = 21
          Align = alTop
          ReadOnly = True
          TabOrder = 0
          ExplicitLeft = -3
          ExplicitTop = 36
        end
      end
      object ButtonCopyValue: TButton
        AlignWithMargins = True
        Left = 453
        Top = 131
        Width = 144
        Height = 57
        Align = alClient
        Caption = 'Copy Value'
        TabOrder = 5
        OnClick = ButtonCopyValueClick
        ExplicitLeft = 368
        ExplicitTop = 63
        ExplicitWidth = 75
        ExplicitHeight = 25
      end
      object Panel4: TPanel
        AlignWithMargins = True
        Left = 3
        Top = 194
        Width = 444
        Height = 58
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 6
        ExplicitLeft = 32
        ExplicitTop = 16
        ExplicitWidth = 185
        ExplicitHeight = 41
        object LabelStatus: TLabel
          Left = 0
          Top = 0
          Width = 444
          Height = 58
          Align = alClient
          AutoSize = False
          Caption = 'Click "Verify DNS" to test your DNS record configuration'
          ExplicitLeft = 27
          ExplicitTop = 45
          ExplicitWidth = 417
          ExplicitHeight = 13
        end
      end
      object ButtonVerifyDNS: TButton
        AlignWithMargins = True
        Left = 453
        Top = 194
        Width = 144
        Height = 58
        Align = alClient
        Caption = 'Verify DNS Record'
        TabOrder = 7
        OnClick = ButtonVerifyDNSClick
        ExplicitLeft = 368
        ExplicitTop = 93
        ExplicitWidth = 75
        ExplicitHeight = 25
      end
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 460
    Width = 600
    Height = 39
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object ButtonOK: TButton
      AlignWithMargins = True
      Left = 411
      Top = 3
      Width = 90
      Height = 33
      Align = alRight
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = ButtonOKClick
      ExplicitLeft = 339
      ExplicitTop = 6
      ExplicitHeight = 53
    end
    object ButtonCancel: TButton
      AlignWithMargins = True
      Left = 507
      Top = 3
      Width = 90
      Height = 33
      Align = alRight
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
      OnClick = ButtonCancelClick
      ExplicitLeft = 503
      ExplicitTop = 17
      ExplicitHeight = 30
    end
  end
end
