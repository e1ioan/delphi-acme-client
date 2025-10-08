object ACMECertificateListForm: TACMECertificateListForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Certificate List'
  ClientHeight = 450
  ClientWidth = 700
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
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 700
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
      Width = 145
      Height = 19
      Align = alTop
      Caption = 'Certificate Orders'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LabelInstructions: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 28
      Width = 128
      Height = 13
      Align = alTop
      Caption = 'Select an order to resume:'
    end
  end
  object ListView: TListView
    Left = 0
    Top = 80
    Width = 700
    Height = 326
    Align = alClient
    Columns = <
      item
        AutoSize = True
        Caption = 'Domains'
      end
      item
        Caption = 'Status'
        Width = 100
      end
      item
        Caption = 'Created'
        Width = 150
      end
      item
        Caption = 'Cert Expiry'
        Width = 150
      end
      item
        Caption = 'Provider'
        Width = 130
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnCustomDrawSubItem = ListViewCustomDrawSubItem
    OnDblClick = ListViewDblClick
    ExplicitWidth = 692
    ExplicitHeight = 320
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 406
    Width = 700
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object ButtonDelete: TButton
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 90
      Height = 38
      Align = alLeft
      Caption = 'Delete'
      TabOrder = 0
      OnClick = ButtonDeleteClick
      ExplicitLeft = 16
      ExplicitTop = 11
      ExplicitHeight = 30
    end
    object ButtonOK: TButton
      AlignWithMargins = True
      Left = 511
      Top = 3
      Width = 90
      Height = 38
      Align = alRight
      Caption = 'OK'
      Default = True
      TabOrder = 1
      OnClick = ButtonOKClick
      ExplicitLeft = 447
      ExplicitTop = -1
      ExplicitHeight = 44
    end
    object ButtonCancel: TButton
      AlignWithMargins = True
      Left = 607
      Top = 3
      Width = 90
      Height = 38
      Align = alRight
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 2
      OnClick = ButtonCancelClick
      ExplicitLeft = 600
      ExplicitTop = 11
      ExplicitHeight = 30
    end
  end
end
