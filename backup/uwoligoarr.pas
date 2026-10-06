unit UWOligoArr;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Spin, StdCtrls,
  Buttons, ExtCtrls;

const
  RG_FILL_EMPTY = 0;
  RG_FILL_RND = 1;
  RG_FILL_SEQ = 2;

type

  { TForm3 }

  TForm3 = class(TForm)
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
    procedure BB_CancelArrClick(Sender: TObject);
    procedure BB_CreateArrClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RG_FillClick(Sender: TObject);
  private
    Procedure ShowFillElements(aFillType: integer);
  public

  end;

var
  Form3: TForm3;
  RND_Length: integer;
  ConstSeqStr: String;
  OligoArrCol, OligoArrRow, FillType: Integer;

implementation
uses
  UMain;

{$R *.lfm}

{ TForm3 }

procedure TForm3.FormCreate(Sender: TObject);
begin
  Form3.Caption:=MyInterface.ReadString('OligoArray','Form3','OligoArray');
  L_SetOligoSize.Caption:=MyInterface.ReadString('OligoArray','L_SetOligoSize','Set OligoArray size');
  L_ArrColumns.Caption:=MyInterface.ReadString('OligoArray','L_ArrColumns','Number of Columns');
  L_ArrRows.Caption:=MyInterface.ReadString('OligoArray','L_ArrRows','Number of Rows');
  RG_Fill.Caption:=MyInterface.ReadString('OligoArray','RG_Fill','Filling method');
  RG_Fill.Items[0]:=MyInterface.ReadString('OligoArray','RG_Fill_Item0','Empty Array');
  RG_Fill.Items[1]:=MyInterface.ReadString('OligoArray','RG_Fill_Item1','Random Filling');
  RG_Fill.Items[2]:=MyInterface.ReadString('OligoArray','RG_Fill_Item2','Constant Sequence');
  BB_CancelArr.Caption:=MyInterface.ReadString('OligoArray','BB_CancelArr','Cancel');
  BB_CreateArr.Caption:=MyInterface.ReadString('OligoArray','BB_CreateArr','OK');
  L_LenOfRNDSeq.Caption:=MyInterface.ReadString('OligoArray','L_LenOfRNDSeq','Length');
  L_Seq.Caption:=MyInterface.ReadString('OligoArray','L_Seq','Sequence');

  E_ConstSeq.Text:=MyIni.ReadString('Program','E_ConstSeq','AAATTTGGGCCC');
  SE_NOligoCol.Value:=MyIni.ReadInteger('Program','SE_NOligoCol',10);
  SE_NOligoRow.Value:=MyIni.ReadInteger('Program','SE_NOligoRow',10);
  SE_LenOfRNDSeq.Value:=MyIni.ReadInteger('Program','SE_LenOfRNDSeq',10);
end;

procedure TForm3.RG_FillClick(Sender: TObject);
begin
  case RG_Fill.ItemIndex of
  0: ShowFillElements(RG_FILL_EMPTY);
  1: ShowFillElements(RG_FILL_RND);
  2: ShowFillElements(RG_FILL_SEQ);
  end;

end;

procedure TForm3.FormShow(Sender: TObject);
begin
  RND_Length:=0;
  ConstSeqStr:='';
  RG_FillClick(Self);
end;

procedure TForm3.BB_CreateArrClick(Sender: TObject);
begin
  OligoArrCol:=SE_NOligoCol.Value;
  OligoArrRow:=SE_NOligoRow.Value;
  case RG_Fill.ItemIndex of
  0:begin
        FillType:=0;
      end;
  1:begin
        RND_Length:=SE_LenOfRNDSeq.Value;
        FillType:=1;
      end;
  2:begin
        ConstSeqStr:='';
        ConstSeqStr:=E_ConstSeq.Text;
        FillType:=2;
      end;
  end;
end;

procedure TForm3.BB_CancelArrClick(Sender: TObject);
begin
    FillType:=-1;
end;

procedure TForm3.ShowFillElements(aFillType: integer);
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

