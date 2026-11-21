unit ProjectModel;
// Проект как объект, без интерфейса: папка проекта <имя>\ и файл проекта
// <имя>.OlProj (JSON) в ней. Состав проекта - то, что записано в файле: один
// файл массива (CSV), слайсинги (папки slice_<алгоритм>\ со Slices.txt) и синтезы
// synthes_<дата>\ внутри слайсинга. Синтез лежит в папке слайсинга, из которого
// взяты его слои, поэтому связь «синтез - слайсинг» задаёт расположение папки.
// Файл на диске, которого нет в .OlProj, в проект не входит.
// Refresh сверяет файл проекта с диском: записи, чьих файлов уже нет, выпадают;
// всё, что появилось на диске после прошлой сверки, добавляется в проект и файл
// перезаписывается. Папка без .OlProj (прежний формат) при первой сверке
// принимается целиком, и файл создаётся. Нет массива - проект пустой.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  PROJECT_FILE_EXT = '.OlProj';  // расширение файла проекта

type
  // Что открывает «Файл → Открыть» по имени выбранного файла.
  TProjectFileKind = (pfkUnknown, pfkArray, pfkProtocol, pfkSynthesis);

  // Строка дерева проекта: проект, массив, слайсинг, синтез.
  TProjectNodeKind = (pnkProject, pnkArray, pnkSlicing, pnkSynthesis);

  TProjectNode = record
    Kind: TProjectNodeKind;
    Level: Integer;    // глубина: проект 0, массив и слайсинги 1, синтезы 2
    Caption: string;   // имя проекта, файла массива или папки
    Path: string;      // файл массива или папка проекта, слайсинга, синтеза
  end;
  TProjectNodes = array of TProjectNode;

  TProjectSynthesis = record
    Name: string;     // имя папки синтеза
    Folder: string;   // полный путь к папке синтеза
  end;
  TProjectSyntheses = array of TProjectSynthesis;

  TProjectSlicing = record
    Name: string;       // имя папки слайсинга: slice_<алгоритм> или другое на slice...
    Algorithm: string;  // часть имени после slice_; пусто, если имя без slice_
    Folder: string;     // полный путь к папке слайсинга
    Syntheses: TProjectSyntheses;  // синтезы этого слайсинга по имени папки
  end;
  TProjectSlicings = array of TProjectSlicing;

  TProject = class
  private
    FDir: string;
    FFile: string;
    FArrayFile: string;
    FSlicings: TProjectSlicings;
    FKnown: TStringList;  // что было на диске при прошлой сверке; nil - сверки не было
    function GetName: string;
    function GetSlicingCount: Integer;
    function GetSlicing(AIndex: Integer): TProjectSlicing;
    function Save(out AErrorText: string): Boolean;
  public
    // AFile - файл проекта; пусто - <ADir>\*.OlProj или, если его нет,
    // <ADir>\<имя папки>.OlProj (создаётся первой сверкой).
    constructor Create(const ADir: string; const AFile: string = '');
    destructor Destroy; override;
    // Сверяет файл проекта с диском (см. описание модуля). Ошибка - False, текст
    // объясняет, и модель остаётся прежней.
    function Refresh(out AErrorText: string): Boolean;
    // Индекс слайсинга по имени его папки или -1.
    function IndexOfSlicing(const AName: string): Integer;
    // Индекс слайсинга, в папке которого лежит синтез (по полному пути
    // папки синтеза) или -1.
    function SlicingOfSynthesis(const ASynthesisFolder: string): Integer;

    // Папка проекта без разделителя на конце.
    property Dir: string read FDir;
    // Полный путь к файлу проекта (.OlProj).
    property FileName: string read FFile;
    // Имя проекта - имя его папки (для корня диска - сам диск).
    property Name: string read GetName;
    // Полный путь к CSV массива; пусто, если массива в проекте нет.
    property ArrayFile: string read FArrayFile;
    property SlicingCount: Integer read GetSlicingCount;
    property Slicings[AIndex: Integer]: TProjectSlicing read GetSlicing;
  end;

