unit ULaserActions;
// Действия лазера: параметры пера (вкладка «Последовательности»), геометрия
// и EZD-файлы слоёв синтеза (вкладка «Синтез»). Вкладки вызывают их через
// события и порты, про лазер ничего не знают; связывает их AppComposition.
// Параметры пера и последняя введённая геометрия хранятся в configs\laser.ini.
// Окон-вкладок у юнита нет.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoSlices;

type
  TLaserLogEvent = procedure(const AMsg: string) of object;

  { TLaserActions }

  TLaserActions = class
  private
    FOnLog: TLaserLogEvent;
    procedure Log(const AMsg: string);
  public
    // Переносит настройки лазера из sequences.ini в laser.ini; повторный
    // вызов безопасен.
    procedure LoadSettings;
    // Перо лазера, с которым создаются EZD слоёв.
    procedure EditLaserParams(Sender: TObject);
    // Слои синтеза по слайсу ASliceFolder (Slices.txt и матрицы слоёв):
    // окно геометрии (занятые ячейки - объединение матриц слоёв), затем EZD
    // всех слоёв в ASynthesisFolder\ezd и там же Slices.lays, geometry.ini и
    // laser.ini. True - созданы все слои, ALayers с путями к EZD. False и
    // ACancelled - оператор отказался на окне геометрии; False и текст в
    // AErrorText - ошибка, часть файлов могла остаться.
    function BuildSynthesisLayers(const ASliceFolder, ASynthesisFolder: string;
      out ALayers: TSliceLayers; out ACancelled: Boolean;
      out AErrorText: string): Boolean;
    // Геометрия синтеза (ASynthesisFolder\geometry.ini) только для просмотра,
    // на занятых ячейках слайса ASliceFolder. Слайса нет - только подложка.
    function ViewSynthesisGeometry(const ASliceFolder,
      ASynthesisFolder: string; out AErrorText: string): Boolean;
    property OnLog: TLaserLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  Forms, Dialogs, MatrixTypes, AppPaths, MarkGeometry, LaserPen, LayerEzd,
  MarkEzdWriter, LaserConfigMigration, UMarkGeometryForm, ULaserPenForm,
  UEzdProgressForm;

{ TLaserActions }

procedure TLaserActions.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
end;

procedure TLaserActions.LoadSettings;
var
  ErrorText: string;
begin
  if not MigrateLaserSettings(SequencesConfigPath, LaserConfigPath,
       ErrorText) then
    Log(ErrorText);
end;

procedure TLaserActions.EditLaserParams(Sender: TObject);
// Перо лазера, с которым создаются EZD слоёв; хранится в configs\laser.ini
var
  Pen: TLaserPen;
  Reader: TMarkEzdWriter;
  ErrorText: String;
begin
  Pen:=LoadLaserPen(LaserConfigPath);
  Reader:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    if not TLaserPenForm.Execute('Параметры лазера', Pen,
         @Reader.ReadDefaultPen) then
      Exit;
  finally
    Reader.Free;
  end;
  if not SaveLaserPen(LaserConfigPath, Pen, ErrorText) then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
  end;
end;

function TLaserActions.BuildSynthesisLayers(const ASliceFolder,
  ASynthesisFolder: string; out ALayers: TSliceLayers;
  out ACancelled: Boolean; out AErrorText: string): Boolean;
var
  Table: TSliceLayers;
  Occupied: TMatrix;
  Geometry: TMarkGeometry;
  Writer: TMarkEzdWriter;
  Progress: TEzdProgressForm;
  EzdPath, SaveError: string;
begin
  Result:=False;
  ALayers:=nil;
  ACancelled:=False;
  if not LoadSliceStatistics(IncludeTrailingPathDelimiter(ASliceFolder)+
       'Slices.txt', Table, AErrorText) then
    Exit;
  if not LoadOccupiedCells(Table, Occupied, AErrorText) then
    Exit;

  // окно открывается с последней введённой геометрией
  Geometry:=LoadMarkGeometry(LaserConfigPath);
  if not TMarkGeometryForm.Execute('Параметры геометрии', Geometry,
       Occupied) then
  begin
    ACancelled:=True;
    Exit;
  end;
  if ForceDirectories(ConfigsDir) and
     not SaveMarkGeometry(LaserConfigPath, Geometry, SaveError) then
    Log(SaveError);

  EzdPath:=IncludeTrailingPathDelimiter(ASynthesisFolder)+EZD_FOLDER;
  if not ForceDirectories(EzdPath) then
  begin
    AErrorText:='Не удалось создать папку EZD-файлов:'+LineEnding+EzdPath;
    Exit;
  end;

  // Сообщение MarkEzd.dll при подключении (например, что плата маркера
  // не найдена) не закрываем: пользователь должен его увидеть.
  Writer:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  Progress:=TEzdProgressForm.Create(Application);
  try
    Progress.Open;
    Result:=CreateSliceEzdFiles(Writer, Table, EzdPath, ASynthesisFolder,
      Geometry, LoadLaserPen(LaserConfigPath), ALayers, AErrorText,
      @Progress.Report);
  finally
    Progress.Free;
    Writer.Free;
  end;
  if not Result then
    ALayers:=nil; // после неудачи таблица может быть заполнена наполовину
end;

function TLaserActions.ViewSynthesisGeometry(const ASliceFolder,
  ASynthesisFolder: string; out AErrorText: string): Boolean;
var
  Table: TSliceLayers;
  Occupied: TMatrix;
  Geometry: TMarkGeometry;
  GeometryFile, CellsError: string;
begin
  Result:=False;
  AErrorText:='';
  GeometryFile:=IncludeTrailingPathDelimiter(ASynthesisFolder)+GEOMETRY_FILE;
  if not FileExists(GeometryFile) then
  begin
    AErrorText:='В папке синтеза нет файла геометрии:'+LineEnding+GeometryFile;
    Exit;
  end;
  Geometry:=LoadMarkGeometry(GeometryFile);
  // занятые ячейки берём из слайса; если его уже нет, показываем подложку
  Occupied:=nil;
  if not (LoadSliceStatistics(IncludeTrailingPathDelimiter(ASliceFolder)+
            'Slices.txt', Table, CellsError) and
          LoadOccupiedCells(Table, Occupied, CellsError)) then
  begin
    Occupied:=nil;
    Log('Геометрия синтеза: массив на подложке не показан. '+CellsError);
  end;
  TMarkGeometryForm.View('Геометрия синтеза', Geometry, Occupied);
  Result:=True;
end;

end.
