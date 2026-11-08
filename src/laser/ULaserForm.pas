unit ULaserForm;
// Вкладка «Лазер»: папка массива (единственный .csv и Slices.txt), параметры
// пера и геометрии из configs\laser.ini, EZD-файлы слоёв. Таблица слоёв,
// прочитанная из папки, уходит в синтез через OnLayersChanged.
// Форма встраивается во вкладку главного окна. Все элементы создаются кодом,
// поэтому файла .lfm у этой формы нет.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, IniFiles, OligoSlices,
  LaserArrayFolder;

type
  TLaserLogEvent = procedure(const AMsg: string) of object;
  // Слои для синтеза: загружены из папки массива или созданы заново.
  TLaserLayersEvent = procedure(const ALayers: TSliceLayers) of object;

  { TLaserForm }

  TLaserForm = class(TForm)
  private
    FLoaded: TLoadedArrayFolder; // папка массива и её слои; Folder='' - не выбрана
    B_ChooseArray: TButton;
    B_LaserParams: TButton;
    B_Geometry: TButton;
    B_CreateEzd: TButton;
    L_Folder: TLabel;
    L_Array: TLabel;
    L_Layers: TLabel;
    FOnLog: TLaserLogEvent;
    FOnLayersChanged: TLaserLayersEvent;
    procedure B_ChooseArrayClick(Sender: TObject);
    procedure B_LaserParamsClick(Sender: TObject);
    procedure B_GeometryClick(Sender: TObject);
    procedure B_CreateEzdClick(Sender: TObject);
    procedure Log(const AMsg: string);
    procedure LayersChanged(const ALayers: TSliceLayers);
    procedure ShowLoadedInfo;
    procedure LayoutButtons;
    // Перечитывает выбранную папку: за время работы массив и слои на диске
    // могли измениться (повторный слайсинг, пересохранение массива).
    // False - папка не выбрана или не читается (пользователь уже уведомлён).
    function ReloadFolder: Boolean;
    // Папка для EZD-файлов слоёв: если там уже есть EZD слоёв, заменить их
    // можно только с согласия. Папка создаётся.
    function ChooseEzdFolder(const ACaption, APrompt: string;
      var APath: string): Boolean;
  protected
    procedure DoShow; override;
    procedure Resize; override;
  public
    constructor Create(TheOwner: TComponent); override;
    // Надписи кнопок из файла интерфейса (раздел [LaserTab]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Переносит настройки лазера из sequences.ini в laser.ini; повторный
    // вызов безопасен.
    procedure LoadSettings;
    property OnLog: TLaserLogEvent read FOnLog write FOnLog;
    property OnLayersChanged: TLaserLayersEvent read FOnLayersChanged
      write FOnLayersChanged;
  end;

implementation

uses
  Dialogs, AppPaths, OligoArray, MarkGeometry, LaserPen, LayerEzd,
  MarkEzdWriter, LaserConfigMigration, UFolderForm, UMarkGeometryForm,
  ULaserPenForm;

{ TLaserForm }

constructor TLaserForm.Create(TheOwner: TComponent);
const
  MARGIN = 8;
  ROW_TOP = 4;
var
  Buttons: array of TButton;
  i: integer;
