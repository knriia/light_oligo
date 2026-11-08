program laser_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, LaserTests, LaserConfigMigrationTests,
  LaserArrayFolderTests, LayerEzdTests;

var
  Application: TTestRunner;

begin
  DefaultRunAllTests := True;
  DefaultFormat := fPlainNoTiming;
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Laser module tests';
  Application.Run;
  Application.Free;
end.
