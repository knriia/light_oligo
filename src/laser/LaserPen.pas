unit LaserPen;
// Параметры пера лазера (то, что передаётся в lmc1_SetPenParam2).
// Они записываются в каждый EZD-файл, поэтому задаются при его создании.
// Хранятся в разделе [LaserPen] конфига вкладки; модуль не зависит от DLL.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

const
  LASER_PEN_SECTION = 'LaserPen';
  LASER_PEN_FILE = 'laser.ini'; // параметры лазера, с которыми созданы EZD слоёв

type
  TLaserPen = record
    nPenNo: Integer;          // номер пера (0-255)
    nMarkLoop: Integer;       // количество повторов
    dMarkSpeed: Double;       // скорость маркировки, мм/с
    dPowerRatio: Double;      // мощность, % (0-100)
    dCurrent: Double;         // ток, А
    nFreq: Integer;           // частота, Гц
    dQPulseWidth: Double;     // ширина Q-импульса, мкс
    nStartTC: Integer;        // задержка включения лазера, мкс
    nLaserOffTC: Integer;     // задержка выключения лазера, мкс
    nEndTC: Integer;          // задержка в конце, мкс
    nPolyTC: Integer;         // задержка в узле, мкс
    dJumpSpeed: Double;       // скорость перехода, мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние перехода
    dPointTime: Double;       // время точки, мс
    nSpiWave: Integer;        // тип волны SPI
    bWobbleMode: Boolean;     // воблинг
    dWobbleDiameter: Double;  // диаметр воблинга, мм
    dWobbleDist: Double;      // шаг воблинга, мм
  end;

// Значения по умолчанию - те, что раньше лежали в ProgConfig.ini.
function DefaultLaserPen: TLaserPen;
// Перо из раздела [LaserPen]. Нет файла, ключа или значение недопустимо -
// для этого параметра берётся значение по умолчанию.
function LoadLaserPen(const AFileName: string): TLaserPen;
// Записывает раздел [LaserPen]; другие разделы файла сохраняются.
function SaveLaserPen(const AFileName: string; const APen: TLaserPen;
  out AErrorText: string): Boolean;

implementation

uses
  IniFiles, IniNumbers;

function DefaultLaserPen: TLaserPen;
begin
  Result := Default(TLaserPen);
  Result.nPenNo := 10;
  Result.nMarkLoop := 1;
  Result.dMarkSpeed := 500;
  Result.dPowerRatio := 100;
  Result.dCurrent := 10;
  Result.nFreq := 30000;
  Result.dQPulseWidth := 10;
  Result.nStartTC := 150;
  Result.nLaserOffTC := 150;
  Result.nEndTC := 300;
  Result.nPolyTC := 100;
  Result.dJumpSpeed := 1000;
  Result.nJumpPosTC := 10;
  Result.nJumpDistTC := 10;
  Result.dPointTime := 10;
  Result.nSpiWave := 0;
  Result.bWobbleMode := False;
  Result.dWobbleDiameter := 0;
  Result.dWobbleDist := 0;
end;

function LoadLaserPen(const AFileName: string): TLaserPen;
var
  Ini: TMemIniFile;
  D: TLaserPen;

  function Int(const AKey: string; ADefault, AMin, AMax: Integer): Integer;
  begin
    Result := Ini.ReadInteger(LASER_PEN_SECTION, AKey, ADefault);
    if (Result < AMin) or (Result > AMax) then
      Result := ADefault;
  end;

  function Num(const AKey: string; ADefault, AMin, AMax: Double): Double;
  begin
    Result := ReadIniFloat(Ini, LASER_PEN_SECTION, AKey, ADefault);
    if (Result < AMin) or (Result > AMax) then
      Result := ADefault;
  end;

