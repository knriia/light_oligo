unit USequencesForm;
// Вкладка «Последовательности»: массив олигов, слайсинг, EZD-файлы слоёв.
// Форма встраивается во вкладку главного окна. Всё, что ей нужно от
// главного окна (журнал, геометрия маркировки, настройки лазера), она
// получает через события.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, IniFiles, MarkGeometry, OligoArrayDocument, OligoSlices;

type
  TSequencesLogEvent = procedure(const AMsg: string) of object;
  TGetMarkGeometryEvent = function: TMarkGeometry of object;

  { TSequencesForm }

  TSequencesForm = class(TForm)
    B_ClearOligoArr: TButton;
    B_CloseOligoArr: TButton;
    B_CreateArrEzd: TButton;
    B_CreateOligoArr: TButton;
    B_LoadOligs: TButton;
    B_SaveOligs: TButton;
    B_SetGeomParam: TButton;
    B_SetLasPen2: TButton;
    B_SliceOligoArr: TButton;
    GB_OligControl: TGroupBox;
    OD_File: TOpenDialog;
    Panel4: TPanel;
    SD_File: TSaveDialog;
    SG_OligoArr: TStringGrid;
    procedure B_ClearOligoArrClick(Sender: TObject);
    procedure B_CloseOligoArrClick(Sender: TObject);
    procedure B_CreateArrEzdClick(Sender: TObject);
    procedure B_CreateOligoArrClick(Sender: TObject);
    procedure B_LoadOligsClick(Sender: TObject);
    procedure B_SaveOligsClick(Sender: TObject);
    procedure B_SetGeomParamClick(Sender: TObject);
    procedure B_SetLasPen2Click(Sender: TObject);
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
    // результат последнего слайсинга этого массива и папка массива, рядом с
    // которой лежат Slices.txt и Slices.lays
    FSliceTable: TArrSliceStruc;
    FSliceDir: string;
    FOnLog: TSequencesLogEvent;
    FOnGetMarkGeometry: TGetMarkGeometryEvent;
    FOnShowLaserSettings: TNotifyEvent;
    FOnBeforeDllInit: TNotifyEvent;
    procedure Log(const AMsg: string);
    procedure LogDll(const AFunName: string; ARez: Integer);
    procedure DisplayOligoArray;
    procedure ForgetSlicing;
    procedure StoreCell(ACol, ARow: Integer);
    procedure LayoutButtons;
    function SaveArray: Boolean;
    function ConfirmSaveIfModified: Boolean;
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
    // Шаг, группы и смещение берутся с вкладки ручного управления.
    property OnGetMarkGeometry: TGetMarkGeometryEvent
      read FOnGetMarkGeometry write FOnGetMarkGeometry;
    property OnShowLaserSettings: TNotifyEvent
      read FOnShowLaserSettings write FOnShowLaserSettings;
    // Перед подключением к MarkEzd.dll: главное окно закрывает её сообщение.
    property OnBeforeDllInit: TNotifyEvent
      read FOnBeforeDllInit write FOnBeforeDllInit;
  end;

implementation

uses
  LCLType, Clipbrd, MatrixTypes, AppState, AppPaths, CommonUtils, EzCadApi,
  Lmc1Results, OligoArray, OligoSlicing, OligoMatrix,
  OligoPaste, UOligoArrayForm, UArraySaveForm, UFolderForm, ULayerChartForm;

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
  B_CreateOligoArr.Caption:=AIni.ReadString('Oligo','B_CreateOligoArr','Create OligoArray');
  B_ClearOligoArr.Caption:=AIni.ReadString('Oligo','B_ClearOligoArr','Clear OligoArray');
  B_CloseOligoArr.Caption:=AIni.ReadString('Oligo','B_CloseOligoArr','Remove OligoArray');
  B_LoadOligs.Caption:=AIni.ReadString('Oligo','B_LoadOligs','Load Oligs');
  B_SaveOligs.Caption:=AIni.ReadString('Oligo','B_SaveOligs','Save Oligs');
  B_SliceOligoArr.Caption:=AIni.ReadString('Oligo','B_SliceOligoArr','Slice');
  B_SetLasPen2.Caption:=AIni.ReadString('Oligo','B_SetLasPen2','SetLasPen');
  B_SetGeomParam.Caption:=AIni.ReadString('Oligo','B_SetGeomParam','SetGeomParam');
  B_CreateArrEzd.Caption:=AIni.ReadString('Oligo','B_CreateArrEzd','EZD Files');
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
  Buttons:=[B_CreateOligoArr, B_LoadOligs, B_SaveOligs, B_ClearOligoArr,
            B_CloseOligoArr, B_SliceOligoArr, B_SetLasPen2, B_SetGeomParam,
            B_CreateArrEzd];
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

