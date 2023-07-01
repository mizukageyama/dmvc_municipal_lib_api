object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 442
  ClientWidth = 628
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Button1: TButton
    Left = 248
    Top = 256
    Width = 137
    Height = 25
    Caption = 'Button1'
    TabOrder = 0
    OnClick = Button1Click
  end
  object FDConnection1: TFDConnection
    Params.Strings = (
      'Database=municipal_library'
      'User_Name=root'
      'Password=M@st3rk3y1234'
      'Server=localhost'
      'DriverID=MySQL')
    Left = 40
    Top = 32
  end
end