begin
  D := DefaultLaserPen;
  Result := D;
  if not FileExists(AFileName) then
    Exit;
  try
    Ini := TMemIniFile.Create(AFileName);
  except
    Exit; // файл не читается - остаются значения по умолчанию
  end;
  try
    Result.nPenNo := Int('PenNo', D.nPenNo, 0, 255);
    Result.nMarkLoop := Int('MarkLoop', D.nMarkLoop, 1, MaxInt);
    Result.dMarkSpeed := Num('MarkSpeed', D.dMarkSpeed, 1e-9, MaxInt);
    Result.dPowerRatio := Num('PowerRatio', D.dPowerRatio, 0, 100);
    Result.dCurrent := Num('Current', D.dCurrent, 0, MaxInt);
    Result.nFreq := Int('Freq', D.nFreq, 1, MaxInt);
    Result.dQPulseWidth := Num('QPulseWidth', D.dQPulseWidth, 0, MaxInt);
    Result.nStartTC := Int('StartTC', D.nStartTC, -MaxInt, MaxInt);
    Result.nLaserOffTC := Int('LaserOffTC', D.nLaserOffTC, -MaxInt, MaxInt);
    Result.nEndTC := Int('EndTC', D.nEndTC, -MaxInt, MaxInt);
    Result.nPolyTC := Int('PolyTC', D.nPolyTC, -MaxInt, MaxInt);
    Result.dJumpSpeed := Num('JumpSpeed', D.dJumpSpeed, 1e-9, MaxInt);
    Result.nJumpPosTC := Int('JumpPosTC', D.nJumpPosTC, -MaxInt, MaxInt);
    Result.nJumpDistTC := Int('JumpDistTC', D.nJumpDistTC, -MaxInt, MaxInt);
    Result.dPointTime := Num('PointTime', D.dPointTime, 0, MaxInt);
    Result.nSpiWave := Int('SpiWave', D.nSpiWave, 0, MaxInt);
    Result.bWobbleMode := Ini.ReadBool(LASER_PEN_SECTION, 'WobbleMode',
      D.bWobbleMode);
    Result.dWobbleDiameter := Num('WobbleDiameter', D.dWobbleDiameter, 0, MaxInt);
    Result.dWobbleDist := Num('WobbleDist', D.dWobbleDist, 0, MaxInt);
  finally
    Ini.Free;
  end;
end;

function SaveLaserPen(const AFileName: string; const APen: TLaserPen;
  out AErrorText: string): Boolean;
var
  Ini: TMemIniFile;
begin
  Result := False;
  AErrorText := '';
  try
    Ini := TMemIniFile.Create(AFileName);
    try
      Ini.WriteInteger(LASER_PEN_SECTION, 'PenNo', APen.nPenNo);
      Ini.WriteInteger(LASER_PEN_SECTION, 'MarkLoop', APen.nMarkLoop);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'MarkSpeed', APen.dMarkSpeed);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'PowerRatio', APen.dPowerRatio);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'Current', APen.dCurrent);
      Ini.WriteInteger(LASER_PEN_SECTION, 'Freq', APen.nFreq);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'QPulseWidth', APen.dQPulseWidth);
      Ini.WriteInteger(LASER_PEN_SECTION, 'StartTC', APen.nStartTC);
      Ini.WriteInteger(LASER_PEN_SECTION, 'LaserOffTC', APen.nLaserOffTC);
      Ini.WriteInteger(LASER_PEN_SECTION, 'EndTC', APen.nEndTC);
      Ini.WriteInteger(LASER_PEN_SECTION, 'PolyTC', APen.nPolyTC);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'JumpSpeed', APen.dJumpSpeed);
      Ini.WriteInteger(LASER_PEN_SECTION, 'JumpPosTC', APen.nJumpPosTC);
      Ini.WriteInteger(LASER_PEN_SECTION, 'JumpDistTC', APen.nJumpDistTC);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'PointTime', APen.dPointTime);
      Ini.WriteInteger(LASER_PEN_SECTION, 'SpiWave', APen.nSpiWave);
      Ini.WriteBool(LASER_PEN_SECTION, 'WobbleMode', APen.bWobbleMode);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'WobbleDiameter', APen.dWobbleDiameter);
      WriteIniFloat(Ini, LASER_PEN_SECTION, 'WobbleDist', APen.dWobbleDist);
      Ini.UpdateFile;
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      AErrorText := 'Не удалось записать параметры лазера:' + LineEnding +
        AFileName + LineEnding + E.Message;
  end;
end;

end.
