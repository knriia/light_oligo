unit ULaserActions;
// Действия лазера для вкладки «Последовательности»: параметры пера и
// геометрии из configs\laser.ini, создание EZD-файлов слоёв. Вкладка вызывает
// их через события, сама про лазер ничего не знает; связывает их
// AppComposition. Окон-вкладок у юнита нет.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoArray, OligoSlices;

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
    // Геометрия, с которой создаются EZD слоёв. Просмотр чертит занятые
    // ячейки массива AArr.
    procedure EditGeometry(const AArr: TOligoArr);
    // EZD-файл для каждого слоя ATable (по умолчанию в папке ezd рядом с
    // массивом, имя как у файла матрицы слоя) и Slices.lays с параметрами в
    // ASliceDir. True - созданы все, AResult - таблица с путями к EZD.
    function CreateEzd(const ASliceDir: string; const ATable: TSliceLayers;
      out AResult: TSliceLayers): Boolean;
    property OnLog: TLaserLogEvent read FOnLog write FOnLog;
  end;

implementation

uses
  Forms, Dialogs, AppPaths, MarkGeometry, LaserPen, LayerEzd, MarkEzdWriter,
  LaserConfigMigration, UFolderForm, UMarkGeometryForm, ULaserPenForm;

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

procedure TLaserActions.EditGeometry(const AArr: TOligoArr);
// Геометрия, с которой создаются EZD слоёв; хранится в configs\laser.ini
var
  Geometry: TMarkGeometry;
  ErrorText: String;
begin
  Geometry:=LoadMarkGeometry(LaserConfigPath);
  if not TMarkGeometryForm.Execute('Параметры геометрии', Geometry,
       OccupiedCellsMatrix(AArr)) then
    Exit;
  if not ForceDirectories(ConfigsDir) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+ConfigsDir);
    Exit;
  end;
  if not SaveMarkGeometry(LaserConfigPath, Geometry, ErrorText) then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
  end;
end;

function TLaserActions.CreateEzd(const ASliceDir: string;
  const ATable: TSliceLayers; out AResult: TSliceLayers): Boolean;
var
  Path, ErrorText: String;
  Geometry: TMarkGeometry;
  Writer: TMarkEzdWriter;
begin
  Result:=False;
  AResult:=nil;
  Geometry:=LoadMarkGeometry(LaserConfigPath);

  Path:=IncludeTrailingPathDelimiter(ASliceDir)+EZD_FOLDER;
  if not ChooseFolderForFiles('EZD-файлы слоёв',
       'Папка для EZD-файлов слоёв:', 'EZD-файлы слоёв',
       @ListLayerEzdFiles, @DeleteLayerEzdFiles, Path) then
    Exit;

  // Сообщение MarkEzd.dll при подключении (например, что плата маркера
  // не найдена) не закрываем: пользователь должен его увидеть.
  Writer:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    Result:=CreateSliceEzdFiles(Writer, ATable, Path, ASliceDir, Geometry,
      LoadLaserPen(LaserConfigPath), AResult, ErrorText);
  finally
    Writer.Free;
  end;
  if not Result then
  begin
    AResult:=nil; // после неудачи таблица может быть заполнена наполовину
    Log(ErrorText);
    ShowMessage(ErrorText);
    Exit;
  end;
  ShowMessage('Создано EZD-файлов слоёв: '+IntToStr(Length(AResult))+
              LineEnding+Path);
end;

end.
