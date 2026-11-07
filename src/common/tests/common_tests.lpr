program common_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, AppPathsTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Common module tests';
  Application.Run;
  Application.Free;
end.
