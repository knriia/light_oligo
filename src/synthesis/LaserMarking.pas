unit LaserMarking;
// Маркировка слоя через EzCAD: порядок действий без самой программы EzCAD.
// Перед запуском EzCAD должен быть закрыт (может ещё закрываться после
// предыдущего слоя - ждём), иначе маркировка пошла бы чужим файлом или не
// пошла бы совсем. Потом EzCAD запускается с файлом слоя, ждёт открытия,
// получает команду маркировки нужное число раз и закрывается. Любая беда
// называется ошибкой, а не пропускается молча. Сами действия делает
// TEzCadDriver: в программе - через EzCadApp, в тестах - подставной.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, SynthesisPorts;

const
  EZCAD_CLOSE_WAIT_MS = 10000; // сколько ждём, пока EzCAD закроется
  EZCAD_POLL_MS = 200;         // как часто проверяем

type
  // Драйвер знает только про EzCAD. Остановка, ожидание и журнал - в контексте.
  TEzCadDriver = class
  public
    function IsRunning: Boolean; virtual; abstract;
    // Запускает EzCAD с файлом; False - не запустился.
    function Launch(const AEzdFile: string): Boolean; virtual; abstract;
    // Команда маркировки (F2); False - EzCAD не принял.
    function SendMark: Boolean; virtual; abstract;
    procedure Close; virtual; abstract;
    // EzCAD сейчас запустится: включить наблюдатель за его окнами.
    procedure Opening; virtual; abstract;
  end;

// Маркирует слой файлом AEzdFile: ARepeats раз, после каждой маркировки ждёт
// ATimeSeconds. AOpenDelayMs - пауза после запуска EzCAD. prFailed - EzCAD не
// закрылся, не запустился или не принял команду; AErrorText объясняет, что не
// сделано. EzCAD закрывается и после ошибки, если успел запуститься.
function MarkLayerWithEzCad(ADriver: TEzCadDriver;
  AContext: TExecutionContext; const AEzdFile: string; ARepeats: Integer;
  ATimeSeconds: Double; AOpenDelayMs: Integer;
  out AErrorText: string): TPortResult;

implementation

// Ждёт, пока EzCAD закроется; True - закрылся.
function WaitUntilClosed(ADriver: TEzCadDriver;
  AContext: TExecutionContext): Boolean;
var
  Waited: Integer;
begin
  Waited := 0;
  while ADriver.IsRunning and (Waited < EZCAD_CLOSE_WAIT_MS) do
  begin
    AContext.Poll(EZCAD_POLL_MS);
    Inc(Waited, EZCAD_POLL_MS);
  end;
  Result := not ADriver.IsRunning;
end;

procedure CloseAndWait(ADriver: TEzCadDriver; AContext: TExecutionContext);
begin
  if not ADriver.IsRunning then
    Exit;
  ADriver.Close;
  if WaitUntilClosed(ADriver, AContext) then
    AContext.Log('EzCAD closed')
  else
    AContext.Log('WARNING: EzCAD не закрылся за ' +
      IntToStr(EZCAD_CLOSE_WAIT_MS div 1000) + ' с');
end;

function MarkLayerWithEzCad(ADriver: TEzCadDriver;
  AContext: TExecutionContext; const AEzdFile: string; ARepeats: Integer;
  ATimeSeconds: Double; AOpenDelayMs: Integer;
  out AErrorText: string): TPortResult;
var
  I: Integer;
begin
  Result := prFailed;
  AErrorText := '';

  // EzCAD может ещё закрываться после предыдущего слоя
  if ADriver.IsRunning then
  begin
    AContext.Log('EzCAD уже запущен, ждём его закрытия');
    if not WaitUntilClosed(ADriver, AContext) then
    begin
      AErrorText := 'EzCAD2 уже запущен и не закрывается. Маркировка слоя ' +
        'не выполнена, чтобы не маркировать чужим файлом. Закройте EzCAD2 ' +
        'и запустите синтез снова.';
      Exit;
    end;
  end;

  ADriver.Opening;
  AContext.Log('EzCAD opening');
  if not ADriver.Launch(AEzdFile) then
  begin
    AErrorText := 'Не удалось запустить EzCAD2.exe с файлом слоя:' +
      LineEnding + AEzdFile;
    Exit;
  end;

  try
    AContext.Wait(AOpenDelayMs); // время на открытие EzCAD
    if not ADriver.IsRunning then
    begin
      AErrorText := 'EzCAD2 не запустился (или закрылся сразу после ' +
        'запуска). Маркировка слоя не выполнена:' + LineEnding + AEzdFile;
      Exit;
    end;
    for I := 1 to ARepeats do
    begin
      if AContext.StopRequested then
        Break;
      if not ADriver.SendMark then
      begin
        AErrorText := 'EzCAD2 не принял команду маркировки (маркировка ' +
          IntToStr(I) + ' из ' + IntToStr(ARepeats) + ').';
        Exit;
      end;
      AContext.Wait(Round(ATimeSeconds) * 1000); // время после маркировки
      AContext.Log('Laser----F2--->');
    end;
    Result := prSucceeded;
  finally
    CloseAndWait(ADriver, AContext);
  end;
end;

end.
