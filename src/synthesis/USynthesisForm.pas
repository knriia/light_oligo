unit USynthesisForm;
// Вкладка «Синтез»: загрузка слоёв и протоколов, запуск и остановка синтеза.
// Что загружено - в синтезе (SynthesisWorkspace: сессия и папка на диске, куда
// слои и протоколы копируются кнопкой «Сохранить»), ход синтеза - в потоке
// (SynthesisThread и SynthesisRunner). Вкладка ничего не знает о главном окне:
// журнал, шприцевую станцию и запуск наблюдателя за окнами EzCAD ей передаёт
// владелец.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, IniFiles,
  OligoSlices, SynthesisSession, SynthesisWorkspace, SynthesisThread,
  SynthesisFolder,
  UDispenserStationHost;

type
  TSynthesisLogEvent = procedure(const AMsg: string) of object;

  { TSynthesisForm }

  TSynthesisForm = class(TForm)
    B_NewSynthesis: TButton;
    B_OpenSynthesis: TButton;
    B_SaveSynthesis: TButton;
    B_LoadLayers: TButton;
    B_LoadProtToSynth: TButton;
    B_Pause: TButton;
    B_Start: TButton;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    OD_File: TOpenDialog;
    TV_Synthesis: TTreeView;
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_NewSynthesisClick(Sender: TObject);
    procedure B_OpenSynthesisClick(Sender: TObject);
    procedure B_SaveSynthesisClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
  private
    FWorkspace: TSynthesisWorkspace;      // слои и протоколы синтеза и его папка
    FThread: TSynthesisThread;            // nil, пока синтез не идёт
    FHost: TSynthesisHost;                // связь потока с окнами
    FStation: TDispenserStationForm;
    FOnLog: TSynthesisLogEvent;
    FOnEzCadOpening: TNotifyEvent;
    FOnClearLog: TNotifyEvent;
    FEzCadOpenDelayMs: Integer;
    function Running: Boolean;
    procedure ThreadFinished(Sender: TObject);
    procedure RebuildTree;
    function SaveSynthesis: Boolean;
    function AskSaveIfNeeded: Boolean;
    procedure Log(const AText: string);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Слои нового массива (после слайсинга) или пустая таблица (массив сброшен).
    procedure SetLayers(const ALayers: TSliceLayers);
    // Перед закрытием программы: идущий синтез останавливаем только с согласия.
    function CanCloseFromHost: Boolean;
    property Station: TDispenserStationForm read FStation write FStation;
    property OnLog: TSynthesisLogEvent read FOnLog write FOnLog;
    // Перед запуском синтеза владелец очищает журнал.
    property OnClearLog: TNotifyEvent read FOnClearLog write FOnClearLog;
    // Синтез запускает EzCAD: владелец включает наблюдатель за его окнами.
    property OnEzCadOpening: TNotifyEvent read FOnEzCadOpening
      write FOnEzCadOpening;
    // Сколько ждать после запуска EzCAD перед маркировкой, мс.
    property EzCadOpenDelayMs: Integer read FEzCadOpenDelayMs
      write FEzCadOpenDelayMs;
  end;

implementation

{$R *.lfm}

uses
  AppPaths;

type
  // Передаёт потоку журнал, станцию и запуск наблюдателя из окна синтеза.
  TFormHost = class(TSynthesisHost)
  private
    FForm: TSynthesisForm;
  public
    constructor Create(AForm: TSynthesisForm);
    procedure WriteLog(const AText: string); override;
    function Station: TDispenserStationForm; override;
    procedure EzCadOpening; override;
    function EzCadOpenDelayMs: Integer; override;
  end;

constructor TFormHost.Create(AForm: TSynthesisForm);
begin
  inherited Create;
  FForm := AForm;
end;

procedure TFormHost.WriteLog(const AText: string);
begin
  FForm.Log(AText);
end;

function TFormHost.Station: TDispenserStationForm;
begin
  Result := FForm.FStation;
end;

procedure TFormHost.EzCadOpening;
begin
  if Assigned(FForm.FOnEzCadOpening) then
    FForm.FOnEzCadOpening(FForm);
end;

function TFormHost.EzCadOpenDelayMs: Integer;
begin
  Result := FForm.FEzCadOpenDelayMs;
end;

{ TSynthesisForm }

constructor TSynthesisForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FWorkspace := TSynthesisWorkspace.Create;
  FHost := TFormHost.Create(Self);
  FEzCadOpenDelayMs := 1000;
end;

destructor TSynthesisForm.Destroy;
begin
  // идущий синтез останавливаем; сессию он ещё читает, поэтому не освобождаем
  if FThread <> nil then
    FThread.Terminate
  else
    FreeAndNil(FWorkspace);
  inherited Destroy;
end;

