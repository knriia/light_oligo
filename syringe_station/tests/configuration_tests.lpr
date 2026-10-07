program configuration_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, ConfigurationTests, RuntimeStateTests,
  CoordinatorTests, ControllerTests, AutomationProtocolRunnerTests,
  WorkDispatcherTests, ManualControlsLayoutTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Syringe pump configuration tests';
  Application.Run;
  Application.Free;
end.
