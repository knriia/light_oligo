program markezd_tests;
// Интеграционные тесты с настоящей MarkEzd.dll.
// Собираются в bin\ рядом с DLL и EZCAD.CFG и запускаются оттуда.
// LightOligo и EzCAD при запуске должны быть закрыты.

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, EzCadApiTests, MarkEzdWriterTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'MarkEzd.dll integration tests';
  Application.Run;
  Application.Free;
end.
