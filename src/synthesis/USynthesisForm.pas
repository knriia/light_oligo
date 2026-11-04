unit USynthesisForm;
// Вкладка «Синтез»: загрузка слоёв и протоколов, запуск и остановка синтеза.
// Что загружено - в сессии (SynthesisSession), ход синтеза - в потоке
// (SynthesisThread и SynthesisRunner). Вкладка ничего не знает о главном окне:
// журнал, шприцевую станцию и запуск наблюдателя за окнами EzCAD ей передаёт
// владелец.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, IniFiles,
  OligoSlices, SynthesisSession, SynthesisThread, SynthesisFolder,
  UDispenserStationHost;

type
  TSynthesisLogEvent = procedure(const AMsg: string) of object;

  { TSynthesisForm }

  TSynthesisForm = class(TForm)
    B_ClearAll: TButton;
    B_LoadLayers: TButton;
    B_LoadProtToSynth: TButton;
    B_Pause: TButton;
    B_Start: TButton;
    GB_Files: TGroupBox;
    GB_SynthControl: TGroupBox;
    OD_File: TOpenDialog;
    TV_Synthesis: TTreeView;
    procedure B_ClearAllClick(Sender: TObject);
    procedure B_LoadLayersClick(Sender: TObject);
    procedure B_LoadProtToSynthClick(Sender: TObject);
    procedure B_PauseClick(Sender: TObject);
    procedure B_StartClick(Sender: TObject);
  private
    FSession: TSynthesisSession;          // слои и протоколы для синтеза
    FThread: TSynthesisThread;            // nil, пока синтез не идёт
    FHost: TSynthesisHost;                // связь потока с окнами
    FStation: TDispenserStationForm;
    FOnLog: TSynthesisLogEvent;
    FOnEzCadOpening: TNotifyEvent;
    FOnClearLog: TNotifyEvent;
    FEzCadOpenDelayMs: Integer;
    function Running: Boolean;
    procedure ThreadFinished(Sender: TObject);
    procedure ShowFileInTree(const AFileName: string);
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
  FSession := TSynthesisSession.Create;
  FHost := TFormHost.Create(Self);
  FEzCadOpenDelayMs := 1000;
end;

destructor TSynthesisForm.Destroy;
begin
  // идущий синтез останавливаем; сессию он ещё читает, поэтому не освобождаем
  if FThread <> nil then
    FThread.Terminate
  else
    FreeAndNil(FSession);
  inherited Destroy;
end;

procedure TSynthesisForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  GB_SynthControl.Caption := AIni.ReadString('Synthesis', 'GB_SynthControl', 'Synthesis Control');
  GB_Files.Caption := AIni.ReadString('Synthesis', 'GB_Files', 'Files');
  B_LoadProtToSynth.Caption := AIni.ReadString('Synthesis', 'B_LoadProtToSynth', 'Load Protocol');
  B_LoadLayers.Caption := AIni.ReadString('Synthesis', 'B_LoadLayers', 'Load Layers');
  B_ClearAll.Caption := AIni.ReadString('Synthesis', 'B_ClearAll', 'Clear All');
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
  FSession.SetLayers(ALayers);
end;

function TSynthesisForm.CanCloseFromHost: Boolean;
begin
  Result := True;
  if Running then
    Result := MessageDlg('Синтез идёт. Остановить его и закрыть программу?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  if Result and Running then
    FThread.Terminate;
end;

procedure TSynthesisForm.ShowFileInTree(const AFileName: string);
// Содержимое файла - узлом дерева: имя файла, под ним его строки
var
  FileLines: TStringList;
  NewNode: TTreeNode;
  I: Integer;
begin
  if not FileExists(AFileName) then
  begin
    ShowMessage('Файл не найден: ' + AFileName);
    Exit;
  end;
  FileLines := TStringList.Create;
  try
    FileLines.LoadFromFile(AFileName);
    NewNode := TV_Synthesis.Items.Add(nil, ExtractFileName(AFileName));
    for I := 0 to FileLines.Count - 1 do
      TV_Synthesis.Items.AddChild(NewNode, FileLines[I]);
    NewNode.Expand(True);
  finally
    FileLines.Free;
  end;
end;

procedure TSynthesisForm.B_LoadProtToSynthClick(Sender: TObject);
// Загрузить файлы протоколов
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
  if FSession.AddProtocolFile(OD_File.FileName, Letter, ErrorText) then
  begin
    Log('Протокол для буквы ' + Letter + ' загружен: ' + OD_File.FileName);
    ShowFileInTree(OD_File.FileName);
  end
  else
    ShowMessage(ErrorText);
end;

procedure TSynthesisForm.B_LoadLayersClick(Sender: TObject);
// Загрузить файлы слоев
var
  ErrorText: string;
  Node: TTreeNode;
begin
  Node := TV_Synthesis.Items.GetFirstNode;
  while Node <> nil do
  begin
    // Проверяем, содержит ли узел искомый текст
    if Pos('.lays', Node.Text) > 0 then
    begin
      ShowMessage('Файл слоев уже загружен!');
      Exit;
    end;
    Node := Node.GetNext;
  end;

  OD_File.Filter := 'Слои|*.lays';
  OD_File.InitialDir := SlicesDir;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  if FSession.LoadLayersFile(OD_File.FileName, ErrorText) then
    ShowFileInTree(OD_File.FileName)
  else
    ShowMessage(ErrorText);
end;

procedure TSynthesisForm.B_ClearAllClick(Sender: TObject);
// Очистить протоколы и файлы
begin
  if Running then
  begin
    ShowMessage('Синтез идёт. Остановите его, чтобы очистить загруженное.');
    Exit;
  end;
  FSession.Clear;
  TV_Synthesis.Items.Clear;
end;

procedure TSynthesisForm.B_StartClick(Sender: TObject);
// Запуск синтеза
var
  I: Integer;
  ErrorText: string;
  Snapshot: TSynthesisSnapshot;
begin
  if Running then
  begin
    ShowMessage('Синтез уже идёт.');
    Exit;
  end;
  if Assigned(FOnClearLog) then
    FOnClearLog(Self);

  // Перед запуском проверяем, что есть слои и протоколы на все буквы
  if not FSession.CheckReady(ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;

  for I := 0 to FSession.ProtocolCount - 1 do
    Log(FSession.ProtocolLetters[I]);
  Log('Число слоев=' + IntToStr(FSession.LayerCount));
  Log('Первыйслой=' + IntToStr(FSession.Layers[0].LayerNumber) + ' ' +
    FSession.Layers[0].EZDFile);
  Log('Последний слой=' +
    IntToStr(FSession.Layers[FSession.LayerCount - 1].LayerNumber) + ' ' +
    FSession.Layers[FSession.LayerCount - 1].EZDFile);

  // папка запуска: копии слоёв и протоколов, synthesis.ini, журнал
  if not CreateSynthesisSnapshot(FSession, SynthesesDir, Now, Snapshot,
    ErrorText) then
  begin
    ShowMessage(ErrorText);
    Exit;
  end;
  Log('Папка синтеза: ' + Snapshot.Folder);

  FThread := TSynthesisThread.Create(FSession, FHost, Snapshot);
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
