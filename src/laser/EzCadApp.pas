unit EzCadApp;
// Управление программой EzCAD2 снаружи: запуск с EZD-файлом, закрытие,
// команда маркировки (F2) и наблюдатель, который после запуска закрывает
// окна EzCAD с лицензией и предупреждениями.
// Позже это заменит маркировка напрямую через MarkEzd.dll.

{$mode ObjFPC}{$H+}

interface

uses
  Windows, SysUtils;

const
  EZCAD_EXE = 'EzCad2.exe';
  EZCAD_LICENSE_TITLE = 'License'; // окно лицензии: подтверждаем Enter
  EZCAD_WARNING_TITLE = 'EzCad';   // окно предупреждения: закрываем
  EZCAD_WATCH_TICKS = 100;         // сколько тиков таймера следить за окнами

type
  // Поиск окна по заголовку и отправка ему сообщения (в тестах подменяются).
  TFindWindowFunc = function(const ATitle: string): HWND;
  TPostMessageFunc = function(AWnd: HWND; AMsg: UINT; AWParam: WPARAM): Boolean;

  // Окна EzCAD появляются не сразу после запуска, поэтому их ищут по таймеру:
  // Start - начать, Tick на каждом срабатывании таймера; Tick = False -
  // наблюдение закончено, таймер можно выключить.
  TEzCadDialogWatcher = class
  private
    FFindWindow: TFindWindowFunc;
    FPostMessage: TPostMessageFunc;
    FTicksLeft: Integer;
  public
    constructor Create(AFindWindow: TFindWindowFunc = nil;
      APostMessage: TPostMessageFunc = nil);
    procedure Start;
    function Tick: Boolean;
    function Active: Boolean;
  end;

function EzCadRunning: Boolean;
// Запускает EzCAD2 из папки программы с EZD-файлом. Путь может содержать
// кириллицу и пробелы. False - не запустился.
function LaunchEzCad(const AAppDir, AEzdFile: string): Boolean;
// Закрывает EzCAD (Alt+F4 и WM_CLOSE). False - EzCAD не запущен.
function CloseEzCad: Boolean;
// Команда маркировки: F2 в окно EzCAD. False - EzCAD не запущен.
function SendEzCadMark: Boolean;

implementation

uses
  ShellApi, WinProcessUtils;

function WindowsFindWindow(const ATitle: string): HWND;
begin
  Result := FindWindow(nil, PChar(ATitle));
end;

function WindowsPostMessage(AWnd: HWND; AMsg: UINT; AWParam: WPARAM): Boolean;
begin
  Result := PostMessage(AWnd, AMsg, AWParam, 0);
end;

constructor TEzCadDialogWatcher.Create(AFindWindow: TFindWindowFunc;
  APostMessage: TPostMessageFunc);
begin
  inherited Create;
  FFindWindow := AFindWindow;
  if FFindWindow = nil then
    FFindWindow := @WindowsFindWindow;
  FPostMessage := APostMessage;
  if FPostMessage = nil then
    FPostMessage := @WindowsPostMessage;
end;

procedure TEzCadDialogWatcher.Start;
begin
  FTicksLeft := EZCAD_WATCH_TICKS;
end;

function TEzCadDialogWatcher.Tick: Boolean;
var
  Wnd: HWND;
begin
  if FTicksLeft <= 0 then
    Exit(False);
  Wnd := FFindWindow(EZCAD_LICENSE_TITLE);
  if Wnd <> 0 then
    FPostMessage(Wnd, WM_KEYDOWN, VK_RETURN);
  Wnd := FFindWindow(EZCAD_WARNING_TITLE);
  if Wnd <> 0 then
    FPostMessage(Wnd, WM_CLOSE, 0);
  Dec(FTicksLeft);
  Result := FTicksLeft > 0;
end;

function TEzCadDialogWatcher.Active: Boolean;
begin
  Result := FTicksLeft > 0;
end;

function EzCadRunning: Boolean;
begin
  Result := GetProcessHandle(EZCAD_EXE) <> 0;
end;

function LaunchEzCad(const AAppDir, AEzdFile: string): Boolean;
begin
  Result := ShellExecuteW(0, 'open',
    PWideChar(UnicodeString(IncludeTrailingPathDelimiter(AAppDir) + EZCAD_EXE)),
    PWideChar(UnicodeString('"' + AEzdFile + '"')), nil, SW_SHOWMINIMIZED) > 32;
end;

function CloseEzCad: Boolean;
var
  Process: THandle;
begin
  Process := GetProcessHandle(EZCAD_EXE);
  Result := Process <> 0;
  if not Result then
    Exit;
  SendMsgToProcWithMod(EZCAD_EXE, VK_F4, VK_MENU); // Alt+F4
  PostMessage(Process, WM_CLOSE, 0, 0);
end;

function SendEzCadMark: Boolean;
begin
  Result := EzCadRunning and SendMsgToProc(EZCAD_EXE, VK_F2);
end;

end.
