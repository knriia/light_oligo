unit USequencesForm;
// Вкладка «Последовательности»: массив олигов, слайсинг. Форма встраивается во
// вкладку главного окна, журнал получает от него через событие. Слои синтеза
// она не отдаёт: синтез сам берёт слайс из папки проекта.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids, IniFiles, OligoArray, OligoArrayDocument, OligoSlices, GridWidthMode;

type
  TSequencesLogEvent = procedure(const AMsg: string) of object;

  { TSequencesForm }

  TSequencesForm = class(TForm)
    B_CreateOligoArr: TButton;
    B_LoadOligoArr: TButton;
    B_SaveOligoArr: TButton;
    B_SliceOligoArr: TButton;
    GB_OligControl: TGroupBox;
    OD_File: TOpenDialog;
    P_OligoArr: TPanel;
    SG_OligoArr: TStringGrid;
    procedure B_CreateOligoArrClick(Sender: TObject);
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
    FTargetDir: string;  // проект, в который SaveArray пишет новый массив без диалога
    FWidthMode: TGridWidthMode;
    FOnLog: TSequencesLogEvent;
    procedure Log(const AMsg: string);
    procedure DisplayOligoArray;
    procedure ApplyWidthMode;
    procedure StoreCell(ACol, ARow: Integer);
    function SaveArray: Boolean;
    function DoCreateArray: Boolean;
    function LoadFile(const AFileName: string): Boolean;
    function ConfirmSaveIfModified: Boolean;
    function RequireArray: Boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    // Надписи кнопок из файла интерфейса (раздел [Oligo]).
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Перед закрытием программы: несохранённый массив предлагаем сохранить.
    // False - пользователь отменил закрытие.
    function CanCloseFromHost: Boolean;
    property OnLog: TSequencesLogEvent read FOnLog write FOnLog;
    // Папка открытого проекта (там лежит файл массива); пусто - массив ещё
    // не сохранён в проект.
    function ProjectDir: string;
    // Те же действия, что у кнопок вкладки; вызываются из главного меню.
    procedure CreateArray;
    // Создаёт новый массив и сразу сохраняет его в папку проекта AProjectDir
    // как <проект>\<проект>.csv, без окна выбора места. False - отмена или
    // ошибка; массив при ошибке сохранения остаётся несохранённым.
    function CreateArrayInProject(const AProjectDir: string): Boolean;
    // Открывает CSV массива: вопрос о несохранённом, замена текущего.
    // False - отмена или ошибка чтения, массив прежний.
    function OpenArrayFile(const AFileName: string): Boolean;
    procedure SaveArrayToProject;
    procedure SliceArray;
    // Есть ли массив.
    function HasArray: Boolean;
  end;

implementation

uses
  LCLType, Clipbrd, AppPaths, CommonUtils, OligoSlicing,
  OligoPaste, UOligoArrayForm, UArraySaveForm, UChoiceForm, ULayerChartForm;

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
  GB_OligControl.Caption:=AIni.ReadString('Oligo','GB_OligControl','Control');
  B_CreateOligoArr.Caption:=AIni.ReadString('Oligo','B_CreateOligoArr','Create');
  B_LoadOligoArr.Caption:=AIni.ReadString('Oligo','B_LoadOligoArr','Load');
  B_SaveOligoArr.Caption:=AIni.ReadString('Oligo','B_SaveOligoArr','Save');
  B_SliceOligoArr.Caption:=AIni.ReadString('Oligo','B_SliceOligoArr','Slicing');
end;

function TSequencesForm.RequireArray: Boolean;
// действия над массивом: пустой массив - сообщение и отказ
begin
  Result:=not FDocument.IsEmpty;
  if not Result then
    ShowMessage('Массив пуст.');
end;

function TSequencesForm.ProjectDir: string;
begin
  Result:=FDocument.ArrayDir;
end;

procedure TSequencesForm.CreateArray;
begin
  B_CreateOligoArrClick(nil);
end;

function TSequencesForm.CreateArrayInProject(const AProjectDir: string): Boolean;
begin
  Result:=DoCreateArray;
  if not Result then
    Exit;
  // место задаём только после создания: вопрос о сохранении прежнего
  // массива не должен писать его в этот проект
  FTargetDir:=ExcludeTrailingPathDelimiter(AProjectDir);
  try
    Result:=SaveArray;
  finally
    FTargetDir:='';
  end;
end;

function TSequencesForm.OpenArrayFile(const AFileName: string): Boolean;
begin
  Result:=ConfirmSaveIfModified and LoadFile(AFileName);
end;

procedure TSequencesForm.SaveArrayToProject;
begin
  SaveArray;
end;

