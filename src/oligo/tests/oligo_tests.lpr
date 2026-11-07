program oligo_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, OligoTests, LayerEzdTests,
  OligoSlicesFileTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Oligo module tests';
  Application.Run;
  Application.Free;
end.
