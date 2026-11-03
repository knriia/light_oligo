unit UMatrixForm;
// Окно матрицы ручной вкладки. Саму матрицу хранит TMatrixDocument ручной
// вкладки; окно только показывает её и вызывает действия документа.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin, Grids,
  Buttons, CommonUtils, AppPaths, MatrixDocument;

type

  { TMatrixForm }

  TMatrixForm = class(TForm)
    B_LoadFile: TBitBtn;
    B_Clear: TButton;
    B_RND: TButton;
    GB_Matrix: TGroupBox;
    L_Columns: TLabel;
    L_Rows: TLabel;
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
    FDocument: TMatrixDocument;
    FOnMatrixChanged: TNotifyEvent;
    FResizing: Boolean; // размер меняется из кода - поля размера не трогают матрицу
    procedure SetDocument(ADocument: TMatrixDocument);
    procedure DisplayMatrix;
    procedure ShowSize;
    procedure MatrixChanged;
  public
    // Матрица, которую показывает и меняет окно (документ ручной вкладки).
    property Document: TMatrixDocument read FDocument write SetDocument;
    // Матрица изменилась (загрузка из файла, случайное заполнение).
    property OnMatrixChanged: TNotifyEvent read FOnMatrixChanged
      write FOnMatrixChanged;
  end;

var
  MatrixForm: TMatrixForm;

implementation

uses
  UMainForm;

{$R *.lfm}

{ TMatrixForm }

procedure TMatrixForm.FormCreate(Sender: TObject);
begin
  Caption:=MyInterface.ReadString('Matrix','MatrixForm','Matrix Creation');
  GB_Matrix.Caption:=MyInterface.ReadString('Matrix','GB_Matrix','Matrix');
  L_Columns.Caption:=MyInterface.ReadString('Matrix','L_Columns','Columns');
  L_Rows.Caption:=MyInterface.ReadString('Matrix','L_Rows','Rows');
  B_Clear.Caption:=MyInterface.ReadString('Matrix','B_Clear','Clear');
  B_RND.Caption:=MyInterface.ReadString('Matrix','B_RND','RND');
  B_LoadFile.Caption:=MyInterface.ReadString('Matrix','B_LoadFile','LoadFile');
end;

procedure TMatrixForm.SetDocument(ADocument: TMatrixDocument);
begin
  FDocument:=ADocument;
  ShowSize;
  DisplayMatrix;
end;

procedure TMatrixForm.ShowSize;
// поля размера: строки - число строк матрицы, столбцы - длина строки
begin
  if not Assigned(FDocument) then
    Exit;
  FResizing:=True;
  try
    SE_NRows.Value:=FDocument.Rows;
    SE_NCols.Value:=FDocument.Cols;
  finally
    FResizing:=False;
  end;
end;

procedure TMatrixForm.DisplayMatrix;
var
  i, j: Integer;
begin
  if not Assigned(FDocument) then
    Exit;
  SG_Matrix.RowCount:=FDocument.Rows+1;
  SG_Matrix.ColCount:=FDocument.Cols+1;
  for i:=0 to FDocument.Rows-1 do
    for j:=0 to FDocument.Cols-1 do
      if FDocument.Matrix[i][j]<>0 then
        SG_Matrix.Cells[j+1, i+1]:=IntToStr(FDocument.Matrix[i][j])
      else
        SG_Matrix.Cells[j+1, i+1]:='';
  NumerateGrid(SG_Matrix);
end;

procedure TMatrixForm.MatrixChanged;
begin
  if Assigned(FOnMatrixChanged) then
    FOnMatrixChanged(Self);
end;

procedure TMatrixForm.B_ClearClick(Sender: TObject);
begin
  if not Assigned(FDocument) then
    Exit;
  FDocument.Clear;
  DisplayMatrix;
end;

procedure TMatrixForm.B_LoadFileClick(Sender: TObject);
// матрица из файла заменяет текущую; если файл не читается - текущая остаётся
var
  FileName, ErrorText: String;
  Dialog: TOpenDialog;
begin
  if not Assigned(FDocument) then
    Exit;
  Dialog:=TOpenDialog.Create(nil);
  try
    Dialog.Filter:='Текстовый файл матрицы|*.txt';
    Dialog.FilterIndex:=1;
    Dialog.InitialDir:=MatricesDir;
    if not Dialog.Execute then
      Exit;
    FileName:=Dialog.FileName;
  finally
    Dialog.Free;
  end;
  if not FDocument.LoadFromFile(FileName, ErrorText) then
  begin
    ShowMessage('Не удалось прочитать файл матрицы:'+LineEnding+FileName+
                LineEnding+ErrorText);
    Exit;
  end;
  ShowSize;
  DisplayMatrix;
  MatrixChanged;
end;

procedure TMatrixForm.B_RNDClick(Sender: TObject);
// каждая ячейка - 0 или 1 случайно
begin
  if not Assigned(FDocument) then
    Exit;
  Randomize;
  FDocument.FillRandom;
  DisplayMatrix;
  MatrixChanged;
end;

procedure TMatrixForm.SE_NColsChange(Sender: TObject);
begin
  if FResizing or not Assigned(FDocument) then
    Exit;
  FDocument.Resize(SE_NRows.Value, SE_NCols.Value);
  DisplayMatrix;
end;

procedure TMatrixForm.SE_NRowsChange(Sender: TObject);
begin
  SE_NColsChange(Sender);
end;

procedure TMatrixForm.SG_MatrixKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
// цифра 0-9 - в выделенные ячейки, Backspace - 0; остальные клавиши запрещены
var
  Value: Integer;
begin
  case Char(Key) of
    '0'..'9': Value:=Ord(Char(Key))-Ord('0');
    #8: Value:=0;
  else
    Key:=0;
    Exit;
  end;
  if not Assigned(FDocument) then
    Exit;
  // в таблице строка и столбец 0 - заголовки
  FDocument.FillCells(SG_Matrix.Selection.Top-1, SG_Matrix.Selection.Left-1,
    SG_Matrix.Selection.Bottom-1, SG_Matrix.Selection.Right-1, Value);
  DisplayMatrix;
end;

end.