procedure TSequencesForm.SliceArray;
begin
  B_SliceOligoArrClick(nil);
end;

function TSequencesForm.HasArray: Boolean;
begin
  Result:=not FDocument.IsEmpty;
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
begin
  if not ConfirmSaveIfModified then // загруженный массив заменит текущий
    Exit;
  OD_File.Filter:='CSV Files|*.csv';
  OD_File.InitialDir:=ProjectsDir;
  OD_File.FilterIndex:=1;
  if not OD_File.Execute then
    Exit;
  LoadFile(OD_File.FileName);
end;

function TSequencesForm.LoadFile(const AFileName: string): Boolean;
var
  ErrorText: String;
begin
  Result:=FDocument.LoadFromFile(AFileName, ErrorText);
  if not Result then
  begin
    ShowMessage('Не удалось прочитать файл массива:'+LineEnding+
                AFileName+LineEnding+ErrorText);
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
  FilePath:='';
  if (not FDocument.HasFile) and (FTargetDir<>'') then
  begin
    FilePath:=IncludeTrailingPathDelimiter(FTargetDir)+
              ExtractFileName(FTargetDir)+'.csv';
    OtherCsv:=FindOtherProjectCsv(FTargetDir, FilePath);
    if OtherCsv<>'' then
    begin
      ShowMessage('В папке проекта уже есть другой CSV:'+LineEnding+OtherCsv);
      Exit;
    end;
  end;
  FDocument.SuggestProjectLocation(ProjectsDir, Now, Folder, ProjectName);
  if FDocument.HasFile then
    ArrayFile:=ChangeFileExt(ExtractFileName(FDocument.FileName), '')
  else
    ArrayFile:=DEFAULT_ARRAY_FILE;

  // спрашиваем, пока не получим допустимое место и согласие на перезапись
  // (место проекта уже известно - не спрашиваем)
  if FilePath='' then
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
begin
  DoCreateArray;
end;

function TSequencesForm.DoCreateArray: Boolean;
// окно параметров нового массива: пустой, случайный или одна последовательность;
// True - массив создан
var
  Rows, Cols, RandomLength: Integer;
  Fill: TOligoFill;
  ConstSeq: String;
begin
  Result:=False;
  if not ConfirmSaveIfModified then // новый массив заменит текущий
    Exit;
  if not OligoArrayForm.Execute(Rows, Cols, Fill, RandomLength, ConstSeq) then
    Exit;
  FDocument.NewArray(CreateOligoArray(Rows, Cols, Fill, RandomLength, ConstSeq));
  DisplayOligoArray;
  Result:=True;
end;

procedure TSequencesForm.B_SliceOligoArrClick(Sender: TObject);
// нарезка массива выбранным алгоритмом в папку проекта slice_<алгоритм>:
// Slices.txt и папка layers с матрицами слоёв
var
  Layers: TOligoLayers;
  Table: TSliceLayers;
  Algorithms: TStringList;
  Existing: TStringArray;
  i, AlgorithmIndex: integer;
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

  // алгоритм слайсинга; пока он один, его имя - постфикс папки слайса
  Algorithms:=TStringList.Create;
  try
    Algorithms.Add(SLICE_ALGORITHM_BASE);
    AlgorithmIndex:=0;
    if not ChooseFromList('Слайсинг', 'Алгоритм слайсинга:', Algorithms,
         AlgorithmIndex) then
      Exit;
    Path:=IncludeTrailingPathDelimiter(FDocument.ArrayDir)+
          SliceFolderName(Algorithms[AlgorithmIndex]);
  finally
    Algorithms.Free;
  end;

  // слайс одного алгоритма один: прежний заменяется с согласия оператора
  Existing:=ListSliceFiles(Path);
  if Length(Existing)>0 then
  begin
    if MessageDlg('В папке уже есть файлы слайсинга ('+
         IntToStr(Length(Existing))+'):'+LineEnding+Path+LineEnding+
         'Удалить их и записать новые?', mtConfirmation, [mbYes, mbNo],
         0)<>mrYes then
      Exit;
    if not DeleteSliceFiles(Path, ErrorText) then
    begin
      ShowMessage(ErrorText);
      Exit;
    end;
  end;
  if not ForceDirectories(Path) then
  begin
    ShowMessage('Не удалось создать папку:'+LineEnding+Path);
    Exit;
  end;

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

  LayerChartForm.LS_CharsInLayers.Clear;
  for i:=0 to High(Layers) do
    LayerChartForm.LS_CharsInLayers.AddXY(Layers[i].Number, Layers[i].Count,
                                          Layers[i].Letter);
  LayerChartForm.ShowModal;
end;

end.
