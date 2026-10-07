unit SerialPort;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows;

type
  TSerialPort = class
  private
    FHandle: THandle;
    FPortName: string;
    FIsConnected: Boolean;
    FLastError: string;
    function ConfigurePort(BaudRate: Integer): Boolean;
  protected
    function GetPortName: string; virtual;
    function GetConnected: Boolean; virtual;
    function GetLastError: string; virtual;
  public
    constructor Create;
    destructor Destroy; override;

    function Open(const PortName: string; Baud: Integer = 9600): Boolean; virtual;
    procedure Close; virtual;
    function Write(const Data: AnsiString): Boolean; virtual;
    function ReadResponse(out Data: AnsiString;
      TimeoutMs: Cardinal = 1000): Boolean; virtual;
    procedure ClearInputBuffer; virtual;
    procedure ScanAvailablePorts(PortList: TStrings); virtual;

    property PortName: string read GetPortName;
    property Connected: Boolean read GetConnected;
    property LastError: string read GetLastError;
  end;

implementation

constructor TSerialPort.Create;
begin
  FHandle := INVALID_HANDLE_VALUE;
  FIsConnected := False;
end;

destructor TSerialPort.Destroy;
begin
  Close;
  inherited;
end;

function TSerialPort.Open(const PortName: string; Baud: Integer): Boolean;
begin
  Close;
  FHandle := CreateFile(PChar('\\.\' + PortName), GENERIC_READ or GENERIC_WRITE,
                        0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

  if FHandle = INVALID_HANDLE_VALUE then
  begin
    FPortName := PortName;
    FLastError := 'Ошибка открытия ' + PortName;
    Exit(False);
  end;

  FPortName := PortName;
  Result := ConfigurePort(Baud);
  FIsConnected := Result;
  if not Result then Close;
end;

procedure TSerialPort.Close;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
    FPortName := '';
  end;
  FIsConnected := False;
end;

function TSerialPort.ConfigurePort(BaudRate: Integer): Boolean;
var
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  if not GetCommState(FHandle, DCB) then Exit(False);

  DCB.BaudRate := BaudRate;
  DCB.ByteSize := 8;
  DCB.Parity := NOPARITY;
  DCB.StopBits := ONESTOPBIT;

  if not SetCommState(FHandle, DCB) then Exit(False);

  Timeouts.ReadIntervalTimeout := 50;
  Timeouts.ReadTotalTimeoutMultiplier := 10;
  Timeouts.ReadTotalTimeoutConstant := 100;
  Timeouts.WriteTotalTimeoutMultiplier := 10;
  Timeouts.WriteTotalTimeoutConstant := 100;

  Result := SetCommTimeouts(FHandle, Timeouts);
end;

function TSerialPort.Write(const Data: AnsiString): Boolean;
var
  BytesWritten: DWORD;
begin
  if not FIsConnected then
    Exit(False);
  if Length(Data) = 0 then
    Exit(True); // Пустая строка - ничего не пишем, но это не ошибка

  Result := WriteFile(FHandle, Data[1], Length(Data), BytesWritten, nil)
            and (BytesWritten = DWORD(Length(Data)));
end;

procedure TSerialPort.ClearInputBuffer;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
    PurgeComm(FHandle, PURGE_RXCLEAR);
end;

function TSerialPort.ReadResponse(out Data: AnsiString;
  TimeoutMs: Cardinal): Boolean;
var
  StartedAt: QWord;
  Errors: DWORD;
  ComStat: TComStat;
  BytesToRead: DWORD;
  BytesRead: DWORD;
  Buffer: array[0..255] of AnsiChar;
  Chunk: AnsiString;
begin
  Data := '';
  Result := False;

  if not FIsConnected then
  begin
    FLastError := 'COM-порт не подключён';
    Exit;
  end;

  StartedAt := GetTickCount64;
  repeat
    if not ClearCommError(FHandle, Errors, @ComStat) then
    begin
      FLastError := 'Не удалось проверить входной буфер COM-порта';
      Exit;
    end;

    if ComStat.cbInQue > 0 then
    begin
      BytesToRead := ComStat.cbInQue;
      if BytesToRead > SizeOf(Buffer) then
        BytesToRead := SizeOf(Buffer);

      BytesRead := 0;
      if not ReadFile(FHandle, Buffer[0], BytesToRead, BytesRead, nil) then
      begin
        FLastError := 'Не удалось прочитать ответ из COM-порта';
        Exit;
      end;

      if BytesRead > 0 then
      begin
        SetString(Chunk, PAnsiChar(@Buffer[0]), BytesRead);
        Data := Data + Chunk;

        if (Pos(#13, Data) > 0) or (Pos(#10, Data) > 0) then
          Break;
      end;
    end
    else
      Sleep(10);
  until GetTickCount64 - StartedAt >= TimeoutMs;

  Result := Length(Data) > 0;
  if not Result then
    FLastError := 'Тайм-аут ожидания ответа устройства';
end;

procedure TSerialPort.ScanAvailablePorts(PortList: TStrings);
var i: Integer; h: THandle;
begin
  PortList.Clear;
  for i := 1 to 20 do begin
    h := CreateFile(PChar('\\.\COM' + IntToStr(i)), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
    if h <> INVALID_HANDLE_VALUE then begin
      PortList.Add('COM' + IntToStr(i));
      CloseHandle(h);
    end;
  end;
end;

function TSerialPort.GetPortName: string;
begin
  Result := FPortName;
end;

function TSerialPort.GetConnected: Boolean;
begin
  Result := FIsConnected;
end;

function TSerialPort.GetLastError: string;
begin
  Result := FLastError;
end;

end.
