unit PathUtilsTests;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, PathUtils;

type
  TPathUtilsTests = class(TTestCase)
  private
    FDirectory: string;
  protected
    procedure SetUp; override;
  published
    procedure MakePathRelativeStripsBaseDirectory;
    procedure MakePathRelativeKeepsOutsidePath;
    procedure MakePathRelativeKeepsPathForEmptyInput;
    procedure ResolvePathAddsBaseToRelativeName;
    procedure ResolvePathKeepsAbsolutePath;
    procedure ResolvePathKeepsEmptyName;
    procedure IsAbsolutePathRecognizesDriveAndRootedPaths;
  end;

implementation

procedure TPathUtilsTests.SetUp;
begin
  inherited SetUp;
  FDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'light_oligo_pathutils';
end;

procedure TPathUtilsTests.MakePathRelativeStripsBaseDirectory;
begin
  AssertEquals('run1' + PathDelim + 'Layer1_A10.ezd',
    MakePathRelative(FDirectory, IncludeTrailingPathDelimiter(FDirectory) +
      'run1' + PathDelim + 'Layer1_A10.ezd'));
end;

procedure TPathUtilsTests.MakePathRelativeKeepsOutsidePath;
begin
  AssertEquals('Z:\other\Layer1_A10.ezd',
    MakePathRelative(FDirectory, 'Z:\other\Layer1_A10.ezd'));
end;

procedure TPathUtilsTests.MakePathRelativeKeepsPathForEmptyInput;
begin
  AssertEquals('Layer1_A10.ezd', MakePathRelative('', 'Layer1_A10.ezd'));
  AssertEquals('', MakePathRelative(FDirectory, ''));
end;

procedure TPathUtilsTests.ResolvePathAddsBaseToRelativeName;
begin
  AssertEquals(IncludeTrailingPathDelimiter(FDirectory) + 'Layer1_A10.ezd',
    ResolvePath(FDirectory, 'Layer1_A10.ezd'));
end;

procedure TPathUtilsTests.ResolvePathKeepsAbsolutePath;
begin
  AssertEquals('Z:\other\Layer1_A10.ezd',
    ResolvePath(FDirectory, 'Z:\other\Layer1_A10.ezd'));
end;

procedure TPathUtilsTests.ResolvePathKeepsEmptyName;
begin
  AssertEquals('', ResolvePath(FDirectory, ''));
  AssertEquals('  ', ResolvePath(FDirectory, '  '));
end;

procedure TPathUtilsTests.IsAbsolutePathRecognizesDriveAndRootedPaths;
begin
  AssertTrue(IsAbsolutePath('D:\data\file.ezd'));
  AssertTrue(IsAbsolutePath('\data\file.ezd'));
  AssertTrue(IsAbsolutePath('/data/file.ezd'));
  AssertFalse(IsAbsolutePath('file.ezd'));
  AssertFalse(IsAbsolutePath('data' + PathDelim + 'file.ezd'));
  AssertFalse(IsAbsolutePath(''));
end;

initialization
  RegisterTest(TPathUtilsTests);

end.
