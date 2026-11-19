unit USequencesForm;
// Вкладка «Последовательности»: массив олигов, слайсинг, кнопки лазера.
// Форма встраивается во вкладку главного окна. Журнал и действия лазера
// (параметры пера, геометрия, создание EZD) она получает от главного окна
// через события и про модуль лазера ничего не знает.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, IniFiles, OligoArray, OligoArrayDocument, OligoSlices, GridWidthMode;

type
  TSequencesLogEvent = procedure(const AMsg: string) of object;
  // Таблица слоёв массива изменилась (слайсинг, EZD-файлы) или сброшена
  // (пустая): синтез берёт слои отсюда.
  TSequencesLayersEvent = procedure(const ALayers: TSliceLayers) of object;
  // Параметры геометрии маркировки: окно чертит занятые ячейки массива.
  TSequencesGeometryEvent = procedure(const AArr: TOligoArr) of object;
  // EZD-файлы для слоёв ATable (Slices.txt лежит в ASliceDir). True - созданы
  // все, AResult - таблица с путями к EZD.
  TSequencesCreateEzdEvent = function(const ASliceDir: string;
    const ATable: TSliceLayers; out AResult: TSliceLayers): Boolean of object;

  { TSequencesForm }

  TSequencesForm = class(TForm)
    B_CreateEzd: TButton;
    B_CreateOligoArr: TButton;
    B_Geometry: TButton;
    B_LaserParams: TButton;
    B_LoadOligoArr: TButton;
    B_SaveOligoArr: TButton;
    B_SliceOligoArr: TButton;
    GB_OligControl: TGroupBox;
    OD_File: TOpenDialog;
    P_OligoArr: TPanel;
    SG_OligoArr: TStringGrid;
    procedure B_CreateEzdClick(Sender: TObject);
    procedure B_CreateOligoArrClick(Sender: TObject);
    procedure B_GeometryClick(Sender: TObject);
    procedure B_LaserParamsClick(Sender: TObject);
    procedure B_LoadOligoArrClick(Sender: TObject);
    procedure B_SaveOligoArrClick(Sender: TObject);
    procedure B_SliceOligoArrClick(Sender: TObject);
    procedure SG_OligoArrEditingDone(Sender: TObject);
    procedure SG_OligoArrHeaderClick(Sender: TObject; IsColumn: Boolean;
      Index: Integer);
    procedure SG_OligoArrKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure SG_OligoArrSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
  private
    FEditedCol: Integer;
    FEditedRow: Integer;
    FDocument: TOligoArrayDocument;
    FWidthMode: TGridWidthMode;
    FOnLog: TSequencesLogEvent;
    FOnLayersChanged: TSequencesLayersEvent;
    FOnEditLaserParams: TNotifyEvent;
    FOnEditGeometry: TSequencesGeometryEvent;
    FOnCreateEzd: TSequencesCreateEzdEvent;
    procedure LayersChanged(const ALayers: TSliceLayers);
    procedure Log(const AMsg: string);
    procedure DisplayOligoArray;
    procedure ApplyWidthMode;
    procedure StoreCell(ACol, ARow: Integer);
    function SaveArray: Boolean;
    function ConfirmSaveIfModified: Boolean;
    function RequireArray: Boolean;
    procedure UpdateLaserButtons;
    procedure SetOnEditLaserParams(AValue: TNotifyEvent);
    procedure SetOnEditGeometry(AValue: TSequencesGeometryEvent);
    procedure SetOnCreateEzd(AValue: TSequencesCreateEzdEvent);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Надписи кнопок из файла интерфейса (раздел [Oligo]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Перед закрытием программы: несохранённый массив предлагаем сохранить.
    // False - пользователь отменил закрытие.
    function CanCloseFromHost: Boolean;
    property OnLog: TSequencesLogEvent read FOnLog write FOnLog;
    property OnLayersChanged: TSequencesLayersEvent read FOnLayersChanged
      write FOnLayersChanged;
    // Кнопки лазера доступны, только когда назначено их событие.
    property OnEditLaserParams: TNotifyEvent read FOnEditLaserParams
      write SetOnEditLaserParams;
    property OnEditGeometry: TSequencesGeometryEvent read FOnEditGeometry
      write SetOnEditGeometry;
    property OnCreateEzd: TSequencesCreateEzdEvent read FOnCreateEzd
      write SetOnCreateEzd;
  end;

implementation

uses
  LCLType, Clipbrd, AppPaths, CommonUtils, OligoSlicing,
  OligoPaste, UOligoArrayForm, UArraySaveForm, UFolderForm, ULayerChartForm;

{$R *.lfm}

{ TSequencesForm }

constructor TSequencesForm.Create(TheOwner: TComponent);
begin
  FDocument:=TOligoArrayDocument.Create;
  inherited Create(TheOwner);
  UpdateLaserButtons;
end;

destructor TSequencesForm.Destroy;
begin
  inherited Destroy;
  FDocument.Free;
end;

procedure TSequencesForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_OligControl.Caption:=AIni.ReadString('Oligo','GB_OligControl','Control');
  B_CreateOligoArr.Caption:=AIni.ReadString('Oligo','B_CreateOligoArr','Create');
  B_LoadOligoArr.Caption:=AIni.ReadString('Oligo','B_LoadOligoArr','Load');
  B_SaveOligoArr.Caption:=AIni.ReadString('Oligo','B_SaveOligoArr','Save');
  B_SliceOligoArr.Caption:=AIni.ReadString('Oligo','B_SliceOligoArr','Slicing');
  B_LaserParams.Caption:=AIni.ReadString('Oligo','B_LaserParams','Laser parameters');
  B_Geometry.Caption:=AIni.ReadString('Oligo','B_Geometry','Geometry parameters');
  B_CreateEzd.Caption:=AIni.ReadString('Oligo','B_CreateEzd','Create EZD');
end;

procedure TSequencesForm.UpdateLaserButtons;
begin
  B_LaserParams.Enabled:=Assigned(FOnEditLaserParams);
  B_Geometry.Enabled:=Assigned(FOnEditGeometry);
  B_CreateEzd.Enabled:=Assigned(FOnCreateEzd);
end;

procedure TSequencesForm.SetOnEditLaserParams(AValue: TNotifyEvent);
begin
  FOnEditLaserParams:=AValue;
  UpdateLaserButtons;
end;

procedure TSequencesForm.SetOnEditGeometry(AValue: TSequencesGeometryEvent);
begin
  FOnEditGeometry:=AValue;
  UpdateLaserButtons;
end;

procedure TSequencesForm.SetOnCreateEzd(AValue: TSequencesCreateEzdEvent);
begin
  FOnCreateEzd:=AValue;
  UpdateLaserButtons;
end;

function TSequencesForm.RequireArray: Boolean;
// действия над массивом: пустой массив - сообщение и отказ
begin
  Result:=not FDocument.IsEmpty;
  if not Result then
    ShowMessage('Массив пуст.');
end;

procedure TSequencesForm.LayersChanged(const ALayers: TSliceLayers);
begin
  if Assigned(FOnLayersChanged) then
    FOnLayersChanged(ALayers);
end;

procedure TSequencesForm.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
end;

procedure TSequencesForm.DisplayOligoArray;
// массив олигов в таблицу: строка 0 и столбец 0 - заголовки
var
  i,j: Integer;
begin
  SG_OligoArr.Clear;
  SG_OligoArr.RowCount:=Length(FDocument.Arr)+1;
  if FDocument.IsEmpty then
    SG_OligoArr.ColCount:=1
  else
    SG_OligoArr.ColCount:=Length(FDocument.Arr[0])+1;
  for i:=0 to High(FDocument.Arr) do
    for j:=0 to High(FDocument.Arr[i]) do
      SG_OligoArr.Cells[j+1, i+1]:=FDocument.Arr[i][j];
  NumerateGrid(SG_OligoArr);
  FWidthMode:=gwmDefault;
  ApplyWidthMode;
end;

procedure TSequencesForm.ApplyWidthMode;
var
  i: integer;
begin
  for i:=1 to SG_OligoArr.ColCount-1 do
    case FWidthMode of
      gwmDefault: SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultColWidth;
      gwmLongest: AutoSizeGridColumn(SG_OligoArr, i);
      gwmSquare: SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultRowHeight;
    end;
end;

procedure TSequencesForm.StoreCell(ACol, ARow: Integer);
// ячейку таблицы в массив; ячейки вне массива не трогаем
begin
  if FDocument.SetCell(ARow-1, ACol-1, SG_OligoArr.Cells[ACol,ARow]) then
    SG_OligoArr.Cells[ACol,ARow]:=FDocument.Cell(ARow-1, ACol-1);
end;

procedure TSequencesForm.SG_OligoArrHeaderClick(Sender: TObject;
  IsColumn: Boolean; Index: Integer);
// клик по углу таблицы переключает ширину ячеек (см. GridWidthMode)
begin
  if not IsColumn or (Index<>0) then
    Exit;
  FWidthMode:=NextGridWidthMode(FWidthMode);
  ApplyWidthMode;
end;

procedure TSequencesForm.SG_OligoArrKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
// после Ctrl+V переносим всю таблицу в массив и сообщаем,
// если таблица отбросила часть вставленных данных
var
  i,j: integer;
  Msg: string;
begin
  if (Key<>VK_V) or (Shift<>[ssCtrl]) then
    Exit;
  for i:=1 to SG_OligoArr.RowCount-1 do
    for j:=1 to SG_OligoArr.ColCount-1 do
      StoreCell(j, i);
  if not CheckPasteFits(Clipboard.AsText, SG_OligoArr.Selection.Top,
       SG_OligoArr.Selection.Left, SG_OligoArr.RowCount, SG_OligoArr.ColCount,
       Msg) then
    ShowMessage(Msg);
end;

procedure TSequencesForm.SG_OligoArrSetEditText(Sender: TObject; ACol,
  ARow: Integer; const Value: string);
// запоминаем редактируемую ячейку
begin
  FEditedCol:=ACol;
  FEditedRow:=ARow;
end;

procedure TSequencesForm.SG_OligoArrEditingDone(Sender: TObject);
begin
  StoreCell(FEditedCol, FEditedRow);
end;

procedure TSequencesForm.B_LoadOligoArrClick(Sender: TObject);
var
  ErrorText: String;
begin
  if not ConfirmSaveIfModified then // загруженный массив заменит текущий
    Exit;
  OD_File.Filter:='CSV Files|*.csv';
  OD_File.InitialDir:=ProjectsDir;
  OD_File.FilterIndex:=1;
  if not OD_File.Execute then
    Exit;
  if not FDocument.LoadFromFile(OD_File.FileName, ErrorText) then
  begin
    ShowMessage('Не удалось прочитать файл массива:'+LineEnding+
                OD_File.FileName+LineEnding+ErrorText);
    Exit;
  end;
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SaveOligoArrClick(Sender: TObject);
begin
  SaveArray;
end;

function TSequencesForm.SaveArray: Boolean;
// Сохранение массива в проект <папка проектов>\<имя>\<имя>.csv: место по
// умолчанию предлагает документ, но можно выбрать любую папку проектов.
// В папке проекта должен быть ровно один CSV.
var
  Folder, ProjectName, ArrayFile, FilePath, ErrorText, OtherCsv: String;
begin
  Result:=False;
  FDocument.SuggestProjectLocation(ProjectsDir, Now, Folder, ProjectName);
  if FDocument.HasFile then
    ArrayFile:=ChangeFileExt(ExtractFileName(FDocument.FileName), '')
  else
    ArrayFile:=DEFAULT_ARRAY_FILE;

  // спрашиваем, пока не получим допустимое место и согласие на перезапись
  repeat
    if not TArraySaveForm.Execute(Folder, ProjectName, ArrayFile, FilePath) then
      Exit;
    OtherCsv:=FindOtherProjectCsv(ExtractFileDir(FilePath), FilePath);
    if OtherCsv<>'' then
    begin
      ShowMessage('В папке проекта уже есть другой CSV:'+LineEnding+OtherCsv+
                  LineEnding+'В проекте должен быть один CSV. Выберите другое имя проекта.');
      Continue;
    end;
    if FileExists(FilePath) and
       (MessageDlg('Файл уже существует:'+LineEnding+FilePath+LineEnding+
                   'Перезаписать его?', mtConfirmation, [mbYes, mbNo], 0)<>mrYes) then
      Continue;
    Break;
  until false;

  if not ForceDirectories(ExtractFileDir(FilePath)) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+ExtractFileDir(FilePath));
    Exit;
  end;

  Result:=FDocument.SaveToFile(FilePath, ErrorText);
  if not Result then
    ShowMessage('Не удалось сохранить массив:'+LineEnding+FilePath+LineEnding+
                ErrorText);
