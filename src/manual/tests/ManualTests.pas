unit ManualTests;
// Тесты ручной вкладки: настройки вкладки.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, MarkGeometry, LaserPen,
  ManualSettings;

type
  TManualSettingsTests = class(TTestCase)
  private
    FDirectory: string;
    function FilePath(const AName: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure SettingsDefaultsAreFormerProgConfigValues;
    procedure SettingsRoundTrip;
    procedure SettingsKeepLaserPenInSameFile;
    procedure SettingsBadMatrixSizeFallsBackToDefault;
    procedure GeometryMissingKeysTakeGivenDefaults;
  end;

implementation

function TManualSettingsTests.FilePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDirectory) + AName;
end;

procedure TManualSettingsTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_manual_' + IntToStr(GetTickCount64);
  AssertTrue(ForceDirectories(FDirectory));
end;

procedure TManualSettingsTests.TearDown;
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

procedure TManualSettingsTests.SettingsDefaultsAreFormerProgConfigValues;
var
  S: TManualSettings;
begin
  S := LoadManualSettings(FilePath('missing.ini'));
  AssertEquals(0.1, S.Geometry.Step, 1e-9);
  AssertEquals(10, S.Geometry.Group);
  AssertEquals(0.1, S.Geometry.GroupStep, 1e-9);
  AssertTrue(S.Geometry.AutoCenter);
  AssertEquals(60.0, S.Geometry.SpotSize, 1e-9);
  AssertEquals(20.0, S.Geometry.SubstrateDiameter, 1e-9);
  AssertEquals(30, S.MatrixRows);
  AssertEquals(30, S.MatrixCols);
end;

procedure TManualSettingsTests.SettingsRoundTrip;
var
  S, L: TManualSettings;
  ErrorText: string;
begin
  S := DefaultManualSettings;
  S.Geometry.Step := 0.25;
  S.Geometry.AutoCenter := False;
  S.Geometry.BiasX := -1.5;
  S.Geometry.SubstrateDiameter := 25;
  S.MatrixRows := 2;
  S.MatrixCols := 7;
  AssertTrue(ErrorText, SaveManualSettings(FilePath('manual.ini'), S, ErrorText));
  L := LoadManualSettings(FilePath('manual.ini'));
  AssertEquals(0.25, L.Geometry.Step, 1e-9);
  AssertFalse(L.Geometry.AutoCenter);
  AssertEquals(-1.5, L.Geometry.BiasX, 1e-9);
  AssertEquals(25.0, L.Geometry.SubstrateDiameter, 1e-9);
  AssertEquals(2, L.MatrixRows);
  AssertEquals(7, L.MatrixCols);
end;

procedure TManualSettingsTests.SettingsKeepLaserPenInSameFile;
var
  Pen: TLaserPen;
  ErrorText: string;
begin
  Pen := DefaultLaserPen;
  Pen.nPenNo := 4;
  AssertTrue(ErrorText, SaveLaserPen(FilePath('manual.ini'), Pen, ErrorText));
  AssertTrue(ErrorText, SaveManualSettings(FilePath('manual.ini'),
    DefaultManualSettings, ErrorText));
  AssertEquals(4, LoadLaserPen(FilePath('manual.ini')).nPenNo);
end;

procedure TManualSettingsTests.SettingsBadMatrixSizeFallsBackToDefault;
var
  Lines: TStringList;
  S: TManualSettings;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Manual]');
    Lines.Add('MatrixRows=0');
    Lines.Add('MatrixCols=abc');
    Lines.SaveToFile(FilePath('manual.ini'));
  finally
    Lines.Free;
  end;
  S := LoadManualSettings(FilePath('manual.ini'));
  AssertEquals(30, S.MatrixRows);
  AssertEquals(30, S.MatrixCols);
end;

procedure TManualSettingsTests.GeometryMissingKeysTakeGivenDefaults;
var
  Lines: TStringList;
  D, G: TMarkGeometry;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Geometry]');
    Lines.Add('Step=0.3');
    Lines.Add('SpotSize=-5');
    Lines.SaveToFile(FilePath('g.ini'));
  finally
    Lines.Free;
  end;
  D := DefaultMarkGeometry;
  D.SpotSize := 60;
  D.Group := 4;
  G := LoadMarkGeometry(FilePath('g.ini'), D);
  AssertEquals(0.3, G.Step, 1e-9);
  AssertEquals('нет ключа', 4, G.Group);
  AssertEquals('недопустимое', 60.0, G.SpotSize, 1e-9);
end;

initialization
  RegisterTest(TManualSettingsTests);

end.