begin
  inherited CreateNew(TheOwner);

  Caption:='Лазер';
  Width:=760;
  Height:=200;

  B_ChooseArray:=TButton.Create(Self);
  B_ChooseArray.Name:='B_ChooseArray';
  B_ChooseArray.Parent:=Self;
  B_ChooseArray.Caption:='Папка массива';
  B_ChooseArray.OnClick:=@B_ChooseArrayClick;
  B_LaserParams:=TButton.Create(Self);
  B_LaserParams.Name:='B_LaserParams';
  B_LaserParams.Parent:=Self;
  B_LaserParams.Caption:='Параметры лазера';
  B_LaserParams.OnClick:=@B_LaserParamsClick;
  B_Geometry:=TButton.Create(Self);
  B_Geometry.Name:='B_Geometry';
  B_Geometry.Parent:=Self;
  B_Geometry.Caption:='Геометрия';
  B_Geometry.OnClick:=@B_GeometryClick;
  B_CreateEzd:=TButton.Create(Self);
  B_CreateEzd.Name:='B_CreateEzd';
  B_CreateEzd.Parent:=Self;
  B_CreateEzd.Caption:='Создать EZD';
  B_CreateEzd.OnClick:=@B_CreateEzdClick;

  // высота каждой кнопки - по одной, тогда ряд ровный при любом масштабе
  Buttons:=[B_ChooseArray, B_LaserParams, B_Geometry, B_CreateEzd];
  for i:=0 to High(Buttons) do
    Buttons[i].Height:=B_ChooseArray.Height;

  L_Folder:=TLabel.Create(Self);
  L_Folder.Name:='L_Folder';
  L_Folder.AutoSize:=False; // раскладку задаёт LayoutButtons, иначе цикл ChangeBounds
  L_Folder.Parent:=Self;
  L_Array:=TLabel.Create(Self);
  L_Array.Name:='L_Array';
  L_Array.AutoSize:=False;
  L_Array.Parent:=Self;
  L_Layers:=TLabel.Create(Self);
  L_Layers.Name:='L_Layers';
  L_Layers.AutoSize:=False;
  L_Layers.Parent:=Self;
  ShowLoadedInfo;

  LayoutButtons;
end;

procedure TLaserForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  B_ChooseArray.Caption:=AIni.ReadString('LaserTab','B_ChooseArray',
    'Папка массива');
  B_LaserParams.Caption:=AIni.ReadString('LaserTab','B_LaserParams',
    'Параметры лазера');
  B_Geometry.Caption:=AIni.ReadString('LaserTab','B_Geometry','Геометрия');
  B_CreateEzd.Caption:=AIni.ReadString('LaserTab','B_CreateEzd','Создать EZD');
  LayoutButtons;
end;

procedure TLaserForm.LayoutButtons;
// Кнопки в один ряд слева направо, ширина каждой - по её надписи.
const
  GAP = 8;
  ROW_TOP = 4;
  MARGIN = 8;
var
  X, Y, i: Integer;
  Buttons: array of TButton;
  Labels: array of TLabel;

  function LabelHeight(ALabel: TLabel): Integer;
  var
    W, H: Integer;
  begin
    W:=0;
    H:=0;
    ALabel.GetPreferredSize(W, H);
    if H<=0 then
      H:=ALabel.Height;
    Result:=H;
  end;

  function TextWidth(AButton: TButton): Integer;
  var
    W, H: Integer;
  begin
    W:=0;
    H:=0;
    AButton.GetPreferredSize(W, H);
    if W<=0 then // окно кнопки ещё не создано
      W:=AButton.Width;
    Result:=W;
  end;

begin
  Buttons:=[B_ChooseArray, B_LaserParams, B_Geometry, B_CreateEzd];
  X:=8;
  for i:=0 to High(Buttons) do
  begin
    Buttons[i].SetBounds(X, ROW_TOP, TextWidth(Buttons[i]), Buttons[i].Height);
    Buttons[i].TabOrder:=i;
    Inc(X, Buttons[i].Width+GAP);
  end;
  // метки без AutoSize (иначе цикл ChangeBounds): ширину, высоту и Top
  // задаём здесь; длинный путь виден целиком во всплывающей подсказке
  Y:=ROW_TOP+B_ChooseArray.Height+10;
  Labels:=[L_Folder, L_Array, L_Layers];
  for i:=0 to High(Labels) do
  begin
    Labels[i].SetBounds(MARGIN, Y, ClientWidth-2*MARGIN, LabelHeight(Labels[i]));
    Inc(Y, Labels[i].Height+6);
  end;
end;

