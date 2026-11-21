unit ProjectModel;
// Проект как объект, без интерфейса: папка проекта <имя>\ с одним CSV массива,
// папками слайсингов (имя начинается со slice, обычно slice_<алгоритм>\, и в них
// есть Slices.txt - так их находит ListSliceFolders) и папками синтезов synthes_<дата>\ внутри
// слайсинга. Синтез лежит в папке слайсинга, из которого взяты его слои, поэтому
// связь «синтез - слайсинг» задаёт расположение папки. Модель читает диск и
// ничего не меняет, кроме создания папки нового проекта. Нет CSV - проект пустой
// (массив ещё не создан); больше одного CSV - ошибка.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

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
    FArrayFile: string;
    FSlicings: TProjectSlicings;
    function GetName: string;
    function GetSlicingCount: Integer;
    function GetSlicing(AIndex: Integer): TProjectSlicing;
  public
    constructor Create(const ADir: string);
    // Перечитывает диск: массив, слайсинги, синтезы. Ошибка - False, текст
    // объясняет, и модель остаётся прежней.
    function Refresh(out AErrorText: string): Boolean;
    // Индекс слайсинга по имени его папки или -1.
    function IndexOfSlicing(const AName: string): Integer;
    // Индекс слайсинга, в папке которого лежит синтез (по полному пути
    // папки синтеза) или -1.
    function SlicingOfSynthesis(const ASynthesisFolder: string): Integer;

    // Папка проекта без разделителя на конце.
    property Dir: string read FDir;
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
// Открывает существующий проект. Нет папки, не папка проекта или несколько
// CSV - nil, текст объясняет.
function OpenProject(const ADir: string; out AErrorText: string): TProject;
// Создаёт папку нового проекта AParentDir\AName и открывает её. Папка
// AParentDir должна существовать, создаётся только папка проекта. Имя или
// путь недопустимы, родителя нет, папка уже есть, создать не удалось - nil,
// текст объясняет.
function CreateProject(const AParentDir, AName: string;
  out AErrorText: string): TProject;

implementation

uses
  AppPaths, OligoSlices, OligoArrayDocument, SynthesisFolder;

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

constructor TProject.Create(const ADir: string);
begin
  inherited Create;
  FDir := ExcludeTrailingPathDelimiter(ExpandFileName(ADir));
  // корень диска: 'D:' - это текущая папка диска, а не корень
  if (Length(FDir) = 2) and (FDir[2] = ':') then
    FDir := FDir + PathDelim;
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
  NewArrayFile, Second, RootDir: string;
  Folders: TStringArray;
  NewSlicings: TProjectSlicings;
  I: Integer;
begin
  Result := False;
  AErrorText := '';
  if not DirectoryExists(FDir) then
  begin
    AErrorText := 'Папка проекта не найдена:' + LineEnding + FDir;
    Exit;
  end;
  NewArrayFile := FindOtherProjectCsv(FDir, '');
  if NewArrayFile <> '' then
  begin
    Second := FindOtherProjectCsv(FDir, NewArrayFile);
    if Second <> '' then
    begin
      AErrorText := 'В проекте должен быть один файл массива (.csv), а найдено ' +
        'несколько:' + LineEnding + NewArrayFile + LineEnding + Second;
      Exit;
    end;
  end;

  RootDir := IncludeTrailingPathDelimiter(FDir);
  Folders := ListSliceFolders(FDir);
  SetLength(NewSlicings, Length(Folders));
  for I := 0 to High(Folders) do
  begin
    NewSlicings[I].Name := Folders[I];
    NewSlicings[I].Algorithm := SlicingAlgorithm(Folders[I]);
    NewSlicings[I].Folder := RootDir + Folders[I];
    NewSlicings[I].Syntheses := ScanSyntheses(NewSlicings[I].Folder);
  end;
  FArrayFile := NewArrayFile;
  FSlicings := NewSlicings;
  Result := True;
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

function OpenProject(const ADir: string; out AErrorText: string): TProject;
begin
  Result := TProject.Create(ADir);
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
