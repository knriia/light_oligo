unit MatrixDocument;
// Матрица точек ручной вкладки: 0 - точки нет, не 0 - точка маркируется.
// Размер, очистка, случайное заполнение, заполнение прямоугольника и
// загрузка из файла. Окно матрицы только показывает и вызывает эти действия.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes;

type
  // Случайное число от 0 до ARange-1 (для тестов подменяется).
  TRandomFunc = function(ARange: Integer): Integer;

  TMatrixDocument = class
  private
    FMatrix: TMatrix;
  public
    constructor Create(ARows, ACols: Integer);
    function Rows: Integer;
    function Cols: Integer;
    // Значения, попавшие в новый размер, сохраняются, новые ячейки - нули.
    procedure Resize(ARows, ACols: Integer);
    procedure Clear;
    // Каждая ячейка - 0 или 1 случайно. ARandom = nil - системный Random.
    procedure FillRandom(ARandom: TRandomFunc = nil);
    // Значение в прямоугольник [ATop..ABottom] x [ALeft..ARight] (с нуля,
    // границы включительно, в любом порядке). Что вне матрицы - пропускается.
    procedure FillCells(ATop, ALeft, ABottom, ARight, AValue: Integer);
    // Матрица из файла заменяет текущую. При ошибке текущая не меняется.
    function LoadFromFile(const AFileName: string; out AErrorText: string): Boolean;
    property Matrix: TMatrix read FMatrix;
  end;

implementation

uses
  OligoMatrix;

function SystemRandom(ARange: Integer): Integer;
begin
  Result := Random(ARange);
end;

constructor TMatrixDocument.Create(ARows, ACols: Integer);
begin
  inherited Create;
  Resize(ARows, ACols);
end;

function TMatrixDocument.Rows: Integer;
begin
  Result := Length(FMatrix);
end;

function TMatrixDocument.Cols: Integer;
begin
  if Length(FMatrix) = 0 then
    Result := 0
  else
    Result := Length(FMatrix[0]);
end;

procedure TMatrixDocument.Resize(ARows, ACols: Integer);
begin
  ResizeMatrix(FMatrix, ARows, ACols);
end;

procedure TMatrixDocument.Clear;
begin
  FillCells(0, 0, Rows - 1, Cols - 1, 0);
end;

procedure TMatrixDocument.FillRandom(ARandom: TRandomFunc);
var
  i, j: Integer;
begin
  if ARandom = nil then
    ARandom := @SystemRandom;
  for i := 0 to High(FMatrix) do
    for j := 0 to High(FMatrix[i]) do
      FMatrix[i, j] := ARandom(2);
end;

procedure TMatrixDocument.FillCells(ATop, ALeft, ABottom, ARight, AValue: Integer);
var
  i, j, T: Integer;
begin
  if ATop > ABottom then
  begin
    T := ATop; ATop := ABottom; ABottom := T;
  end;
  if ALeft > ARight then
  begin
    T := ALeft; ALeft := ARight; ARight := T;
  end;
  if ATop < 0 then
    ATop := 0;
  if ALeft < 0 then
    ALeft := 0;
  if ABottom > Rows - 1 then
    ABottom := Rows - 1;
  if ARight > Cols - 1 then
    ARight := Cols - 1;
  for i := ATop to ABottom do
    for j := ALeft to ARight do
      FMatrix[i, j] := AValue;
end;

function TMatrixDocument.LoadFromFile(const AFileName: string;
  out AErrorText: string): Boolean;
begin
  Result := LoadMatrixFile(AFileName, FMatrix, AErrorText);
end;

end.