procedure TSynthesisForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_SynthControl.Caption := AIni.ReadString('Synthesis', 'GB_SynthControl', 'Synthesis Control');
  GB_Files.Caption := AIni.ReadString('Synthesis', 'GB_Files', 'Synthesis Tree');
  B_LoadProtToSynth.Caption := AIni.ReadString('Synthesis', 'B_LoadProtToSynth', 'Load Protocol');
  B_LoadLayers.Caption := AIni.ReadString('Synthesis', 'B_LoadLayers', 'Load Layers');
  B_NewSynthesis.Caption := AIni.ReadString('Synthesis', 'B_NewSynthesis', 'New Synthesis');
  B_OpenSynthesis.Caption := AIni.ReadString('Synthesis', 'B_OpenSynthesis', 'Open');
  B_SaveSynthesis.Caption := AIni.ReadString('Synthesis', 'B_SaveSynthesis', 'Save');
  B_Start.Caption := AIni.ReadString('Synthesis', 'B_Start', 'Start');
  B_Pause.Caption := AIni.ReadString('Synthesis', 'B_Pause', 'Pause');
end;

function TSynthesisForm.Running: Boolean;
begin
  Result := FThread <> nil;
end;

procedure TSynthesisForm.Log(const AText: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AText);
end;

procedure TSynthesisForm.ThreadFinished(Sender: TObject);
// Поток закончил работу (сам освободится): синтез можно запускать снова
begin
  FThread := nil;
end;

procedure TSynthesisForm.SetLayers(const ALayers: TSliceLayers);
begin
  if Running then
  begin
    Log('WARNING: слои массива изменились во время синтеза, в синтез они ' +
      'не добавлены');
    Exit;
  end;
  FWorkspace.ReplaceLayers(ALayers);
  RebuildTree;
end;