// Тип файла по имени: .csv - массив, .pro - протокол, synthesis.ini -
// синтез (регистр не важен), остальное - pfkUnknown.
function ProjectFileKindOf(const AFileName: string): TProjectFileKind;
// Дерево проекта плоским списком в порядке показа: проект, массив (если есть),
// затем каждый слайсинг и сразу за ним его синтезы.
function ProjectNodes(AProject: TProject): TProjectNodes;
// Открывает существующий проект по файлу .OlProj или по папке проекта (папка
// без .OlProj принимается целиком). Нет папки, файл проекта не читается -
// nil, текст объясняет.
function OpenProject(const APath: string; out AErrorText: string): TProject;
// Создаёт папку нового проекта AParentDir\AName и открывает её. Папка
// AParentDir должна существовать, создаётся только папка проекта. Имя или
// путь недопустимы, родителя нет, папка уже есть, создать не удалось - nil,
// текст объясняет.
function CreateProject(const AParentDir, AName: string;
  out AErrorText: string): TProject;

implementation

uses
  fpjson, jsonparser, AppPaths, OligoSlices, OligoArrayDocument,
  SynthesisFolder;

function ProjectFileKindOf(const AFileName: string): TProjectFileKind;
begin
  if SameText(ExtractFileName(AFileName), SYNTHESIS_INFO_FILE) then
    Result := pfkSynthesis
  else if SameText(ExtractFileExt(AFileName), '.csv') then
    Result := pfkArray
  else if SameText(ExtractFileExt(AFileName), '.pro') then
    Result := pfkProtocol
  else
    Result := pfkUnknown;
end;

function ProjectNodes(AProject: TProject): TProjectNodes;
var
  Count, I, J: Integer;

  procedure Add(AKind: TProjectNodeKind; ALevel: Integer;
    const ACaption, APath: string);
  begin
    Result[Count].Kind := AKind;
    Result[Count].Level := ALevel;
    Result[Count].Caption := ACaption;
    Result[Count].Path := APath;
    Inc(Count);
  end;

begin
  Count := 0;
  SetLength(Result, 2 + AProject.SlicingCount);
  for I := 0 to AProject.SlicingCount - 1 do
    SetLength(Result, Length(Result) + Length(AProject.Slicings[I].Syntheses));
  Add(pnkProject, 0, AProject.Name, AProject.Dir);
  if AProject.ArrayFile <> '' then
    Add(pnkArray, 1, ExtractFileName(AProject.ArrayFile), AProject.ArrayFile);
  for I := 0 to AProject.SlicingCount - 1 do
  begin
    Add(pnkSlicing, 1, AProject.Slicings[I].Name, AProject.Slicings[I].Folder);
    for J := 0 to High(AProject.Slicings[I].Syntheses) do
      Add(pnkSynthesis, 2, AProject.Slicings[I].Syntheses[J].Name,
        AProject.Slicings[I].Syntheses[J].Folder);
  end;
  SetLength(Result, Count);
end;

function IsDirectoryEntry(const ASearch: TSearchRec): Boolean;
begin
  Result := ((ASearch.Attr and faDirectory) <> 0) and (ASearch.Name <> '.') and
    (ASearch.Name <> '..');
end;

// Синтезы слайсинга: подпапки synthes_* с файлом synthesis.ini.
function ScanSyntheses(const ASliceDir: string): TProjectSyntheses;
var
  Names: TStringList;
  Search: TSearchRec;
  Dir, NameError: string;
  I: Integer;
begin
  Result := nil;
  Dir := IncludeTrailingPathDelimiter(ASliceDir);
  Names := TStringList.Create;
  try
    if FindFirst(Dir + '*', faAnyFile, Search) = 0 then
    try
      repeat
        if IsDirectoryEntry(Search) and
           CheckSynthesisFolderName(Search.Name, NameError) and
           FileExists(Dir + Search.Name + PathDelim + SYNTHESIS_INFO_FILE) then
          Names.Add(Search.Name);
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    Names.Sort;
    SetLength(Result, Names.Count);
    for I := 0 to Names.Count - 1 do
    begin
      Result[I].Name := Names[I];
      Result[I].Folder := Dir + Names[I];
    end;
  finally
    Names.Free;
  end;
