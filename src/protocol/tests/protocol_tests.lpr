program protocol_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, ProtocolEditingTests, ProtocolFormatTests,
  ProtocolModelTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Protocol module tests';
  Application.Run;
  Application.Free;
end.