function TSynthesisForm.CanCloseFromHost: Boolean;
begin
  Result := True;
  if Running then
    Result := MessageDlg('Синтез идёт. Остановить его и закрыть программу?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  if Result and Running then
    FThread.Terminate;
  if Result and not Running then
    Result := AskSaveIfNeeded;
end;

procedure TSynthesisForm.RebuildTree;
// Дерево синтеза: папка, протоколы и слои так, как они сейчас в синтезе
var
  Root, Node: TTreeNode;
  Lines: TStringList;
  I, J: Integer;
  Session: TSynthesisSession;
  Letter: string;
begin
  Session := FWorkspace.Session;
  Lines := TStringList.Create;
  TV_Synthesis.Items.BeginUpdate;
  try
    TV_Synthesis.Items.Clear;
    if (Session.ProtocolCount = 0) and (Session.LayerCount = 0) then
      Exit;
    if FWorkspace.Folder = '' then
      Root := TV_Synthesis.Items.Add(nil, 'Синтез не сохранён')
    else
      Root := TV_Synthesis.Items.Add(nil, 'Синтез: ' + FWorkspace.Folder);
    for I := 0 to Session.ProtocolCount - 1 do
    begin
      Letter := Session.ProtocolLetters[I];
      Node := TV_Synthesis.Items.AddChild(Root, Letter + '.pro');
      Lines.Text := Session.ProtocolOf(Letter).ToText;
      for J := 0 to Lines.Count - 1 do
        if Trim(Lines[J]) <> '' then
          TV_Synthesis.Items.AddChild(Node, Lines[J]);
      Node.Expand(True);
    end;
    if Session.LayerCount > 0 then
    begin
      Node := TV_Synthesis.Items.AddChild(Root, 'Слои: ' +
        IntToStr(Session.LayerCount));
      for I := 0 to Session.LayerCount - 1 do
        TV_Synthesis.Items.AddChild(Node, IntToStr(Session.Layers[I].LayerNumber) +
          ' ' + Session.Layers[I].Letter + ' ' + Session.Layers[I].EZDFile);
    end;
    Root.Expand(False);
  finally
    TV_Synthesis.Items.EndUpdate;
    Lines.Free;
  end;
end;

function TSynthesisForm.AskSaveIfNeeded: Boolean;
// True - можно продолжать (сохранили или отказались сохранять); False - отмена
begin
  Result := True;
  if not FWorkspace.NeedsSave then
    Exit;
  case QuestionDlg('Синтез не сохранён', 'Сохранить синтез?', mtConfirmation,
    [mrYes, AnsiString('Сохранить'), mrNo, AnsiString('Нет'),
     mrCancel, AnsiString('Отмена')], 0) of
    mrYes: Result := SaveSynthesis;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TSynthesisForm.B_NewSynthesisClick(Sender: TObject);
// Новый пустой синтез; сохранённые файлы остаются в своих папках
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы создать новый.');
    Exit;
  end;
  if not AskSaveIfNeeded then
    Exit;
  FWorkspace.NewSynthesis;
  RebuildTree;
end;

procedure TSynthesisForm.B_OpenSynthesisClick(Sender: TObject);
// Открыть сохранённый синтез по его файлу synthesis.ini
var
  ErrorText: string;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы открыть другой.');
    Exit;
  end;
  if not AskSaveIfNeeded then
    Exit;
  OD_File.Filter := 'Файл синтеза|' + SYNTHESIS_INFO_FILE;
  OD_File.InitialDir := SynthesesDir;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  if FWorkspace.Open(OD_File.FileName, ErrorText) then
    Log('Синтез открыт: ' + FWorkspace.Folder)
  else
    ShowMessage(ErrorText);
  RebuildTree;
end;

function TSynthesisForm.SaveSynthesis: Boolean;
// Сохранить синтез: слои и протоколы копируются в папку синтеза.
// True - сохранён; False - не сохранён (отмена, ошибка, идёт синтез).
var
  Dialog: TSaveDialog;
  Target, ErrorText, ArrayName: string;
begin
  Result := False;
  if Running then
  begin
    ShowMessage('Синтез идёт. Сохранять можно после остановки.');
    Exit;
  end;
  if FWorkspace.Folder <> '' then
    Target := FWorkspace.Folder
  else
    Target := '';
  // сохранённый и не запускавшийся синтез сохраняется на месте, иначе
  // спрашиваем, где создать папку
  if (Target = '') or FWorkspace.Started then
  begin
    ForceDirectories(SynthesesDir);
    ArrayName := '';
    if FWorkspace.Session.LayerCount > 0 then
      ArrayName := ArrayNameOfLayers(FWorkspace.Session.Layers);
    Dialog := TSaveDialog.Create(nil);
    try
      Dialog.Title := 'Сохранить синтез: имя папки синтеза';
      Dialog.InitialDir := SynthesesDir;
      Dialog.FileName := SynthesisFolderName(ArrayName, Now);
      if not Dialog.Execute then
        Exit;
      Target := Dialog.FileName;
    finally
      Dialog.Free;
    end;
  end;
  Result := FWorkspace.Save(Target, Now, ErrorText);
  if Result then
    Log('Синтез сохранён: ' + FWorkspace.Folder)
  else
    ShowMessage(ErrorText);
  RebuildTree;
end;

procedure TSynthesisForm.B_SaveSynthesisClick(Sender: TObject);
begin
  SaveSynthesis;
end;

procedure TSynthesisForm.B_LoadProtToSynthClick(Sender: TObject);
// Добавить протокол в синтез
var
  Letter, ErrorText: string;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять протоколы.');
    Exit;
  end;
  OD_File.Filter := 'Протокол|*.pro';
  OD_File.InitialDir := ProtocolsDir;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  if FWorkspace.AddProtocolFile(OD_File.FileName, Letter, ErrorText) then
  begin
    Log('Протокол для буквы ' + Letter + ' загружен: ' + OD_File.FileName);
    RebuildTree;
  end
  else
    ShowMessage(ErrorText);
end;

procedure TSynthesisForm.B_LoadLayersClick(Sender: TObject);
// Добавить слои в синтез: файл Slices.lays лежит в папке массива
var
  ErrorText: string;
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы менять слои.');
    Exit;
  end;
  if FWorkspace.Session.LayerCount > 0 then
  begin
    ShowMessage('Слои уже загружены. Чтобы загрузить другие, нажмите ' +
      '«Создать синтез».');
    Exit;
  end;
  OD_File.Filter := 'Слои|*.lays';
  OD_File.InitialDir := ArraysDir;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  if FWorkspace.AddLayersFile(OD_File.FileName, ErrorText) then
    RebuildTree
  else
    ShowMessage(ErrorText);
end;

procedure TSynthesisForm.B_StartClick(Sender: TObject);
// Запуск синтеза: только сохранённого и неизменённого
var
  I: Integer;
  ErrorText: string;
  Snapshot: TSynthesisSnapshot;
  Session: TSynthesisSession;
begin
  if Running then
  begin
    ShowMessage('Синтез уже идёт.');
    Exit;
  end;
  if Assigned(FOnClearLog) then
    FOnClearLog(Self);

  // проверка, что синтез сохранён, есть слои и протоколы на все буквы
  if not FWorkspace.PrepareStart(Now, Snapshot, ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  Session := FWorkspace.Session;
  for I := 0 to Session.ProtocolCount - 1 do
    Log(Session.ProtocolLetters[I]);
  Log('Число слоев=' + IntToStr(Session.LayerCount));
  Log('Первыйслой=' + IntToStr(Session.Layers[0].LayerNumber) + ' ' +
    Session.Layers[0].EZDFile);
  Log('Последний слой=' +
    IntToStr(Session.Layers[Session.LayerCount - 1].LayerNumber) + ' ' +
    Session.Layers[Session.LayerCount - 1].EZDFile);
  Log('Папка синтеза: ' + Snapshot.Folder);

  FThread := TSynthesisThread.Create(Session, FHost, Snapshot);
  FThread.OnTerminate := @ThreadFinished;
  FThread.Start;
end;

procedure TSynthesisForm.B_PauseClick(Sender: TObject);
begin
  if FThread <> nil then
    FThread.Terminate;
  Log('Synthesis aborted');
end;

end.
