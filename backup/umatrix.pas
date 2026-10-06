unit UMatrix;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin, Grids,
  Buttons, LasFunc, MyGlobals;

type

  { TForm2 }

  TForm2 = class(TForm)
    B_LoadFile: TBitBtn;
    B_Clear: TButton;
    B_RND: TButton;
    GB_Matrix: TGroupBox;
    L_Columns: TLabel;
    L_Rows: TLabel;
    OpenDialog1: TOpenDialog;
    SE_NCols: TSpinEdit;
    SE_NRows: TSpinEdit;
    SG_Matrix: TStringGrid;
    procedure B_ClearClick(Sender: TObject);
    procedure B_LoadFileClick(Sender: TObject);
    procedure B_RNDClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SE_NColsChange(Sender: TObject);
    procedure SE_NRowsChange(Sender: TObject);
    procedure SG_MatrixKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    Procedure DisplayMatrixInGrid(aMatrix: TMatrix);
    Procedure NColsRowsChage(aNewNCol, aNewNRow: Integer);
  public
    Procedure NumerateGrid(aSG: TStringGrid);
  end;

var
  Form2: TForm2;

implementation
uses Unit1;



{$R *.lfm}

{ TForm2 }

procedure TForm2.FormCreate(Sender: TObject);
begin
  Form2.Caption:=MyIni.ReadString('Interface','Form2','Matrix Creation');
  GB_Matrix.Caption:=MyIni.ReadString('Interface','GB_Matrix','Matrix');
  L_Columns.Caption:=MyIni.ReadString('Interface','L_Columns','Columns');
  L_Rows.Caption:=MyIni.ReadString('Interface','L_Rows','Rows');
  B_Clear.Caption:=MyIni.ReadString('Interface','B_Clear','Clear');
  B_RND.Caption:=MyIni.ReadString('Interface','B_RND','RND');
  B_LoadFile.Caption:=MyIni.ReadString('Interface','B_LoadFile','LoadFile');
  SE_NCols.Value:=MyIni.ReadInteger('Program','SE_NCols',20);
  SE_NRows.Value:=MyIni.ReadInteger('Program','SE_NRows',20);
  NColsRowsChage(SE_NCols.Value, SE_NRows.Value);
end;

procedure TForm2.B_ClearClick(Sender: TObject);
// Очищаем матрицу и вызываем отображение ее в StringGrid
var
  i,j: integer;
begin
  for i:=0 to High(MyMatrix) do
  begin
    for j:=0 to High(MyMatrix[i]) do
    begin
      MyMatrix[i,j]:=0;
    end;
  end;
  DisplayMatrixInGrid(MyMatrix);
end;

procedure TForm2.B_LoadFileClick(Sender: TObject);
// копирование элементов из матрицы донора в матрицу акцептор
var
  TmpPath: String;
  TmpMatrix: TMatrix;
begin
  if OpenDialog1.Execute then
  begin
  try
    TmpPath:=OpenDialog1.FileName;
    ReadMatrixFromFile(TmpPath, TmpMatrix);
    SE_NCols.Value:=Length(TmpMatrix);
    SE_NRows.Value:=Length(TmpMatrix[0]);
    NColsRowsChage(SE_NCols.Value, Length(TmpMatrix[0]));
    CopyMatrix(TmpMatrix, MyMatrix);
    DisplayMatrixInGrid(MyMatrix);
    Form1.B_PreviewClick(Self);
  except
  end;
  end;
end;

procedure TForm2.B_RNDClick(Sender: TObject);
//Генерация слуйчайных значений (1 или 0) в матрице
var
  i,j: integer;
begin
  Randomize;
  for i:=0 to High(MyMatrix) do
  begin
    for j:=0 to High(MyMatrix[i]) do
    begin
      MyMatrix[i,j]:=Random(2);
    end;
  end;
  DisplayMatrixInGrid(MyMatrix);
  Form1.B_PreviewClick(Self);
end;

procedure TForm2.SE_NColsChange(Sender: TObject);
begin
  NColsRowsChage(SE_NCols.Value, SE_NRows.Value);
end;

procedure TForm2.SE_NRowsChange(Sender: TObject);
begin
  NColsRowsChage(SE_NCols.Value, SE_NRows.Value);
end;

procedure TForm2.SG_MatrixKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
// обработка нажатий клавиш. читаются только цифры 0-9 и backspace
// можно применять к выделению
var
  i,j: integer;
begin
  case Char(key) of
  '0'..'9':
    begin
      MyMatrix[SG_Matrix.Row-1,SG_Matrix.Col-1]:=StrToInt(Char(Key));
      if (SG_Matrix.Selection.Left<>SG_Matrix.Selection.Right) or (SG_Matrix.Selection.Top<>SG_Matrix.Selection.Bottom)
      then
      begin
         for i:=SG_Matrix.Selection.Left to SG_Matrix.Selection.Right do
           begin
             for j:=SG_Matrix.Selection.Top to SG_Matrix.Selection.Bottom do
               begin
                 MyMatrix[j-1,i-1]:=StrToInt(Char(Key));
               end;
           end;
      end;
   end;
  #8:
    begin
      MyMatrix[SG_Matrix.Row-1, SG_Matrix.Col-1]:=0;
      if (SG_Matrix.Selection.Left<>SG_Matrix.Selection.Right) or (SG_Matrix.Selection.Top<>SG_Matrix.Selection.Bottom)
      then
      begin
         for i:=SG_Matrix.Selection.Left to SG_Matrix.Selection.Right do
           begin
             for j:=SG_Matrix.Selection.Top to SG_Matrix.Selection.Bottom do
               begin
                 MyMatrix[j-1,i-1]:=0;
               end;
           end;
      end;
    end
  else // остальные символы запрещены
  Key := 0;
  end;
  DisplayMatrixInGrid(MyMatrix);
end;

procedure TForm2.NumerateGrid(aSG: TStringGrid);
// нумерация строк и стобцов StringGrid [i,0] и [0,i]
var
  i: integer;
begin
  for i:=1 to aSG.ColCount-1 do
  begin
    aSG.Cells[i,0]:=IntToStr(i);
  end;
    for i:=1 to aSG.RowCount-1 do
  begin
    aSG.Cells[0,i]:=IntToStr(i);
  end;
end;

procedure TForm2.DisplayMatrixInGrid(aMatrix: TMatrix);
// отображение матрицы в StringGrid
var
  i, j: Integer;
begin
  // Устанавливаем количество строк и столбцов в TStringGrid
  SG_Matrix.RowCount := Length(aMatrix)+1;
  if Length(aMatrix) > 0 then
    SG_Matrix.ColCount := Length(aMatrix[0])+1;

  // Заполняем TStringGrid значениями из aMatrix
  for i := 0 to High(aMatrix) do
  begin
    for j := 0 to High(aMatrix[i]) do
    begin
      // Преобразуем значение в строку и присваиваем ячейке
      if aMatrix[i][j]<>0 then
        SG_Matrix.Cells[j+1, i+1] := IntToStr(aMatrix[i][j])
      else
        SG_Matrix.Cells[j+1, i+1] := '';
    end;
  end;
end;

procedure TForm2.NColsRowsChage(aNewNCol, aNewNRow: Integer);
// изменение числа колонок или строк в матрице
var
  i: integer;
begin
    SetLength(MyMatrix,aNewNRow);
  for i:=0 to Length(MyMatrix)-1 do
  begin
    SetLength(MyMatrix[i],aNewNCol);
  end;
  DisplayMatrixInGrid(MyMatrix);
  NumerateGrid(SG_Matrix);
end;





end.