end;

function SlicingAlgorithm(const AFolderName: string): string;
var
  Prefix: string;
begin
  Prefix := SLICE_FOLDER + '_';
  if SameText(Copy(AFolderName, 1, Length(Prefix)), Prefix) then
    Result := Copy(AFolderName, Length(Prefix) + 1, MaxInt)
  else
    Result := '';
end;

// Файл проекта по умолчанию: <папка>\<имя папки>.OlProj.
function DefaultProjectFile(const ADir: string): string;
var
  Base: string;
begin
  Base := ExtractFileName(ExcludeTrailingPathDelimiter(ADir));
  if Base = '' then
    Base := 'project';  // корень диска
  Result := IncludeTrailingPathDelimiter(ADir) + Base + PROJECT_FILE_EXT;
end;

// Файл *.OlProj в папке: с именем по умолчанию, иначе первый по алфавиту;
// нет файла - ''.
function FindProjectFile(const ADir: string): string;
var
  Names: TStringList;
  Search: TSearchRec;
  Dir: string;
begin
  Result := '';
  Dir := IncludeTrailingPathDelimiter(ADir);
  Names := TStringList.Create;
  try
    if FindFirst(Dir + '*' + PROJECT_FILE_EXT, faAnyFile and not faDirectory,
      Search) = 0 then
    try
      repeat
        if SameText(ExtractFileExt(Search.Name), PROJECT_FILE_EXT) then
          Names.Add(Search.Name);
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    if Names.Count = 0 then
      Exit;
    Names.Sort;
    Result := Dir + Names[0];
    if FileExists(DefaultProjectFile(ADir)) then
      Result := DefaultProjectFile(ADir);
  finally
    Names.Free;
  end;
end;

// Массив и слайсинги на диске: только имена и пути, без учёта файла проекта.
procedure ScanDisk(const ADir: string; out AArrayName: string;
  out ASlicings: TProjectSlicings);
var
  Folders: TStringArray;
  RootDir: string;
  I: Integer;
begin
  RootDir := IncludeTrailingPathDelimiter(ADir);
  AArrayName := ExtractFileName(FindOtherProjectCsv(ADir, ''));
  Folders := ListSliceFolders(ADir);
  SetLength(ASlicings, Length(Folders));
  for I := 0 to High(Folders) do
  begin
    ASlicings[I].Name := Folders[I];
    ASlicings[I].Algorithm := SlicingAlgorithm(Folders[I]);
    ASlicings[I].Folder := RootDir + Folders[I];
    ASlicings[I].Syntheses := ScanSyntheses(ASlicings[I].Folder);
  end;
end;

function KeyArray(const AName: string): string;
begin
  Result := 'a|' + LowerCase(AName);
end;

function KeySlicing(const AName: string): string;
begin
  Result := 's|' + LowerCase(AName);
end;

function KeySynthesis(const ASlicing, AName: string): string;
begin
  Result := 'y|' + LowerCase(ASlicing) + '|' + LowerCase(AName);
end;