procedure TLaserForm.DoShow;
begin
  inherited DoShow;
  // окно кнопок создано: ширину по подписи теперь можно измерить точно
  LayoutButtons;
end;

procedure TLaserForm.Resize;
begin
  inherited Resize;
  if Assigned(L_Layers) then
    LayoutButtons;
end;

procedure TLaserForm.LoadSettings;
var
  ErrorText: string;
begin
  if not MigrateLaserSettings(SequencesConfigPath, LaserConfigPath,
       ErrorText) then
    Log(ErrorText);
end;

procedure TLaserForm.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
end;

procedure TLaserForm.LayersChanged(const ALayers: TSliceLayers);
begin
  if Assigned(FOnLayersChanged) then
    FOnLayersChanged(ALayers);
end;

procedure TLaserForm.ShowLoadedInfo;
// Пути и размеры в метках: они не должны обрезаться формой.
var
  Rows, Cols: integer;
begin
  if FLoaded.Folder='' then
  begin
    L_Folder.Caption:='Папка массива не выбрана';
    L_Array.Caption:='Массив: -';
    L_Layers.Caption:='Слои: -';
  end
  else
  begin
    Rows:=Length(FLoaded.Arr);
    if Rows>0 then
      Cols:=Length(FLoaded.Arr[0])
    else
      Cols:=0;
    L_Folder.Caption:='Папка массива: '+FLoaded.Folder;
    L_Array.Caption:=Format('Массив: %d x %d', [Rows, Cols]);
    L_Layers.Caption:='Слои: '+IntToStr(Length(FLoaded.Table));
    if FLoaded.SlicesOutdated then
      L_Layers.Caption:=L_Layers.Caption+
        ' (массив сохранён после слайсинга, слои могут не соответствовать ему)';
  end;
  L_Folder.Hint:=L_Folder.Caption;
  L_Array.Hint:=L_Array.Caption;
  L_Layers.Hint:=L_Layers.Caption;
  L_Folder.ShowHint:=True;
  L_Array.ShowHint:=True;
  L_Layers.ShowHint:=True;
  if Width>0 then
    LayoutButtons;
end;

function TLaserForm.ReloadFolder: Boolean;
var
  NewFolder: TLoadedArrayFolder;
  ErrorText: string;
begin
  Result:=False;
  if FLoaded.Folder='' then
  begin
    ShowMessage('Сначала выберите папку массива.');
    Exit;
  end;
  if not LoadArrayFolder(FLoaded.Folder, NewFolder, ErrorText) then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
    Exit;
  end;
  FLoaded:=NewFolder;
  ShowLoadedInfo;
  Result:=True;
end;

procedure TLaserForm.B_ChooseArrayClick(Sender: TObject);
// Папка с единственным .csv массива и Slices.txt. При ошибке прежняя
// папка остаётся выбранной.
var
  Folder, ErrorText: string;
  NewFolder: TLoadedArrayFolder;
begin
  // Окно выбора просто начнёт с этой папки, поэтому отказ в её создании
  // не мешает работе.
  Folder:=ArraysDir;
  try
    ForceDirectories(Folder);
  except
    // нет прав - окно выбора покажет ближайшую существующую папку
  end;
  if FLoaded.Folder<>'' then
    Folder:=FLoaded.Folder;

  if not TFolderForm.Execute('Папка массива', 'Папка с файлом массива (*.csv)'+
       ' и Slices.txt:', Folder) then
    Exit;
  try
    ForceDirectories(Folder);
  except
    // нет прав - LoadArrayFolder сообщит, что папки нет
  end;

  if not LoadArrayFolder(Folder, NewFolder, ErrorText) then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
    Exit;
  end;
  FLoaded:=NewFolder;
  ShowLoadedInfo;
end;

procedure TLaserForm.B_LaserParamsClick(Sender: TObject);
// Перо лазера, с которым создаются EZD слоёв; хранится в configs\laser.ini
var
  Pen: TLaserPen;
  Reader: TMarkEzdWriter;
  ErrorText: String;
