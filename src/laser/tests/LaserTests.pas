unit LaserTests;
// Тесты вспомогательной логики лазера: текст результатов MarkEzd.dll,
// параметры пера в конфиге вкладки.

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, fpcunit, testregistry, Lmc1Results, LaserPen,
  EzCadApp;

type
  TLmc1ResultsTests = class(TTestCase)
  published
    procedure TextStartsWithFunctionAndCode;
    procedure KnownAndUnknownCodesDiffer;
    procedure EveryDocumentedCodeHasOwnText;
  end;

  TEzCadDialogWatcherTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure ConfirmsLicenseAndClosesWarning;
    procedure DoesNothingWithoutWindows;
    procedure StopsAfterGivenTicks;
    procedure StartRestartsWatching;
  end;

  TLaserPenTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
    procedure WriteLines(const AName: string; const ALines: array of string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MissingFileGivesDefaults;
    procedure RoundTripKeepsEveryField;
    procedure BadValuesFallBackToDefaults;
    procedure CommaIsReadAsDecimalPoint;
    procedure SaveKeepsOtherSections;
    procedure SaveReportsUnwritablePath;
  end;

implementation

procedure TLmc1ResultsTests.TextStartsWithFunctionAndCode;
begin
  AssertEquals(1, Pos('lmc1_Initial2 -> 0 ', Lmc1ResultText('lmc1_Initial2', 0)));
  AssertEquals(1, Pos('lmc1_Close -> 4 ', Lmc1ResultText('lmc1_Close', 4)));
  AssertEquals(1, Pos('f -> -1 ', Lmc1ResultText('f', -1)));
end;

procedure TLmc1ResultsTests.KnownAndUnknownCodesDiffer;
begin
  AssertTrue(Lmc1ResultText('f', 99) = Lmc1ResultText('f', 20) .Replace(' 20 ', ' 99 '));
  AssertFalse(Lmc1ResultText('f', 0) = Lmc1ResultText('f', 99).Replace(' 99 ', ' 0 '));
end;

procedure TLmc1ResultsTests.EveryDocumentedCodeHasOwnText;
var
  Texts: TStringList;
  Code: Integer;
  Text: string;
begin
  Texts := TStringList.Create;
  try
    for Code := 0 to 21 do
    begin
      if Code = 20 then
        Continue; // кода 20 нет в документации SDK
      Text := Lmc1ResultText('f', Code);
      Text := Copy(Text, Pos(' ', Copy(Text, 6, MaxInt)) + 6, MaxInt);
      AssertEquals('код ' + IntToStr(Code), -1, Texts.IndexOf(Text));
      Texts.Add(Text);
    end;
  finally
    Texts.Free;
  end;
end;

{ TEzCadDialogWatcherTests }

var
  OpenWindows: string; // заголовки открытых окон через '|'
  Posted: string;      // что отправлено: '<окно>:<сообщение>:<параметр>;'

function FakeFindWindow(const ATitle: string): HWND;
// окно 1 - лицензия, окно 2 - предупреждение
begin
  Result := 0;
  if Pos('|' + ATitle + '|', '|' + OpenWindows + '|') = 0 then
    Exit;
  if ATitle = EZCAD_LICENSE_TITLE then
    Result := 1
  else if ATitle = EZCAD_WARNING_TITLE then
    Result := 2;
end;

function FakePostMessage(AWnd: HWND; AMsg: UINT; AWParam: WPARAM): Boolean;
begin
  Posted := Posted + IntToStr(AWnd) + ':' + IntToStr(AMsg) + ':' +
    IntToStr(AWParam) + ';';
  Result := True;
end;

procedure TEzCadDialogWatcherTests.SetUp;
begin
  inherited SetUp;
  OpenWindows := '';
  Posted := '';
end;

procedure TEzCadDialogWatcherTests.ConfirmsLicenseAndClosesWarning;
var
  W: TEzCadDialogWatcher;
begin
  W := TEzCadDialogWatcher.Create(@FakeFindWindow, @FakePostMessage);
  try
    OpenWindows := EZCAD_LICENSE_TITLE + '|' + EZCAD_WARNING_TITLE;
    W.Start;
    AssertTrue(W.Tick);
    AssertEquals('1:' + IntToStr(WM_KEYDOWN) + ':' + IntToStr(VK_RETURN) + ';' +
      '2:' + IntToStr(WM_CLOSE) + ':0;', Posted);
  finally
    W.Free;
  end;
end;

procedure TEzCadDialogWatcherTests.DoesNothingWithoutWindows;
var
  W: TEzCadDialogWatcher;
begin
  W := TEzCadDialogWatcher.Create(@FakeFindWindow, @FakePostMessage);
  try
    W.Start;
    AssertTrue(W.Tick);
    AssertEquals('', Posted);
  finally
    W.Free;
  end;
end;

procedure TEzCadDialogWatcherTests.StopsAfterGivenTicks;
var
  W: TEzCadDialogWatcher;
  I: Integer;
begin
  W := TEzCadDialogWatcher.Create(@FakeFindWindow, @FakePostMessage);
  try
    AssertFalse('до Start не следит', W.Tick);
    W.Start;
    for I := 1 to EZCAD_WATCH_TICKS - 1 do
      AssertTrue(W.Tick);
    AssertFalse('последний тик', W.Tick);
    AssertFalse(W.Active);
    OpenWindows := EZCAD_WARNING_TITLE;
    AssertFalse(W.Tick);
    AssertEquals('после окончания окна не трогает', '', Posted);
  finally
    W.Free;
  end;
end;

procedure TEzCadDialogWatcherTests.StartRestartsWatching;
var
  W: TEzCadDialogWatcher;
  I: Integer;
begin
  W := TEzCadDialogWatcher.Create(@FakeFindWindow, @FakePostMessage);
  try
    W.Start;
    for I := 1 to 10 do
      W.Tick;
    W.Start;
    for I := 1 to EZCAD_WATCH_TICKS - 1 do
      AssertTrue(W.Tick);
    AssertFalse(W.Tick);
  finally
    W.Free;
  end;
end;

{ TLaserPenTests }

function TLaserPenTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TLaserPenTests.WriteLines(const AName: string;
  const ALines: array of string);
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    for I := 0 to High(ALines) do
      Lines.Add(ALines[I]);
    Lines.SaveToFile(FilePath(AName));
  finally
    Lines.Free;
  end;
end;

procedure TLaserPenTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_pen_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TLaserPenTests.TearDown;
var
  Search: TSearchRec;
begin
  if FindFirst(FilePath('*'), faAnyFile and not faDirectory, Search) = 0 then
  try
    repeat
      DeleteFile(FilePath(Search.Name));
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  RemoveDir(FDirectory);
  inherited TearDown;
end;

procedure TLaserPenTests.MissingFileGivesDefaults;
var
  P: TLaserPen;
begin
  P := LoadLaserPen(FilePath('missing.ini'));
  AssertEquals(10, P.nPenNo);
  AssertEquals(1, P.nMarkLoop);
  AssertEquals(500.0, P.dMarkSpeed, 1e-9);
  AssertEquals(100.0, P.dPowerRatio, 1e-9);
  AssertEquals('частота в Гц', 30000, P.nFreq);
  AssertEquals(10.0, P.dPointTime, 1e-9);
  AssertFalse(P.bWobbleMode);
end;

procedure TLaserPenTests.RoundTripKeepsEveryField;
var
  P, L: TLaserPen;
  ErrorText: string;
begin
  P.nPenNo := 3;
  P.nMarkLoop := 2;
  P.dMarkSpeed := 777.5;
  P.dPowerRatio := 33.25;
  P.dCurrent := 1.5;
  P.nFreq := 20000;
  P.dQPulseWidth := 4;
  P.nStartTC := 50;
  P.nLaserOffTC := 151;
  P.nEndTC := 101;
  P.nPolyTC := 51;
  P.dJumpSpeed := 4000;
  P.nJumpPosTC := 500;
  P.nJumpDistTC := 100;
  P.dPointTime := 0.25;
  P.nSpiWave := 1;
  P.bWobbleMode := True;
  P.dWobbleDiameter := 1.2;
  P.dWobbleDist := 0.5;
  AssertTrue(ErrorText, SaveLaserPen(FilePath('p.ini'), P, ErrorText));
  L := LoadLaserPen(FilePath('p.ini'));
  AssertEquals(3, L.nPenNo);
  AssertEquals(2, L.nMarkLoop);
  AssertEquals(777.5, L.dMarkSpeed, 1e-9);
  AssertEquals(33.25, L.dPowerRatio, 1e-9);
  AssertEquals(1.5, L.dCurrent, 1e-9);
  AssertEquals(20000, L.nFreq);
  AssertEquals(4.0, L.dQPulseWidth, 1e-9);
  AssertEquals(50, L.nStartTC);
  AssertEquals(151, L.nLaserOffTC);
  AssertEquals(101, L.nEndTC);
  AssertEquals(51, L.nPolyTC);
  AssertEquals(4000.0, L.dJumpSpeed, 1e-9);
  AssertEquals(500, L.nJumpPosTC);
  AssertEquals(100, L.nJumpDistTC);
  AssertEquals(0.25, L.dPointTime, 1e-9);
  AssertEquals(1, L.nSpiWave);
  AssertTrue(L.bWobbleMode);
  AssertEquals(1.2, L.dWobbleDiameter, 1e-9);
  AssertEquals(0.5, L.dWobbleDist, 1e-9);
end;

procedure TLaserPenTests.BadValuesFallBackToDefaults;
var
  P: TLaserPen;
begin
  WriteLines('p.ini', ['[LaserPen]', 'PenNo=300', 'MarkLoop=0',
    'MarkSpeed=-1', 'PowerRatio=150', 'Freq=abc', 'PointTime=0.5']);
  P := LoadLaserPen(FilePath('p.ini'));
  AssertEquals('перо 0-255', 10, P.nPenNo);
  AssertEquals('повторов хотя бы 1', 1, P.nMarkLoop);
  AssertEquals('скорость > 0', 500.0, P.dMarkSpeed, 1e-9);
  AssertEquals('мощность 0-100', 100.0, P.dPowerRatio, 1e-9);
  AssertEquals('не число', 30000, P.nFreq);
  AssertEquals('допустимое значение читается', 0.5, P.dPointTime, 1e-9);
end;

procedure TLaserPenTests.CommaIsReadAsDecimalPoint;
begin
  WriteLines('p.ini', ['[LaserPen]', 'MarkSpeed=12,5']);
  AssertEquals(12.5, LoadLaserPen(FilePath('p.ini')).dMarkSpeed, 1e-9);
end;

procedure TLaserPenTests.SaveKeepsOtherSections;
var
  Lines: TStringList;
  ErrorText: string;
begin
  WriteLines('tab.ini', ['[Geometry]', 'Step=0.2']);
  AssertTrue(ErrorText, SaveLaserPen(FilePath('tab.ini'), DefaultLaserPen,
    ErrorText));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FilePath('tab.ini'));
    AssertTrue(Lines.IndexOf('Step=0.2') >= 0);
    AssertTrue(Lines.IndexOf('[LaserPen]') >= 0);
    AssertTrue('дробные - с точкой', Lines.IndexOf('PointTime=10') >= 0);
  finally
    Lines.Free;
  end;
end;

procedure TLaserPenTests.SaveReportsUnwritablePath;
var
  ErrorText: string;
begin
  // на месте папки - файл
  WriteLines('blocker', ['x']);
  AssertFalse(SaveLaserPen(FilePath('blocker' + PathDelim + 'p.ini'),
    DefaultLaserPen, ErrorText));
  AssertTrue(ErrorText <> '');
end;

initialization
  RegisterTest(TEzCadDialogWatcherTests);
  RegisterTest(TLaserPenTests);
  RegisterTest(TLmc1ResultsTests);

end.
