unit UOligoArrayForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Spin, StdCtrls,
  Buttons, ExtCtrls, OligoArray;

const
  RG_FILL_EMPTY = 0;
  RG_FILL_RND = 1;
  RG_FILL_SEQ = 2;

type

  { TOligoArrayForm }

  TOligoArrayForm = class(TForm)
    BB_CreateArr: TBitBtn;
    BB_CancelArr: TBitBtn;
    E_ConstSeq: TEdit;
    L_ArrColumns: TLabel;
    L_ArrRows: TLabel;
    L_SetOligoSize: TLabel;
    L_Seq: TLabel;
    L_LenOfRNDSeq: TLabel;
    RG_Fill: TRadioGroup;
    SE_NOligoCol: TSpinEdit;
    SE_NOligoRow: TSpinEdit;
    SE_LenOfRNDSeq: TSpinEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RG_FillClick(Sender: TObject);
  private
    Procedure ShowFillElements(aFillType: integer);
  public
    // Показывает окно. True, если нажали OK; тогда в параметрах - заданный массив.
    function Execute(out ARows, ACols: Integer; out AFill: TOligoFill;
      out ARandomLength: Integer; out AConstSeq: String): Boolean;
  end;

var
  OligoArrayForm: TOligoArrayForm;

implementation
uses
  Localization;

{$R *.lfm}

{ TOligoArrayForm }

procedure TOligoArrayForm.FormCreate(Sender: TObject);
begin
  OligoArrayForm.Caption:=ReadInterfaceString('OligoArray','OligoArrayForm','OligoArray');
  L_SetOligoSize.Caption:=ReadInterfaceString('OligoArray','L_SetOligoSize','Set OligoArray size');
  L_ArrColumns.Caption:=ReadInterfaceString('OligoArray','L_ArrColumns','Number of Columns');
  L_ArrRows.Caption:=ReadInterfaceString('OligoArray','L_ArrRows','Number of Rows');
  RG_Fill.Caption:=ReadInterfaceString('OligoArray','RG_Fill','Filling method');
  RG_Fill.Items[0]:=ReadInterfaceString('OligoArray','RG_Fill_Item0','Empty Array');
  RG_Fill.Items[1]:=ReadInterfaceString('OligoArray','RG_Fill_Item1','Random Filling');
  RG_Fill.Items[2]:=ReadInterfaceString('OligoArray','RG_Fill_Item2','Constant Sequence');
  BB_CancelArr.Caption:=ReadInterfaceString('OligoArray','BB_CancelArr','Cancel');
  BB_CreateArr.Caption:=ReadInterfaceString('OligoArray','BB_CreateArr','OK');
  L_LenOfRNDSeq.Caption:=ReadInterfaceString('OligoArray','L_LenOfRNDSeq','Length');
  L_Seq.Caption:=ReadInterfaceString('OligoArray','L_Seq','Sequence');

  E_ConstSeq.Text:=ReadConfigString('OligoArray','E_ConstSeq','AAATTTGGGCCC');
  SE_NOligoCol.Value:=ReadConfigInteger('OligoArray','SE_NOligoCol',10);
  SE_NOligoRow.Value:=ReadConfigInteger('OligoArray','SE_NOligoRow',10);
  SE_LenOfRNDSeq.Value:=ReadConfigInteger('OligoArray','SE_LenOfRNDSeq',10);
end;

procedure TOligoArrayForm.RG_FillClick(Sender: TObject);
begin
  case RG_Fill.ItemIndex of
  0: ShowFillElements(RG_FILL_EMPTY);
  1: ShowFillElements(RG_FILL_RND);
  2: ShowFillElements(RG_FILL_SEQ);
  end;

end;

procedure TOligoArrayForm.FormShow(Sender: TObject);
begin
  RG_FillClick(Self);
end;

function TOligoArrayForm.Execute(out ARows, ACols: Integer;
  out AFill: TOligoFill; out ARandomLength: Integer;
  out AConstSeq: String): Boolean;
begin
  Result:=ShowModal=mrOK;
  ARows:=SE_NOligoRow.Value;
  ACols:=SE_NOligoCol.Value;
  ARandomLength:=SE_LenOfRNDSeq.Value;
  AConstSeq:=E_ConstSeq.Text;
  case RG_Fill.ItemIndex of
    1: AFill:=ofRandom;
    2: AFill:=ofConstant;
  else
    AFill:=ofEmpty;
  end;
end;

procedure TOligoArrayForm.ShowFillElements(aFillType: integer);
begin
  case aFillType of
  0: begin  // пустой массив, всё прячем
      L_Seq.Visible:=false;
      L_LenOfRNDSeq.Visible:=false;
      SE_LenOfRNDSeq.Visible:=false;
      E_ConstSeq.Visible:=false;
     end;
  1: begin  // Случайное наполнение
      L_Seq.Visible:=false;
      L_LenOfRNDSeq.Visible:=true;
      SE_LenOfRNDSeq.Visible:=true;
      E_ConstSeq.Visible:=false;
     end;
  2: begin  // Одинаковая последовательность
      L_Seq.Visible:=true;
      L_LenOfRNDSeq.Visible:=false;
      SE_LenOfRNDSeq.Visible:=false;
      E_ConstSeq.Visible:=true;
     end;
  end;
end;

end.