function IndexOfSlicingName(const ASlicings: TProjectSlicings;
  const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(ASlicings) do
    if SameText(ASlicings[I].Name, AName) then
      Exit(I);
end;

function IndexOfSynthesisName(const ASyntheses: TProjectSyntheses;
  const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(ASyntheses) do
    if SameText(ASyntheses[I].Name, AName) then
      Exit(I);
end;

// Имя из файла проекта - имя файла или папки внутри проекта, без пути.
procedure CheckProjectName(const AName: string);
begin
  if (AName = '') or (AName = '.') or (AName = '..') or
     (Pos('\', AName) > 0) or (Pos('/', AName) > 0) or (Pos(':', AName) > 0) then
    raise Exception.Create('недопустимое имя "' + AName + '"');
end;

function JsonString(AObject: TJSONObject; const AName: string): string;
var
  Value: TJSONData;
begin
  Value := AObject.Find(AName);
  if (Value <> nil) and (Value.JSONType = jtString) then
    Result := Value.AsString
  else
    Result := '';
end;

// Читает файл проекта: массив и слайсинги с синтезами (только имена). Ошибка -
// False, текст объясняет.
function LoadProjectFile(const AFile: string; out AArray: string;
  out ASlicings: TProjectSlicings; out AErrorText: string): Boolean;
var
  Stream: TFileStream;
  Data: TJSONData;
  Item: TJSONObject;
  List, SynList: TJSONArray;
  I, J: Integer;
begin
  Result := False;
  AErrorText := '';
  AArray := '';
  ASlicings := nil;
  Data := nil;
  try
    try
      Stream := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
      try
        Data := GetJSON(Stream);
      finally
        Stream.Free;
      end;
      if not (Data is TJSONObject) then
        raise Exception.Create('в корне файла должен быть объект');
      AArray := JsonString(TJSONObject(Data), 'array');
      if AArray <> '' then
        CheckProjectName(AArray);
      List := TJSONObject(Data).Find('slicings', jtArray) as TJSONArray;
      if List <> nil then
      begin
        SetLength(ASlicings, List.Count);
        for I := 0 to List.Count - 1 do
        begin
          if not (List[I] is TJSONObject) then
            raise Exception.Create('слайсинг должен быть объектом');
          Item := TJSONObject(List[I]);
          ASlicings[I].Name := JsonString(Item, 'folder');
          CheckProjectName(ASlicings[I].Name);
          SynList := Item.Find('syntheses', jtArray) as TJSONArray;
          if SynList <> nil then
          begin
            SetLength(ASlicings[I].Syntheses, SynList.Count);
            for J := 0 to SynList.Count - 1 do
            begin
              if SynList[J].JSONType <> jtString then
                raise Exception.Create('имя синтеза должно быть строкой');
              ASlicings[I].Syntheses[J].Name := SynList[J].AsString;
              CheckProjectName(ASlicings[I].Syntheses[J].Name);
            end;
          end;
        end;
      end;
      Result := True;
    except
      on E: Exception do
      begin
        AErrorText := 'Не удалось прочитать файл проекта:' + LineEnding + AFile +
          LineEnding + E.Message;
        AArray := '';
        ASlicings := nil;
      end;
    end;
  finally
    Data.Free;
  end;
end;

constructor TProject.Create(const ADir: string; const AFile: string);
begin
  inherited Create;
  FDir := ExcludeTrailingPathDelimiter(ExpandFileName(ADir));
  // корень диска: 'D:' - это текущая папка диска, а не корень
  if (Length(FDir) = 2) and (FDir[2] = ':') then
    FDir := FDir + PathDelim;
  if AFile <> '' then
    FFile := ExpandFileName(AFile);
end;

destructor TProject.Destroy;
begin
  FKnown.Free;
  inherited Destroy;
end;

function TProject.Save(out AErrorText: string): Boolean;
var
  Root, Item: TJSONObject;
  List, SynList: TJSONArray;
  Text: TStringList;
  I, J: Integer;
begin
  Result := False;
  AErrorText := '';
  Root := TJSONObject.Create;
  Text := TStringList.Create;
  try
    Root.Add('version', 1);
    Root.Add('array', ExtractFileName(FArrayFile));
    List := TJSONArray.Create;
    Root.Add('slicings', List);
    for I := 0 to High(FSlicings) do
    begin
      Item := TJSONObject.Create;
      Item.Add('folder', FSlicings[I].Name);
      SynList := TJSONArray.Create;
      Item.Add('syntheses', SynList);
      for J := 0 to High(FSlicings[I].Syntheses) do
        SynList.Add(FSlicings[I].Syntheses[J].Name);
      List.Add(Item);
    end;
    Text.Text := Root.FormatJSON;
    try
      Text.SaveToFile(FFile);
      Result := True;
    except
      on E: Exception do
        AErrorText := 'Не удалось записать файл проекта:' + LineEnding + FFile +
          LineEnding + E.Message;
    end;
  finally
    Text.Free;
    Root.Free;
  end;
end;

function TProject.GetName: string;
begin
  Result := ExtractFileName(FDir);
  if Result = '' then
    Result := ExcludeTrailingPathDelimiter(FDir);
end;

function TProject.GetSlicingCount: Integer;
begin
  Result := Length(FSlicings);
end;

function TProject.GetSlicing(AIndex: Integer): TProjectSlicing;
begin
  Result := FSlicings[AIndex];
end;

function TProject.Refresh(out AErrorText: string): Boolean;
var
  NewFile, FileArray, DiskArray, NewArray, RootDir: string;
  FileSlicings, DiskSlicings, NewSlicings: TProjectSlicings;
  Known: TStringList;
  FileExisted, Changed: Boolean;
  I, J, K, N: Integer;

  // Появилось ли на диске новое: без файла проекта принимается всё, с файлом -
  // только то, чего не было при прошлой сверке.
  function Fresh(const AKey: string): Boolean;
  begin
    if not FileExisted then
      Result := True
    else
      Result := (FKnown <> nil) and (FKnown.IndexOf(AKey) < 0);
  end;

begin
  Result := False;
  AErrorText := '';
  if not DirectoryExists(FDir) then
  begin
    AErrorText := 'Папка проекта не найдена:' + LineEnding + FDir;
    Exit;
  end;
  NewFile := FFile;
  if NewFile = '' then
  begin
    NewFile := FindProjectFile(FDir);
    if NewFile = '' then
      NewFile := DefaultProjectFile(FDir);
  end;
  FileExisted := FileExists(NewFile);
  FileArray := '';
  FileSlicings := nil;
  if FileExisted and
     not LoadProjectFile(NewFile, FileArray, FileSlicings, AErrorText) then
    Exit;
  ScanDisk(FDir, DiskArray, DiskSlicings);
  RootDir := IncludeTrailingPathDelimiter(FDir);
  Changed := not FileExisted;

  // массив: из файла, если он на месте; иначе новый CSV с диска
  NewArray := FileArray;
  if (NewArray <> '') and not FileExists(RootDir + NewArray) then
  begin
    NewArray := '';
    Changed := True;
  end;
  if (NewArray = '') and (DiskArray <> '') and Fresh(KeyArray(DiskArray)) then
  begin
    NewArray := DiskArray;
    Changed := True;
  end;

  // слайсинги и синтезы: записи файла, чьи папки есть на диске, затем новое
  NewSlicings := nil;
  for I := 0 to High(FileSlicings) do
  begin
    J := IndexOfSlicingName(DiskSlicings, FileSlicings[I].Name);
    if (J < 0) or (IndexOfSlicingName(NewSlicings, FileSlicings[I].Name) >= 0) then
    begin
      Changed := True;
      Continue;
    end;
    N := Length(NewSlicings);
    SetLength(NewSlicings, N + 1);
    NewSlicings[N] := DiskSlicings[J];
    NewSlicings[N].Syntheses := nil;
    for K := 0 to High(FileSlicings[I].Syntheses) do
    begin
      if IndexOfSynthesisName(NewSlicings[N].Syntheses,
           FileSlicings[I].Syntheses[K].Name) >= 0 then
        Continue;
      if IndexOfSynthesisName(DiskSlicings[J].Syntheses,
           FileSlicings[I].Syntheses[K].Name) < 0 then
      begin
        Changed := True;
        Continue;
      end;
      SetLength(NewSlicings[N].Syntheses, Length(NewSlicings[N].Syntheses) + 1);
      NewSlicings[N].Syntheses[High(NewSlicings[N].Syntheses)] :=
        DiskSlicings[J].Syntheses[IndexOfSynthesisName(DiskSlicings[J].Syntheses,
        FileSlicings[I].Syntheses[K].Name)];
    end;
    for K := 0 to High(DiskSlicings[J].Syntheses) do
      if (IndexOfSynthesisName(NewSlicings[N].Syntheses,
           DiskSlicings[J].Syntheses[K].Name) < 0) and
         Fresh(KeySynthesis(DiskSlicings[J].Name,
           DiskSlicings[J].Syntheses[K].Name)) then
      begin
        SetLength(NewSlicings[N].Syntheses, Length(NewSlicings[N].Syntheses) + 1);
        NewSlicings[N].Syntheses[High(NewSlicings[N].Syntheses)] :=
          DiskSlicings[J].Syntheses[K];
        Changed := True;
      end;
  end;
  for J := 0 to High(DiskSlicings) do
    if (IndexOfSlicingName(NewSlicings, DiskSlicings[J].Name) < 0) and
       Fresh(KeySlicing(DiskSlicings[J].Name)) then
    begin
      N := Length(NewSlicings);
      SetLength(NewSlicings, N + 1);
      NewSlicings[N] := DiskSlicings[J];
      Changed := True;
    end;

  // что есть на диске сейчас - основа для следующей сверки
  Known := TStringList.Create;
  if DiskArray <> '' then
    Known.Add(KeyArray(DiskArray));
  for J := 0 to High(DiskSlicings) do
  begin
    Known.Add(KeySlicing(DiskSlicings[J].Name));
    for K := 0 to High(DiskSlicings[J].Syntheses) do
      Known.Add(KeySynthesis(DiskSlicings[J].Name,
        DiskSlicings[J].Syntheses[K].Name));
  end;

  FFile := NewFile;
  if NewArray = '' then
    FArrayFile := ''
  else
    FArrayFile := RootDir + NewArray;
  FSlicings := NewSlicings;
  FKnown.Free;
  FKnown := Known;
  Result := True;
  if Changed then
    Result := Save(AErrorText);
end;

function TProject.IndexOfSlicing(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FSlicings) do
    if SameText(FSlicings[I].Name, AName) then
      Exit(I);
end;

function TProject.SlicingOfSynthesis(const ASynthesisFolder: string): Integer;
var
  Parent: string;
  I: Integer;
begin
  Result := -1;
  Parent := ExtractFileDir(ExcludeTrailingPathDelimiter(
    ExpandFileName(ASynthesisFolder)));
  for I := 0 to High(FSlicings) do
    if SameFileName(FSlicings[I].Folder, Parent) then
      Exit(I);
end;

function OpenProject(const APath: string; out AErrorText: string): TProject;
var
  Dir, ProjectFile: string;
begin
  Dir := APath;
  ProjectFile := '';
  if FileExists(APath) then
  begin
    Dir := ExtractFileDir(ExpandFileName(APath));
    if SameText(ExtractFileExt(APath), PROJECT_FILE_EXT) then
      ProjectFile := APath;
  end;
  Result := TProject.Create(Dir, ProjectFile);
  if not Result.Refresh(AErrorText) then
    FreeAndNil(Result);
end;

function CreateProject(const AParentDir, AName: string;
  out AErrorText: string): TProject;
var
  Name, Dir: string;
begin
  Result := nil;
  Name := Trim(AName);
  if not CheckFileNamePart(Name, 'Имя проекта', AErrorText) then
    Exit;
  if not CheckFolderPath(AParentDir, AErrorText) then
    Exit;
  Dir := IncludeTrailingPathDelimiter(ExcludeTrailingPathDelimiter(
    Trim(AParentDir))) + Name;
  if not DirectoryExists(AParentDir) then
  begin
    AErrorText := 'Папка для проекта не найдена:' + LineEnding +
      ExcludeTrailingPathDelimiter(Trim(AParentDir));
    Exit;
  end;
  if DirectoryExists(Dir) or FileExists(Dir) then
  begin
    AErrorText := 'Проект с таким именем уже есть:' + LineEnding + Dir;
    Exit;
  end;
  if not CreateDir(Dir) then
  begin
    AErrorText := 'Не удалось создать папку проекта:' + LineEnding + Dir;
    Exit;
  end;
  Result := OpenProject(Dir, AErrorText);
end;

end.
