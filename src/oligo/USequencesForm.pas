unit USequencesForm;
// Вкладка «Последовательности»: массив олигов, слайсинг, EZD-файлы слоёв.
// Форма встраивается во вкладку главного окна. Всё, что ей нужно от
// главного окна (журнал, геометрия маркировки, настройки лазера), она
// получает через события.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, IniFiles, MarkGeometry, OligoArrayDocument;

type
  TSequencesLogEvent = procedure(const AMsg: string) of object;
  TGetMarkGeometryEvent = function: TMarkGeometry of object;

  { TSequencesForm }

  TSequencesForm = class(TForm)
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
    SDD_Dir: TSelectDirectoryDialog;
    SG_OligoArr: TStringGrid;
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
    FOnLog: TSequencesLogEvent;
    FOnGetMarkGeometry: TGetMarkGeometryEvent;
    FOnShowLaserSettings: TNotifyEvent;
    FOnBeforeDllInit: TNotifyEvent;
    procedure Log(const AMsg: string);
    procedure LogDll(const AFunName: string; ARez: Integer);
    procedure DisplayOligoArray;
    procedure StoreCell(ACol, ARow: Integer);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Надписи кнопок из файла интерфейса (раздел [Oligo]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
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
  OligoSlices, OligoPaste, UOligoArrayForm, UArraySaveForm, ULayerChartForm;

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
  B_CreateOligoArr.Caption:=AIni.ReadString('Oligo','B_CreateOligoArr','OligoArray');
  B_LoadOligs.Caption:=AIni.ReadString('Oligo','B_LoadOligs','Load Oligs');
  B_SaveOligs.Caption:=AIni.ReadString('Oligo','B_SaveOligs','Save Oligs');
  B_SliceOligoArr.Caption:=AIni.ReadString('Oligo','B_SliceOligoArr','Slice');
  B_SetLasPen2.Caption:=AIni.ReadString('Oligo','B_SetLasPen2','SetLasPen');
  B_SetGeomParam.Caption:=AIni.ReadString('Oligo','B_SetGeomParam','SetGeomParam');
  B_CreateArrEzd.Caption:=AIni.ReadString('Oligo','B_CreateArrEzd','EZD Files');
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

procedure TSequencesForm.DisplayOligoArray;
// массив олигов в таблицу: строка 0 и столбец 0 - заголовки
var
  i,j: Integer;
begin
  SG_OligoArr.Clear;
  SG_OligoArr.RowCount:=Length(FDocument.Arr)+1;
  if not FDocument.IsEmpty then
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

procedure TSequencesForm.B_SaveOligsClick(Sender: TObject);
{Сохранение массива: по умолчанию в новую папку data\arrays\<дата>,
 но можно выбрать любую папку}
var
  Folder, FileName, FilePath, ErrorText: String;
begin
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

  if not FDocument.SaveToFile(FilePath, ErrorText) then
    ShowMessage('Не удалось сохранить массив:'+LineEnding+FilePath+LineEnding+
                ErrorText);
end;

procedure TSequencesForm.B_CreateOligoArrClick(Sender: TObject);
// окно параметров нового массива: пустой, случайный или одна последовательность
var
  Rows, Cols, RandomLength: Integer;
  Fill: TOligoFill;
  ConstSeq: String;
begin
  if not OligoArrayForm.Execute(Rows, Cols, Fill, RandomLength, ConstSeq) then
    Exit;
  SetLength(SliceTable,0); // слайс-таблица старого массива больше не нужна
  FDocument.NewArray(CreateOligoArray(Rows, Cols, Fill, RandomLength, ConstSeq));
  DisplayOligoArray;
end;

procedure TSequencesForm.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива: файлы матриц слоёв, статистика и слайс-таблица
var
  Layers: TOligoLayers;
  i: integer;
  Path, LayerFile: String;
begin
  if FDocument.IsEmpty then
  begin
    ShowMessage('пустой массив!');
    Exit;
  end;

  // Слои удобно складывать в отдельную подпапку data\slices на каждый запуск
  SDD_Dir.InitialDir:=SlicesDir;
  if not SDD_Dir.Execute then
    Exit; // без выбранной папки файлы слоёв записались бы в корень диска
  Path:=SDD_Dir.FileName;

  // показываем уникальные символы
  ShowMessage(SymbolsToString(CollectSymbols(FDocument.Arr)));

  Layers:=SliceOligoArray(FDocument.Arr);
  SetLength(SliceTable, Length(Layers));
  LayerChartForm.LS_CharsInLayers.Clear;
  for i:=0 to High(Layers) do
  begin
    LayerFile:=IncludeTrailingPathDelimiter(Path)+LayerFileName(Layers[i]);
    SaveMatrixAsFile(Layers[i].Matrix, LayerFile);
    SliceTable[i]:=Default(TSliceStruc);
    SliceTable[i].LayerCount:=Layers[i].Number;
    SliceTable[i].Letter:=Layers[i].Letter;
    SliceTable[i].NumOfChar:=Layers[i].Count;
    SliceTable[i].MatrixFile:=LayerFile;
    LayerChartForm.LS_CharsInLayers.AddXY(Layers[i].Number, Layers[i].Count,
                                          Layers[i].Letter);
  end;
  SaveSliceStatistics(Path, SliceTable);
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
// EZD-файл для каждого слоя: рядом с файлом матрицы слоя, с тем же именем
var
  i, rez: integer;
  EzdFile: String;
  Geometry: TMarkGeometry;
  LayerMatrix: TMatrix;
  Spots: TArrOfTPoint;
  Bias: TPoint;
  Unread: TStringList;
begin
  if Length(SliceTable)=0 then
    Exit;
  if not Assigned(FOnGetMarkGeometry) then
    Exit;
  // шаг, группы и смещение пока берутся с вкладки ручного управления
  Geometry:=FOnGetMarkGeometry();

  if Assigned(FOnBeforeDllInit) then
    FOnBeforeDllInit(Self);
  Unread:=TStringList.Create;
  try
    rez:=lmc1_Initial2(WideString(AppDir), true, Application.MainFormHandle);
    LogDll('lmc1_Initial2',rez); // подключаемся к MarkEzd.dll

    for i:=0 to High(SliceTable) do
    begin
      EzdFile:=RemoveFileExt(SliceTable[i].MatrixFile)+'.ezd';
      SliceTable[i].EZDFile:=EzdFile;
      LayerMatrix:=nil;
      if not ReadMatrixFromFile(SliceTable[i].MatrixFile, LayerMatrix) then
      begin
        Log('Не удалось прочитать матрицу слоя: '+SliceTable[i].MatrixFile);
        Unread.Add(ExtractFileName(SliceTable[i].MatrixFile));
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
        'Layer'+IntToStr(SliceTable[i].LayerCount), 1);
      LogDll('lmc1_AddPointToLib',rez);
      rez:=lmc1_SaveEntLibToFile(WideString(EzdFile));
      LogDll('lmc1_SaveEntLibToFile',rez);
    end;
    SaveSliceStatistics(ExtractFileDir(SliceTable[0].MatrixFile), SliceTable, 1);
  finally
    rez:=lmc1_Close;
    LogDll('lmc1_Close', rez);
    if Unread.Count>0 then
      ShowMessage('Не удалось прочитать матрицы слоёв ('+IntToStr(Unread.Count)+
        ' из '+IntToStr(Length(SliceTable))+'), EZD-файлы для них не созданы:'+
        LineEnding+Unread.Text);
    Unread.Free;
  end;
end;

end.
