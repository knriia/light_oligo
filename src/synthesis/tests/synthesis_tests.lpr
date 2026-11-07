program synthesis_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, LaserMarkingTests, SynthesisFolderTests,
  SynthesisRunnerTests, SynthesisSessionTests, SynthesisWorkspaceTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Synthesis module tests';
  Application.Run;
  Application.Free;
end.