procedure TSequencesForm.LogDll(const AFunName: string; ARez: Integer);
begin
  Log(Lmc1ResultText(AFunName, ARez));
end;

procedure TSequencesForm.ForgetSlicing;
// слои относились к прежнему массиву
begin
  FSliceTable:=nil;
  FSliceDir:='';
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
end;

procedure TSequencesForm.StoreCell(ACol, ARow: Integer);
// ячейку таблицы в массив; ячейки вне массива не трогаем
begin
  if FDocument.SetCell(ARow-1, ACol-1, SG_OligoArr.Cells[ACol,ARow]) then
    SG_OligoArr.Cells[ACol,ARow]:=FDocument.Cell(ARow-1, ACol-1);
end;

procedure TSequencesForm.SG_OligoArrHeaderClick(Sender: TObject;
  IsColumn: Boolean; Index: Integer);
// Клик по углу таблицы переключает ширину ячеек:
// по умолчанию -> по самому длинному олигу -> квадратные -> по умолчанию
var
  i: integer;
begin
  if not IsColumn or (Index<>0) then
    Exit;
  SG_OligoArr.Cells[0,0]:=SG_OligoArr.Cells[0,0]+' ';
  case Length(SG_OligoArr.Cells[0,0]) of
    1: for i:=1 to SG_OligoArr.ColCount-1 do
         SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultColWidth;
    2: for i:=1 to SG_OligoArr.ColCount-1 do
         AutoSizeGridColumn(SG_OligoArr, i);
    3: begin
         for i:=1 to SG_OligoArr.ColCount-1 do
           SG_OligoArr.ColWidths[i]:=SG_OligoArr.DefaultRowHeight;
         SG_OligoArr.Cells[0,0]:='';
       end;
  else
    SG_OligoArr.Cells[0,0]:='';
  end;
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

procedure TSequencesForm.B_LoadOligsClick(Sender: TObject);
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
  ForgetSlicing;
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SaveOligsClick(Sender: TObject);
begin
  SaveArray;
end;

function TSequencesForm.SaveArray: Boolean;
{Сохранение массива: по умолчанию в новую папку data\arrays\<дата>,
 но можно выбрать любую папку}
var
  Folder, FileName, FilePath, ErrorText: String;
begin
  Result:=False;
  // открытый из файла массив предлагаем сохранить туда же,
  // новый - в папку и файл с датой и временем
  if FDocument.HasFile then
  begin
    Folder:=FDocument.ArrayDir;
    FileName:=ChangeFileExt(ExtractFileName(FDocument.FileName), '');
  end
  else
  begin
    FileName:='array_'+FormatDateTime('yyyy-mm-dd_hhnn', Now);
    Folder:=IncludeTrailingPathDelimiter(ArraysDir)+FileName;
  end;

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

procedure TSequencesForm.B_ClearOligoArrClick(Sender: TObject);
// стираем содержимое ячеек, размер массива остаётся
begin
  if FDocument.IsEmpty then
    Exit;
  if not ConfirmSaveIfModified then
    Exit;
  FDocument.ClearCells;
  ForgetSlicing;
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
  ForgetSlicing;
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
  ForgetSlicing;
  FDocument.NewArray(CreateOligoArray(Rows, Cols, Fill, RandomLength, ConstSeq));
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива: файлы матриц слоёв (по умолчанию <папка массива>\layers),
// статистика Slices.txt рядом с файлом массива и слайс-таблица
var
  Layers: TOligoLayers;
  Existing: TStringArray;
  i: integer;
  Path, LayerFile, ErrorText: String;
