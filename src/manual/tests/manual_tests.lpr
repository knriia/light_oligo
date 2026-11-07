program manual_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, ManualTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Manual module tests';
  Application.Run;
  Application.Free;
end.
