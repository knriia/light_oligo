program project_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, ProjectModelTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Project module tests';
  Application.Run;
  Application.Free;
end.
