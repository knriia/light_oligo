unit MarkEzdWriter;
// Запись EZD-файлов через MarkEzd.dll (реализация TEzdWriter).

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes, LayerEzd;

type
  TEzdLogEvent = procedure(const AMsg: string) of object;

  TMarkEzdWriter = class(TEzdWriter)
  private
    FAppDir: string;
    FOwnerHandle: THandle;
    FOnLog: TEzdLogEvent;
    function Call(const AFunName: string; ARez: Integer;
      out AErrorText: string): Boolean;
  public
    // AAppDir - папка с EZCAD.CFG, AOwnerHandle - окно для сообщений DLL.
    constructor Create(const AAppDir: string; AOwnerHandle: THandle;
      AOnLog: TEzdLogEvent);
    function Open(out AErrorText: string): Boolean; override;
    function SavePoints(const AEzdFile, AEntityName: string;
      const APoints: TArrOfTPoint; out AErrorText: string): Boolean; override;
    procedure Close; override;
  end;

implementation

uses
  EzCadApi, Lmc1Results;

constructor TMarkEzdWriter.Create(const AAppDir: string; AOwnerHandle: THandle;
  AOnLog: TEzdLogEvent);
begin
  inherited Create;
  FAppDir := AAppDir;
  FOwnerHandle := AOwnerHandle;
  FOnLog := AOnLog;
end;

function TMarkEzdWriter.Call(const AFunName: string; ARez: Integer;
  out AErrorText: string): Boolean;
// пишет результат вызова в журнал; False и текст, если вызов неудачный
begin
  AErrorText := Lmc1ResultText(AFunName, ARez);
  if Assigned(FOnLog) then
    FOnLog(AErrorText);
  Result := ARez = LMC1_ERR_SUCCESS;
  if Result then
    AErrorText := '';
end;

function TMarkEzdWriter.Open(out AErrorText: string): Boolean;
// Для записи файлов плата маркера не нужна: без неё lmc1_Initial2 сообщает
// об ошибке устройства (без платы - код 5), но EZD сохраняются. Такие
// ошибки пишем в журнал и продолжаем; неудачное сохранение всё равно
// покажет результат lmc1_SaveEntLibToFile.
const
  DEVICE_ERRORS = [LMC1_ERR_FAILEDOPEN, LMC1_ERR_NODEVICE, LMC1_ERR_HARDVER,
    LMC1_ERR_DEVCFG];
var
  Rez: Integer;
begin
  Rez := lmc1_Initial2(WideString(FAppDir), True, FOwnerHandle);
  Result := Call('lmc1_Initial2', Rez, AErrorText);
  if Result then
    Exit;
  if Rez in DEVICE_ERRORS then
  begin
    if Assigned(FOnLog) then
      FOnLog('Плата маркера недоступна, EZD-файлы записываются без неё.');
    AErrorText := '';
    Exit(True);
  end;
  // иначе DLL остаётся в полуподключённом состоянии и следующее
  // подключение получает код 1 ("работает EZCAD")
  lmc1_Close;
end;

function TMarkEzdWriter.SavePoints(const AEzdFile, AEntityName: string;
  const APoints: TArrOfTPoint; out AErrorText: string): Boolean;
var
  Points: TArrOfTPoint;
begin
  Points := APoints; // DLL берёт указатель на массив
  Result := Call('lmc1_ClearEntLib', lmc1_ClearEntLib(), AErrorText) and
    Call('lmc1_AddPointToLib', lmc1_AddPointToLib(@Points[0], Length(Points),
      WideString(AEntityName), 1), AErrorText) and
    Call('lmc1_SaveEntLibToFile', lmc1_SaveEntLibToFile(WideString(AEzdFile)),
      AErrorText);
end;

procedure TMarkEzdWriter.Close;
var
  ErrorText: string;
begin
  Call('lmc1_Close', lmc1_Close, ErrorText);
end;

end.