begin
  if FDocument.IsEmpty then
  begin
    ShowMessage('пустой массив!');
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

  // папка слоёв; если в ней уже есть слои - только с согласия их удалить
  Path:=IncludeTrailingPathDelimiter(FDocument.ArrayDir)+LAYERS_FOLDER;
  repeat
    if not TFolderForm.Execute('Слайсинг', 'Папка для файлов слоёв:', Path) then
      Exit;
    Existing:=ListLayerFiles(Path);
    if Length(Existing)>0 then
    begin
      if MessageDlg('В папке уже есть файлы слоёв ('+IntToStr(Length(Existing))+
           '):'+LineEnding+Path+LineEnding+
           'Удалить их и записать новые слои?', mtConfirmation,
           [mbYes, mbNo], 0)<>mrYes then
        Continue;
      if not DeleteLayerFiles(Path, ErrorText) then
      begin
        ShowMessage(ErrorText);
        Exit;
      end;
    end;
    Break;
  until false;
  if not ForceDirectories(Path) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+Path);
    Exit;
  end;

  // показываем уникальные символы
  ShowMessage(SymbolsToString(CollectSymbols(FDocument.Arr)));

  Layers:=SliceOligoArray(FDocument.Arr);
  SetLength(FSliceTable, Length(Layers));
  LayerChartForm.LS_CharsInLayers.Clear;
  for i:=0 to High(Layers) do
  begin
    LayerFile:=IncludeTrailingPathDelimiter(Path)+LayerFileName(Layers[i]);
    SaveMatrixAsFile(Layers[i].Matrix, LayerFile);
    FSliceTable[i]:=Default(TSliceStruc);
    FSliceTable[i].LayerCount:=Layers[i].Number;
    FSliceTable[i].Letter:=Layers[i].Letter;
    FSliceTable[i].NumOfChar:=Layers[i].Count;
    FSliceTable[i].MatrixFile:=LayerFile;
    LayerChartForm.LS_CharsInLayers.AddXY(Layers[i].Number, Layers[i].Count,
                                          Layers[i].Letter);
  end;
  // пути к слоям в статистике - относительно папки массива
  FSliceDir:=FDocument.ArrayDir;
  SaveSliceStatistics(FSliceDir, FSliceTable);
  SliceTable:=Copy(FSliceTable); // общая таблица слоёв (её использует синтез)
  LayerChartForm.ShowModal;
end;

procedure TSequencesForm.B_SetLasPen2Click(Sender: TObject);
// настройки лазерного маркера - то же окно, что на вкладке ручного управления
begin
  if Assigned(FOnShowLaserSettings) then
    FOnShowLaserSettings(Self);
end;

procedure TSequencesForm.B_SetGeomParamClick(Sender: TObject);
begin
  {TODO: Переделать на вкладке Manual окно задания массива и вызывать его отсюда}
  ShowMessage('Перейдите на вкладку Ручного управления'+LineEnding+
              'и задайте геометрические параметры массива');
end;

procedure TSequencesForm.B_CreateArrEzdClick(Sender: TObject);
// EZD-файл для каждого слоя (по умолчанию в папке ezd рядом с массивом, имя
// как у файла матрицы слоя) и таблица Slices.lays для синтеза рядом с массивом
var
  i, rez: integer;
  Path, EzdFile, ErrorText: String;
  Existing: TStringArray;
  Geometry: TMarkGeometry;
  LayerMatrix: TMatrix;
  Spots: TArrOfTPoint;
  Bias: TPoint;
  Unread: TStringList;
