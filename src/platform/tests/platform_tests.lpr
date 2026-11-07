program platform_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, AppPathsTests, PathUtilsTests,
  LocalizationTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Platform module tests';
  Application.Run;
  Application.Free;
end.
