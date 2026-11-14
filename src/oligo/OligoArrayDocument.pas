unit OligoArrayDocument;
// Открытый массив олигов: сам массив, файл, из которого он открыт или в
// который сохранён, признак изменений после последнего сохранения и
// результат последнего слайсинга этого массива.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoArray, OligoSlices;

type
  TOligoArrayDocument = class
  private
    FArr: TOligoArr;
    FFileName: string;
    FModified: Boolean;
    FSliceTable: TSliceLayers;
    FSliceDir: string;
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
    // Куда предлагать сохранить массив: открытый из файла - туда же,
    // новый - в папку array_<дата_время> внутри AArraysDir.
    procedure SuggestSaveLocation(const AArraysDir: string; ANow: TDateTime;
      out AFolder, AFileName: string);

    // Результат слайсинга: таблица слоёв и папка, рядом с которой лежат
    // Slices.txt и Slices.lays. Забывается, когда массив меняется,
    // заменяется, очищается, убирается или сохраняется в другую папку.
    procedure SetSlicing(const ATable: TSliceLayers; const ASliceDir: string);
    procedure ForgetSlicing;
    function HasSlicing: Boolean;
    property SliceTable: TSliceLayers read FSliceTable;
    property SliceDir: string read FSliceDir;
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
  ForgetSlicing;
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
  ForgetSlicing;
end;

function TOligoArrayDocument.SaveToFile(const AFileName: string;
  out AErrorText: string): Boolean;
begin
  Result:=SaveOligoArrayFile(AFileName, FArr, AErrorText);
  if not Result then
    Exit;
  FFileName:=ExpandFileName(AFileName);
  FModified:=False;
  // слои лежат рядом со старым файлом: рядом с новым их нет
  if HasSlicing and
     not SameFileName(ExcludeTrailingPathDelimiter(FSliceDir), ArrayDir) then
    ForgetSlicing;
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
  ForgetSlicing; // слои нарезаны из прежнего содержимого
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
        ForgetSlicing; // слои нарезаны из прежнего содержимого
      end;
end;

procedure TOligoArrayDocument.Close;
begin
  FArr:=nil;
  FFileName:='';
  FModified:=False;
  ForgetSlicing;
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

procedure TOligoArrayDocument.SuggestSaveLocation(const AArraysDir: string;
  ANow: TDateTime; out AFolder, AFileName: string);
begin
  if HasFile then
  begin
    AFolder:=ArrayDir;
    AFileName:=ChangeFileExt(ExtractFileName(FFileName), '');
  end
  else
  begin
    AFileName:='array_'+FormatDateTime('yyyy-mm-dd_hhnn', ANow);
    AFolder:=IncludeTrailingPathDelimiter(AArraysDir)+AFileName;
  end;
end;

procedure TOligoArrayDocument.SetSlicing(const ATable: TSliceLayers;
  const ASliceDir: string);
begin
  FSliceTable:=Copy(ATable);
  FSliceDir:=ASliceDir;
end;

procedure TOligoArrayDocument.ForgetSlicing;
begin
  FSliceTable:=nil;
  FSliceDir:='';
end;

function TOligoArrayDocument.HasSlicing: Boolean;
begin
  Result:=Length(FSliceTable)>0;
end;

end.
