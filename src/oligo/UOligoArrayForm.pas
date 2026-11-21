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
    E_FileName: TEdit;
    L_FileName: TLabel;
    L_ArrColumns: TLabel;
    L_ArrRows: TLabel;
    L_SetOligoSize: TLabel;
    L_Seq: TLabel;
    L_LenOfRNDSeq: TLabel;
    RG_Fill: TRadioGroup;
    SE_NOligoCol: TSpinEdit;
    SE_NOligoRow: TSpinEdit;
    SE_LenOfRNDSeq: TSpinEdit;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RG_FillClick(Sender: TObject);
  private
    FFileMode: Boolean;      // окно спрашивает ещё и имя файла массива
    FProjectDir: string;     // папка проекта, где появится файл
    FReplaceFile: string;    // CSV, который заменяется: его имя разрешено
    function GetFileBase: string;
    procedure ShowFileRow(AVisible: Boolean);
    Procedure ShowFillElements(aFillType: integer);
  public
    // Окно спрашивает и имя файла массива в папке проекта AProjectDir (по
    // умолчанию ADefaultName); AReplaceFile - заменяемый CSV, его имя можно
    // оставить. Без вызова (или с пустой AProjectDir) имя не спрашивается.
    procedure AskFileName(const AProjectDir, ADefaultName, AReplaceFile: string);
    // Имя файла без .csv, введённое в окне; пусто, если имя не спрашивалось.
    property FileBase: string read GetFileBase;
    // Показывает окно. True, если нажали OK; тогда в параметрах - заданный массив.
    function Execute(out ARows, ACols: Integer; out AFill: TOligoFill;
      out ARandomLength: Integer; out AConstSeq: String): Boolean;
  end;

var
  OligoArrayForm: TOligoArrayForm;

implementation
uses
  LazFileUtils, Localization, AppPaths;

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
  L_FileName.Caption:=ReadInterfaceString('OligoArray','L_FileName','File name');

  E_ConstSeq.Text:=ReadConfigString('OligoArray','E_ConstSeq','AAATTTGGGCCC');
  SE_NOligoCol.Value:=ReadConfigInteger('OligoArray','SE_NOligoCol',10);
  SE_NOligoRow.Value:=ReadConfigInteger('OligoArray','SE_NOligoRow',10);
  SE_LenOfRNDSeq.Value:=ReadConfigInteger('OligoArray','SE_LenOfRNDSeq',10);
end;

function TOligoArrayForm.GetFileBase: string;
begin
  Result:='';
  if not FFileMode then
    Exit;
  Result:=Trim(E_FileName.Text);
  if SameText(ExtractFileExt(Result), '.csv') then
    Result:=Copy(Result, 1, Length(Result)-4);
end;

procedure TOligoArrayForm.ShowFileRow(AVisible: Boolean);
// строка имени файла сверху; остальное окно сдвигается вниз на её высоту
const
  ROW_SHIFT = 36;
var
  I: Integer;
  Shift: Integer;
begin
  if AVisible=L_FileName.Visible then
    Exit;
  if AVisible then
    Shift:=ROW_SHIFT
  else
    Shift:=-ROW_SHIFT;
  for I:=0 to ControlCount-1 do
    if (Controls[I]<>L_FileName) and (Controls[I]<>E_FileName) then
      Controls[I].Top:=Controls[I].Top+Shift;
  ClientHeight:=ClientHeight+Shift;
  L_FileName.Visible:=AVisible;
  E_FileName.Visible:=AVisible;
end;

procedure TOligoArrayForm.AskFileName(const AProjectDir, ADefaultName,
  AReplaceFile: string);
begin
  FFileMode:=AProjectDir<>'';
  FProjectDir:=AProjectDir;
  FReplaceFile:=AReplaceFile;
  E_FileName.Text:=ADefaultName;
  ShowFileRow(FFileMode);
end;

procedure TOligoArrayForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
// «OK» закрывает окно, только если имя файла допустимо и свободно в проекте
var
  ErrorText, FilePath: string;
begin
  if (ModalResult<>mrOK) or not FFileMode then
    Exit;
  CanClose:=CheckFileNamePart(GetFileBase,
    ReadInterfaceString('OligoArray','L_FileName','File name'), ErrorText);
  if CanClose then
  begin
    FilePath:=IncludeTrailingPathDelimiter(FProjectDir)+GetFileBase+'.csv';
    if FileExists(FilePath) and not SameFileName(FilePath, FReplaceFile) then
    begin
      ErrorText:=ReadInterfaceString('OligoArray','FileNameExists',
        'Файл с таким именем уже есть в проекте.');
      CanClose:=False;
    end;
  end;
  if not CanClose then
    ShowMessage(ErrorText);
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