end;

function TSequencesForm.ConfirmSaveIfModified: Boolean;
// Перед действием, после которого несохранённые данные пропадут.
// True - можно продолжать (сохранили или отказались сохранять),
// False - отмена или сохранение не удалось.
begin
  Result:=True;
  if FDocument.IsEmpty or not FDocument.Modified then
    Exit;
  case MessageDlg('Массив не сохранён. Сохранить его?', mtConfirmation,
         [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result:=SaveArray;
    mrNo: Result:=True;
  else
    Result:=False;
  end;
end;

function TSequencesForm.CanCloseFromHost: Boolean;
begin
  Result:=ConfirmSaveIfModified;
end;

procedure TSequencesForm.B_CreateOligoArrClick(Sender: TObject);
// окно параметров нового массива: пустой, случайный или одна последовательность
var
  Rows, Cols, RandomLength: Integer;
  Fill: TOligoFill;
  ConstSeq: String;
begin
  if not ConfirmSaveIfModified then // новый массив заменит текущий
    Exit;
  if not OligoArrayForm.Execute(Rows, Cols, Fill, RandomLength, ConstSeq) then
    Exit;
  LayersChanged(nil); // слайс-таблица старого массива больше не нужна
  FDocument.NewArray(CreateOligoArray(Rows, Cols, Fill, RandomLength, ConstSeq));
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива в папку слайса (по умолчанию <папка проекта>\slice, имя и
// место можно изменить): Slices.txt и папка layers с матрицами слоёв
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  i: integer;
  Path, ErrorText: String;
begin
  if not RequireArray then
    Exit;
  // папка слайса по умолчанию лежит в папке проекта и должна совпадать с
  // массивом, поэтому без сохранения нарезать нельзя: только "Сохранить" или "Отмена"
  if not FDocument.HasFile or FDocument.Modified then
  begin
    if MessageDlg('Массив не сохранён. Сохранить его?'+LineEnding+
                  'Слайсинг записывается в папку проекта.',
                  mtConfirmation, [mbYes, mbCancel], 0)<>mrYes then
      Exit;
    if not SaveArray then
      Exit;
  end;

  Path:=IncludeTrailingPathDelimiter(FDocument.ArrayDir)+SLICE_FOLDER;
  if not ChooseFolderForFiles('Слайсинг', 'Папка слайсинга (Slices.txt и layers):',
       'файлы слайсинга', @ListSliceFiles, @DeleteSliceFiles, Path) then
    Exit;

  // показываем уникальные буквы массива
  ShowMessage(SymbolsToString(CollectSymbols(FDocument.Arr)));

  // прежние слои этого массива больше не действительны
  FDocument.ForgetSlicing;
  if not SliceArrayIntoFolder(FDocument.Arr, Path, Layers, Table,
       ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  FDocument.SetSlicing(Table, Path);
  LayersChanged(Table); // общая таблица слоёв (её использует синтез)

  LayerChartForm.LS_CharsInLayers.Clear;
  for i:=0 to High(Layers) do
    LayerChartForm.LS_CharsInLayers.AddXY(Layers[i].Number, Layers[i].Count,
                                          Layers[i].Letter);
  LayerChartForm.ShowModal;
end;

procedure TSequencesForm.B_LaserParamsClick(Sender: TObject);
begin
  if Assigned(FOnEditLaserParams) then
    FOnEditLaserParams(Self);
end;

procedure TSequencesForm.B_GeometryClick(Sender: TObject);
// окно параметров геометрии чертит занятые ячейки массива, поэтому он нужен
begin
  if not RequireArray then
    Exit;
  FOnEditGeometry(FDocument.Arr); // кнопка доступна, только если событие назначено
end;

procedure TSequencesForm.B_CreateEzdClick(Sender: TObject);
// EZD слоёв создаются по слайсингу этого массива и пишутся рядом с ним.
// Правка массива слайсинг сбрасывает, поэтому "нет слайсинга" включает и
// несохранённый массив: слайсинг сам предложит его сохранить.
var
  Table: TSliceLayers;
begin
  if not RequireArray then
    Exit;
  if not FDocument.HasSlicing then
  begin
    if not FDocument.HasFile or FDocument.Modified then
      ShowMessage('Массив не сохранён и не нарезан на слои.'+LineEnding+
                  'Выполните слайсинг: он предложит сохранить массив.')
    else
      ShowMessage('Сначала выполните слайсинг массива.');
    Exit;
  end;
  if not FOnCreateEzd(FDocument.SliceDir, FDocument.SliceTable, Table) then
    Exit;
  FDocument.SetSlicing(Table, FDocument.SliceDir);
  LayersChanged(Table); // синтез можно запускать сразу
end;

end.
