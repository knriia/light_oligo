unit WinProcessUtils;
// Поиск процессов и окон Windows, отправка нажатий клавиш (управление EzCAD)

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, JwaTlHelp32, JwaPsApi, StrUtils;

Function SendMsgToProc(aProcName: String;
                       aKeyCode: Integer): boolean;
Function SendMsgToProcWithMod(aProcName: String;
                              aKeyCode: Integer;
                              aModifier: Integer): boolean;
Function GetHWNDByExeName(const ExeName: string): HWND;
Function GetProcessHandle(const AProcessName: string): THandle;

implementation

function GetHWNDByExeName(const ExeName: string): HWND;
// определение дескриптора главного окна программы по его ExeName
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
  ProcessID: DWORD;
  hWndTemp: HWND;
  ProcessIDCheck: DWORD;
  ProcessFound: Boolean;
begin
  Result := 0;
  ProcessFound := False;
  ProcessID := 0;

  // Шаг 1: Сначала находим PID процесса по имени исполняемого файла
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot <> INVALID_HANDLE_VALUE then
  try
    pe32.dwSize := SizeOf(TProcessEntry32);
    if Process32First(hSnapshot, pe32) then
    begin
      repeat
        if LowerCase(ExtractFileName(pe32.szExeFile)) = LowerCase(ExeName) then
        begin
          ProcessID := pe32.th32ProcessID;
          ProcessFound := True;
          Break;
        end;
      until not Process32Next(hSnapshot, pe32);
    end;
  finally
    CloseHandle(hSnapshot);
  end;

  if not ProcessFound then Exit;

  // Шаг 2: Находим главное окно процесса
  hWndTemp := FindWindow(nil, nil);
  while hWndTemp <> 0 do
  begin
    GetWindowThreadProcessId(hWndTemp, @ProcessIDCheck);
    if ProcessIDCheck = ProcessID then
    begin
      // Проверяем, что это главное окно (не дочернее) и оно видимо
      if (GetWindow(hWndTemp, GW_OWNER) = 0) and IsWindowVisible(hWndTemp) then
      begin
        Result := hWndTemp;
        Break;
      end;
    end;
    hWndTemp := GetWindow(hWndTemp, GW_HWNDNEXT);
  end;
end;

function GetProcessHandle(const AProcessName: string): THandle;
// получить дескриптор процесса
var
  ProcessIDs: array[0..1023] of DWORD;
  Count, I: DWORD;
  ProcessHandle: THandle;
  ProcessName: array[0..MAX_PATH] of Char;
begin
  Result := 0;
  if EnumProcesses(ProcessIDs, SizeOf(ProcessIDs), Count) then
  begin
    for I := 0 to Count div SizeOf(DWORD) - 1 do
    begin
      ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessIDs[I]);
      if ProcessHandle <> 0 then
      begin
        if GetModuleFileNameEx(ProcessHandle, 0, ProcessName, SizeOf(ProcessName) div SizeOf(Char)) > 0 then
        begin
          if AnsiContainsStr(ProcessName, AProcessName) then
          begin
            Result := ProcessHandle;
            Break;
          end;
        end;
        CloseHandle(ProcessHandle);
      end;
    end;
  end;
end;

function SendMsgToProc(aProcName: String; aKeyCode: Integer): boolean;
// послать команду нажатия клавиши приложению по его ExeName
var
  WinH: HWND;
  Input: TInput; // Массив для нажатия и отпускания клавиши
  pI: PInput;
begin
  WinH:=GetHWNDByExeName(aProcName);
  if WinH <> 0 then
  begin
    SetForegroundWindow(WinH);

    // Настройка нажатия клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));
    Result := True;
  end
  else
  begin
    // Обработка ошибки, если окно не найдено
    //Caption:='0';
    Result := False;
  end;
end;

function SendMsgToProcWithMod(aProcName: String; aKeyCode: Integer; aModifier: Integer): boolean;
// послать команду нажатия клавиши вместе с модификатором приложению по его ExeName
var
  WinH: HWND;
  Input: TInput; // Запись для нажатия и отпускания клавиши
  pI: PInput;
begin
  WinH:=GetHWNDByExeName(aProcName);
  if WinH <> 0 then
  begin
    SetForegroundWindow(WinH);

    // Настройка нажатия модификатора Alt или Shift
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aModifier;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши модификатора
    SendInput(1, pI, SizeOf(TInput));

    // Настройка нажатия клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши модификатора
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aModifier;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));

    Result := True;
  end
  else
  begin
    // Обработка ошибки, если окно не найдено
    //Caption:='0';
    Result := False;
  end;
end;

end.
