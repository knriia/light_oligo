unit OligoArrayDocument;
// Открытый массив олигов: сам массив, файл, из которого он открыт или в
// который сохранён, признак изменений после последнего сохранения и
// результат последнего слайсинга этого массива.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, OligoArray, OligoSlices;

const
  // Имя по умолчанию для нового проекта - текущие дата и время
  // (без двоеточий, т.к. это имя папки).
  DEFAULT_NAME_FORMAT = 'yyyy-mm-dd hh-nn-ss';
  // Имя файла последовательностей (без расширения) в новом проекте.
  DEFAULT_ARRAY_FILE = 'arrays';

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
    function IsEmpty: Boolean;
    function HasFile: Boolean;
    // Папка файла массива; пусто, если массив ещё не сохранялся.
    function ArrayDir: string;
    // Куда предлагать сохранить проект: открытый из файла - туда же
    // (папка проектов = родитель папки проекта, имя = имя папки проекта),
    // новый - в AProjectsDir с именем по времени ANow (DEFAULT_NAME_FORMAT).
    // CSV проекта лежит в <папка проектов>\<имя>\<имя файла>.csv.
    procedure SuggestProjectLocation(const AProjectsDir: string;
      ANow: TDateTime; out AParentDir, AName: string);

    // Результат слайсинга: таблица слоёв и папка слайса, где лежат Slices.txt,
    // layers и Slices.lays. Забывается, когда массив меняется, заменяется или
    // сохраняется в папку другого проекта; сохранение в ту же папку слайсинг
    // не трогает, где бы ни лежала папка слайса.
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

// Путь к другому .csv в папке проекта (не AFilePath) или '' - в проекте
// должен быть ровно один CSV.
function FindOtherProjectCsv(const AFolder, AFilePath: string): string;

implementation

uses
  OligoArrayCsv;

function FindOtherProjectCsv(const AFolder, AFilePath: string): string;
var
  Search: TSearchRec;
  Path: string;
begin
  Result:='';
  if FindFirst(IncludeTrailingPathDelimiter(AFolder)+'*', faAnyFile and not faDirectory,
       Search)<>0 then
    Exit;
  try
    repeat
      if not SameText(ExtractFileExt(Search.Name), '.csv') then
        Continue;
      Path:=IncludeTrailingPathDelimiter(AFolder)+Search.Name;
      if not SameFileName(ExpandFileName(Path), ExpandFileName(AFilePath)) then
      begin
        Result:=Path;
        Exit;
      end;
    until FindNext(Search)<>0;
  finally
    FindClose(Search);
  end;
end;

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
var
  OldDir: string;
begin
  OldDir:=ArrayDir;
  Result:=SaveOligoArrayFile(AFileName, FArr, AErrorText);
  if not Result then
    Exit;
  FFileName:=ExpandFileName(AFileName);
  FModified:=False;
  // слайсинг лежит в папке прежнего проекта: в новом проекте его нет
  if HasSlicing and (OldDir<>'') and not SameFileName(OldDir, ArrayDir) then
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

procedure TOligoArrayDocument.SuggestProjectLocation(const AProjectsDir: string;
  ANow: TDateTime; out AParentDir, AName: string);
begin
  if HasFile then
  begin
    AParentDir:=ExtractFileDir(ArrayDir);
    AName:=ExtractFileName(ArrayDir);
  end
  else
  begin
    AParentDir:=ExcludeTrailingPathDelimiter(AProjectsDir);
    AName:=FormatDateTime(DEFAULT_NAME_FORMAT, ANow);
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
