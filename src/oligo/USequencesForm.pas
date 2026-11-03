unit USequencesForm;
// Вкладка «Последовательности»: массив олигов, слайсинг, EZD-файлы слоёв.
// Форма встраивается во вкладку главного окна. Журнал и окно настроек
// лазера она получает от главного окна через события. Геометрия маркировки
// у вкладки своя - в configs\sequences.ini.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, IniFiles, MarkGeometry, OligoArrayDocument, OligoSlices, GridWidthMode;

type
  TSequencesLogEvent = procedure(const AMsg: string) of object;
  TListLayerFilesFunc = function(const aDir: String): TStringArray;
  TDeleteLayerFilesFunc = function(const aDir: String;
    out aErrorText: String): Boolean;

  { TSequencesForm }

  TSequencesForm = class(TForm)
    B_ClearOligoArr: TButton;
    B_CloseOligoArr: TButton;
    B_CreateLayerEzd: TButton;
    B_CreateOligoArr: TButton;
    B_LoadOligoArr: TButton;
    B_SaveOligoArr: TButton;
    B_GeometryParams: TButton;
    B_LaserParams: TButton;
    B_SliceOligoArr: TButton;
    GB_OligControl: TGroupBox;
    OD_File: TOpenDialog;
    P_OligoArr: TPanel;
    SG_OligoArr: TStringGrid;
    procedure B_ClearOligoArrClick(Sender: TObject);
    procedure B_CloseOligoArrClick(Sender: TObject);
    procedure B_CreateLayerEzdClick(Sender: TObject);
    procedure B_CreateOligoArrClick(Sender: TObject);
    procedure B_LoadOligoArrClick(Sender: TObject);
    procedure B_SaveOligoArrClick(Sender: TObject);
    procedure B_GeometryParamsClick(Sender: TObject);
    procedure B_LaserParamsClick(Sender: TObject);
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
    FOnShowLaserSettings: TNotifyEvent;
    procedure Log(const AMsg: string);
    procedure DisplayOligoArray;
    procedure ApplyWidthMode;
    procedure StoreCell(ACol, ARow: Integer);
    procedure LayoutButtons;
    function SaveArray: Boolean;
    function ConfirmSaveIfModified: Boolean;
    function ChooseLayerFolder(const ACaption, APrompt, AFilesName: string;
      AListFiles: TListLayerFilesFunc; ADeleteFiles: TDeleteLayerFilesFunc;
      var APath: string): Boolean;
  protected
    procedure DoShow; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Надписи кнопок из файла интерфейса (раздел [Oligo]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Перед закрытием программы: несохранённый массив предлагаем сохранить.
    // False - пользователь отменил закрытие.
    function CanCloseFromHost: Boolean;
    property OnLog: TSequencesLogEvent read FOnLog write FOnLog;
    property OnShowLaserSettings: TNotifyEvent
      read FOnShowLaserSettings write FOnShowLaserSettings;
  end;

implementation

uses
  LCLType, Clipbrd, AppState, AppPaths, CommonUtils, OligoArray, OligoSlicing,
  LayerEzd, MarkEzdWriter, OligoPaste, UOligoArrayForm, UArraySaveForm,
  UFolderForm, ULayerChartForm, UMarkGeometryForm;

{$R *.lfm}

{ TSequencesForm }

constructor TSequencesForm.Create(TheOwner: TComponent);
begin
  FDocument:=TOligoArrayDocument.Create;
  inherited Create(TheOwner);
end;

destructor TSequencesForm.Destroy;
begin
  inherited Destroy;
  FDocument.Free;
end;

procedure TSequencesForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_OligControl.Caption:=AIni.ReadString('Oligo','GB_OligControl','Oligonucleotides');
  B_CreateOligoArr.Caption:=AIni.ReadString('Oligo','B_CreateOligoArr','Create array');
  B_ClearOligoArr.Caption:=AIni.ReadString('Oligo','B_ClearOligoArr','Clear array');
  B_CloseOligoArr.Caption:=AIni.ReadString('Oligo','B_CloseOligoArr','Remove array');
  B_LoadOligoArr.Caption:=AIni.ReadString('Oligo','B_LoadOligoArr','Load array');
  B_SaveOligoArr.Caption:=AIni.ReadString('Oligo','B_SaveOligoArr','Save array');
  B_SliceOligoArr.Caption:=AIni.ReadString('Oligo','B_SliceOligoArr','Slicing');
  B_LaserParams.Caption:=AIni.ReadString('Oligo','B_LaserParams','Laser parameters');
  B_GeometryParams.Caption:=AIni.ReadString('Oligo','B_GeometryParams','Geometry parameters');
  B_CreateLayerEzd.Caption:=AIni.ReadString('Oligo','B_CreateLayerEzd','EZD files');
  LayoutButtons;
end;

procedure TSequencesForm.DoShow;
begin
  inherited DoShow;
  LayoutButtons; // окна кнопок уже созданы - ширина текста известна точно
end;

procedure TSequencesForm.LayoutButtons;
// Кнопки стоят в один ряд слева направо, ширина каждой - по её надписи.
const
  GAP = 8;
  ROW_TOP = 4;
  ROW_BOTTOM = 6;
var
  X, i: Integer;
  Buttons: array of TButton;

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
  Buttons:=[B_CreateOligoArr, B_LoadOligoArr, B_SaveOligoArr, B_ClearOligoArr,
            B_CloseOligoArr, B_SliceOligoArr, B_LaserParams, B_GeometryParams,
            B_CreateLayerEzd];
  X:=8;
  for i:=0 to High(Buttons) do
  begin
    Buttons[i].SetBounds(X, ROW_TOP, TextWidth(Buttons[i]), Buttons[i].Height);
    Buttons[i].TabOrder:=i; // Tab ходит по кнопкам в том же порядке
    Inc(X, Buttons[i].Width+GAP);
  end;
  // группа по высоте ровно под один ряд кнопок, остальное место - таблице
  GB_OligControl.ClientHeight:=ROW_TOP+B_CreateOligoArr.Height+ROW_BOTTOM;
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
  OD_File.InitialDir:=ArraysDir;
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
// Сохранение массива: место по умолчанию предлагает документ,
// но можно выбрать любую папку.
var
  Folder, FileName, FilePath, ErrorText: String;
begin
  Result:=False;
  FDocument.SuggestSaveLocation(ArraysDir, Now, Folder, FileName);

  // спрашиваем, пока не получим согласие на перезапись существующего файла
  repeat
    if not TArraySaveForm.Execute(Folder, FileName, FilePath) then
      Exit;
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

function TSequencesForm.ChooseLayerFolder(const ACaption, APrompt,
  AFilesName: string; AListFiles: TListLayerFilesFunc;
  ADeleteFiles: TDeleteLayerFilesFunc; var APath: string): Boolean;
// Папка для файлов слоёв. Если в ней уже есть такие файлы - только с
// согласия их удалить, иначе снова спрашиваем папку. Папка создаётся.
var
  Existing: TStringArray;
  ErrorText: String;
begin
  Result:=False;
  repeat
    if not TFolderForm.Execute(ACaption, APrompt, APath) then
      Exit;
    Existing:=AListFiles(APath);
    if Length(Existing)>0 then
    begin
      if MessageDlg('В папке уже есть '+AFilesName+' ('+
           IntToStr(Length(Existing))+'):'+LineEnding+APath+LineEnding+
           'Удалить их и записать новые?', mtConfirmation,
           [mbYes, mbNo], 0)<>mrYes then
        Continue;
      if not ADeleteFiles(APath, ErrorText) then
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

procedure TSequencesForm.B_ClearOligoArrClick(Sender: TObject);
// стираем содержимое ячеек, размер массива остаётся
begin
  if FDocument.IsEmpty then
    Exit;
  if not ConfirmSaveIfModified then
    Exit;
  FDocument.ClearCells;
  DisplayOligoArray;
end;

procedure TSequencesForm.B_CloseOligoArrClick(Sender: TObject);
// убираем массив из окна; файлы на диске не трогаем
begin
  if FDocument.IsEmpty and not FDocument.HasFile then
    Exit;
  if not ConfirmSaveIfModified then
    Exit;
  FDocument.Close;
  DisplayOligoArray;
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
  SetLength(SliceTable,0); // слайс-таблица старого массива больше не нужна
  FDocument.NewArray(CreateOligoArray(Rows, Cols, Fill, RandomLength, ConstSeq));
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива: файлы матриц слоёв (по умолчанию <папка массива>\layers),
// статистика Slices.txt рядом с файлом массива и слайс-таблица
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  i: integer;
  Path, ErrorText: String;
begin
  if FDocument.IsEmpty then
  begin
    ShowMessage('Массив пуст.');
    Exit;
  end;
  // слои пишутся рядом с файлом массива и должны совпадать с ним,
  // поэтому без сохранения нарезать нельзя: только "Сохранить" или "Отмена"
  if not FDocument.HasFile or FDocument.Modified then
  begin
    if MessageDlg('Массив не сохранён. Сохранить его?'+LineEnding+
                  'Слои записываются рядом с файлом массива.',
                  mtConfirmation, [mbYes, mbCancel], 0)<>mrYes then
      Exit;
    if not SaveArray then
      Exit;
  end;

  Path:=IncludeTrailingPathDelimiter(FDocument.ArrayDir)+LAYERS_FOLDER;
  if not ChooseLayerFolder('Слайсинг', 'Папка для файлов слоёв:',
       'файлы слоёв', @ListLayerFiles, @DeleteLayerFiles, Path) then
    Exit;

  // показываем уникальные буквы массива
  ShowMessage(SymbolsToString(CollectSymbols(FDocument.Arr)));

  // прежние слои этого массива больше не действительны
  FDocument.ForgetSlicing;
  if not SliceArrayIntoFolder(FDocument.Arr, Path, FDocument.ArrayDir, Layers,
       Table, ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  FDocument.SetSlicing(Table, FDocument.ArrayDir);
  SliceTable:=Copy(Table); // общая таблица слоёв (её использует синтез)

  LayerChartForm.LS_CharsInLayers.Clear;
  for i:=0 to High(Layers) do
    LayerChartForm.LS_CharsInLayers.AddXY(Layers[i].Number, Layers[i].Count,
                                          Layers[i].Letter);
  LayerChartForm.ShowModal;
end;

procedure TSequencesForm.B_LaserParamsClick(Sender: TObject);
// настройки лазерного маркера - то же окно, что на вкладке ручного управления
begin
  if Assigned(FOnShowLaserSettings) then
    FOnShowLaserSettings(Self);
end;

procedure TSequencesForm.B_GeometryParamsClick(Sender: TObject);
// геометрия, с которой создаются EZD слоёв; хранится в configs\sequences.ini
var
  Geometry: TMarkGeometry;
  ErrorText: String;
begin
  Geometry:=LoadMarkGeometry(SequencesConfigPath);
  if not TMarkGeometryForm.Execute('Параметры геометрии', Geometry) then
    Exit;
  if not ForceDirectories(ConfigsDir) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+ConfigsDir);
    Exit;
  end;
  if not SaveMarkGeometry(SequencesConfigPath, Geometry, ErrorText) then
    ShowMessage(ErrorText);
end;

procedure TSequencesForm.B_CreateLayerEzdClick(Sender: TObject);
// EZD-файл для каждого слоя (по умолчанию в папке ezd рядом с массивом, имя
// как у файла матрицы слоя) и таблица Slices.lays для синтеза рядом с массивом.
var
  Path, ErrorText: String;
  Geometry: TMarkGeometry;
  Writer: TMarkEzdWriter;
  Table: TSliceLayers;
  Done: Boolean;
begin
  if not FDocument.HasSlicing then
  begin
    ShowMessage('Сначала выполните слайсинг массива.');
    Exit;
  end;
  // геометрия вкладки (кнопка «Параметры геометрии»)
  Geometry:=LoadMarkGeometry(SequencesConfigPath);

  Path:=IncludeTrailingPathDelimiter(FDocument.SliceDir)+EZD_FOLDER;
  if not ChooseLayerFolder('EZD-файлы слоёв', 'Папка для EZD-файлов слоёв:',
       'EZD-файлы слоёв', @ListLayerEzdFiles, @DeleteLayerEzdFiles, Path) then
    Exit;

  // Сообщение MarkEzd.dll при подключении (например, что плата маркера
  // не найдена) не закрываем: пользователь должен его увидеть.
  Writer:=TMarkEzdWriter.Create(AppDir, Application.MainFormHandle, @Log);
  try
    Done:=CreateSliceEzdFiles(Writer, FDocument.SliceTable, Path,
      FDocument.SliceDir, Geometry, Table, ErrorText);
  finally
    Writer.Free;
  end;
  if not Done then
  begin
    Log(ErrorText);
    ShowMessage(ErrorText);
    Exit;
  end;
  FDocument.SetSlicing(Table, FDocument.SliceDir);
  SliceTable:=Copy(Table); // синтез можно запускать сразу
end;

end.
