unit OligoArrayDocument;
// Открытый массив олигов: сам массив, файл, из которого он открыт или в
// который сохранён, и признак изменений после последнего сохранения.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoArray;

type
  TOligoArrayDocument = class
  private
    FArr: TOligoArr;
    FFileName: string;
    FModified: Boolean;
  public
    // Новый массив: файла ещё нет, массив считается несохранённым.
    procedure NewArray(const AArr: TOligoArr);
    // При ошибке документ не меняется.
    function LoadFromFile(const AFileName: string; out AErrorText: string): Boolean;
    function SaveToFile(const AFileName: string; out AErrorText: string): Boolean;
    // Значение ячейки (буквы переводятся в верхний регистр).
    // False, если ячейки нет в массиве. Изменения отмечаются, только если
    // значение действительно поменялось.
    function SetCell(ARow, ACol: Integer; const AValue: string): Boolean;
    function Cell(ARow, ACol: Integer): TOlig;
    // Стирает содержимое всех ячеек, размер массива сохраняется.
    // Изменённым массив становится, только если что-то было непустым.
    procedure ClearCells;
    // Убирает массив: ни массива, ни файла, изменений нет. Файл на диске не трогается.
    procedure Close;
    function IsEmpty: Boolean;
    function HasFile: Boolean;
    // Папка файла массива; пусто, если массив ещё не сохранялся.
    function ArrayDir: string;
    // Массив только для чтения: менять его нужно через методы документа.
    property Arr: TOligoArr read FArr;
    property FileName: string read FFileName;
    property Modified: Boolean read FModified;
  end;

implementation

uses
  OligoArrayCsv;

procedure TOligoArrayDocument.NewArray(const AArr: TOligoArr);
begin
  FArr:=CopyOligoArray(AArr);
  FFileName:='';
  FModified:=True;
end;

function TOligoArrayDocument.LoadFromFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  Loaded: TOligoArr;
begin
  Result:=LoadOligoArrayFile(AFileName, Loaded, AErrorText);
  if not Result then
    Exit;
  FArr:=Loaded;
  FFileName:=ExpandFileName(AFileName);
  FModified:=False;
end;

function TOligoArrayDocument.SaveToFile(const AFileName: string;
  out AErrorText: string): Boolean;
begin
  Result:=SaveOligoArrayFile(AFileName, FArr, AErrorText);
  if not Result then
    Exit;
  FFileName:=ExpandFileName(AFileName);
  FModified:=False;
end;

function TOligoArrayDocument.SetCell(ARow, ACol: Integer;
  const AValue: string): Boolean;
var
  Value: TOlig;
begin
  Result:=(ARow>=0) and (ARow<=High(FArr)) and
          (ACol>=0) and (ACol<=High(FArr[ARow]));
  if not Result then
    Exit;
  Value:=StringToOlig(AValue);
  if FArr[ARow,ACol]=Value then
    Exit;
  FArr[ARow,ACol]:=Value;
  FModified:=True;
end;

function TOligoArrayDocument.Cell(ARow, ACol: Integer): TOlig;
begin
  Result:='';
  if (ARow>=0) and (ARow<=High(FArr)) and
     (ACol>=0) and (ACol<=High(FArr[ARow])) then
    Result:=FArr[ARow,ACol];
end;

procedure TOligoArrayDocument.ClearCells;
var
  i, j: Integer;
begin
  for i:=0 to High(FArr) do
    for j:=0 to High(FArr[i]) do
      if FArr[i,j]<>'' then
      begin
        FArr[i,j]:='';
        FModified:=True;
      end;
end;

procedure TOligoArrayDocument.Close;
begin
  FArr:=nil;
  FFileName:='';
  FModified:=False;
end;

function TOligoArrayDocument.IsEmpty: Boolean;
begin
  Result:=Length(FArr)=0;
end;

function TOligoArrayDocument.HasFile: Boolean;
begin
  Result:=FFileName<>'';
end;

function TOligoArrayDocument.ArrayDir: string;
begin
  Result:='';
  if HasFile then
    Result:=ExtractFileDir(FFileName);
end;

end.