begin
  Pen:=LoadLaserPen(LaserConfigPath);
  Reader:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    if not TLaserPenForm.Execute('Параметры лазера (вкладка «Лазер»)',
         Pen, @Reader.ReadDefaultPen) then
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

procedure TLaserForm.B_GeometryClick(Sender: TObject);
// Геометрия, с которой создаются EZD слоёв; хранится в configs\laser.ini.
// Просмотр чертит занятые ячейки массива, поэтому массив должен быть выбран.
var
  Geometry: TMarkGeometry;
  ErrorText: String;
begin
  if not ReloadFolder then
    Exit;
  Geometry:=LoadMarkGeometry(LaserConfigPath);
  if not TMarkGeometryForm.Execute('Параметры геометрии', Geometry,
       OccupiedCellsMatrix(FLoaded.Arr)) then
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

function TLaserForm.ChooseEzdFolder(const ACaption, APrompt: string;
  var APath: string): Boolean;
// Логика та же, что в TSequencesForm.ChooseLayerFolder.
var
  Existing: TStringArray;
  ErrorText: String;
begin
  Result:=False;
  repeat
    if not TFolderForm.Execute(ACaption, APrompt, APath) then
      Exit;
    Existing:=ListLayerEzdFiles(APath);
    if Length(Existing)>0 then
    begin
      if MessageDlg('В папке уже есть EZD-файлы слоёв ('+
           IntToStr(Length(Existing))+'):'+LineEnding+APath+LineEnding+
           'Удалить их и записать новые?', mtConfirmation,
           [mbYes, mbNo], 0)<>mrYes then
        Continue;
      if not DeleteLayerEzdFiles(APath, ErrorText) then
      begin
        ShowMessage(ErrorText);
        Exit;
      end;
    end;
    Break;
  until false;
  Result:=ForceDirectories(APath);
  if not Result then
    ShowMessage('Не удалось создать папку:'+LineEnding+APath);
end;

procedure TLaserForm.B_CreateEzdClick(Sender: TObject);
// EZD-файл для каждого слоя (по умолчанию в папке ezd рядом с массивом,
// имя как у файла матрицы слоя) и Slices.lays с параметрами рядом с массивом.
var
  Path, ErrorText: String;
  Geometry: TMarkGeometry;
  Writer: TMarkEzdWriter;
  Table: TSliceLayers;
  Done: Boolean;
begin
  if not ReloadFolder then
    Exit;
  if FLoaded.SlicesOutdated and
     (MessageDlg('Массив сохранён позже слайсинга: слои могут не '+
        'соответствовать ему.'+LineEnding+
        'Создать EZD по этим слоям? Если массив правили, лучше сначала '+
        'выполнить слайсинг заново.', mtWarning, [mbYes, mbNo], 0)<>mrYes) then
    Exit;
  Geometry:=LoadMarkGeometry(LaserConfigPath);

  Path:=FLoaded.Folder+PathDelim+EZD_FOLDER;
  if not ChooseEzdFolder('EZD-файлы слоёв', 'Папка для EZD-файлов слоёв:',
       Path) then
    Exit;

  // Сообщение MarkEzd.dll при подключении (например, что плата маркера
  // не найдена) не закрываем: пользователь должен его увидеть.
  Writer:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    Done:=CreateSliceEzdFiles(Writer, FLoaded.Table, Path, FLoaded.Folder,
      Geometry, LoadLaserPen(LaserConfigPath), Table, ErrorText);
  finally
    Writer.Free;
  end;
  if not Done then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
    Exit;
  end;
  FLoaded.Table:=Table;
  ShowLoadedInfo;
  LayersChanged(Table); // синтез можно запускать сразу
  ShowMessage('Создано EZD-файлов слоёв: '+IntToStr(Length(Table))+LineEnding+
              Path);
end;

end.