begin
  if Length(FSliceTable)=0 then
  begin
    ShowMessage('Сначала выполните слайсинг массива.');
    Exit;
  end;
  if not Assigned(FOnGetMarkGeometry) then
    Exit;
  // шаг, группы и смещение пока берутся с вкладки ручного управления
  Geometry:=FOnGetMarkGeometry();

  // папка EZD; если в ней уже есть EZD слоёв - только с согласия их удалить
  Path:=IncludeTrailingPathDelimiter(FSliceDir)+EZD_FOLDER;
  repeat
    if not TFolderForm.Execute('EZD-файлы слоёв', 'Папка для EZD-файлов слоёв:',
         Path) then
      Exit;
    Existing:=ListLayerEzdFiles(Path);
    if Length(Existing)>0 then
    begin
      if MessageDlg('В папке уже есть EZD-файлы слоёв ('+IntToStr(Length(Existing))+
           '):'+LineEnding+Path+LineEnding+
           'Удалить их и создать новые?', mtConfirmation, [mbYes, mbNo], 0)<>mrYes then
        Continue;
      if not DeleteLayerEzdFiles(Path, ErrorText) then
      begin
        ShowMessage(ErrorText);
        Exit;
      end;
    end;
    Break;
  until false;
  if not ForceDirectories(Path) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+Path);
    Exit;
  end;

  if Assigned(FOnBeforeDllInit) then
    FOnBeforeDllInit(Self);
  Unread:=TStringList.Create;
  try
    rez:=lmc1_Initial2(WideString(AppDir), true, Application.MainFormHandle);
    LogDll('lmc1_Initial2',rez); // подключаемся к MarkEzd.dll

    for i:=0 to High(FSliceTable) do
    begin
      EzdFile:=IncludeTrailingPathDelimiter(Path)+
        ChangeFileExt(ExtractFileName(FSliceTable[i].MatrixFile), '.ezd');
      FSliceTable[i].EZDFile:=EzdFile;
      LayerMatrix:=nil;
      if not ReadMatrixFromFile(FSliceTable[i].MatrixFile, LayerMatrix) then
      begin
        Log('Не удалось прочитать матрицу слоя: '+FSliceTable[i].MatrixFile);
        Unread.Add(ExtractFileName(FSliceTable[i].MatrixFile));
        Continue;
      end;

      rez:=lmc1_LoadEzdFile(WideString(EzdFile));
      LogDll('lmc1_LoadEzdFile',rez);
      rez:=lmc1_ClearEntLib();
      LogDll('lmc1_ClearEntLib',rez);

      Bias:=MarkBias(LayerMatrix, Geometry);
      Spots:=nil;
      rez:=ConvertMatrixToLinearArray(LayerMatrix, Spots, Geometry.Step,
        Geometry.Group, Geometry.GroupStep, Bias[0], Bias[1]);
      LogDll('ConvertMatrixToLineArray: '+RemoveFileExt(EzdFile)+' ', rez);

      if Length(Spots)=0 then
      begin
        LogDll('Пустой массив! Файл не перезаписан!',-1);
        Continue;
      end;

      rez:=lmc1_AddPointToLib(@Spots[0], Length(Spots),
        'Layer'+IntToStr(FSliceTable[i].LayerCount), 1);
      LogDll('lmc1_AddPointToLib',rez);
      rez:=lmc1_SaveEntLibToFile(WideString(EzdFile));
      LogDll('lmc1_SaveEntLibToFile',rez);
    end;
    // пути к EZD в Slices.lays - относительно папки массива
    SaveSliceStatistics(FSliceDir, FSliceTable, 1);
    SliceTable:=Copy(FSliceTable); // синтез можно запускать сразу
  finally
    rez:=lmc1_Close;
    LogDll('lmc1_Close', rez);
    if Unread.Count>0 then
      ShowMessage('Не удалось прочитать матрицы слоёв ('+IntToStr(Unread.Count)+
        ' из '+IntToStr(Length(FSliceTable))+'), EZD-файлы для них не созданы:'+
        LineEnding+Unread.Text);
    Unread.Free;
  end;
end;

end.
