unit DispenserProtocolTests;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, DispenserProtocol;

type
  TDispenserProtocolTests = class(TTestCase)
  published
    procedure BuildsNonDistributiveChannelOneAspirate;
    procedure BuildsNonDistributiveChannelTwoDispense;
    procedure BuildsDistributiveChannelCommand;
    procedure RejectsUnsupportedNonDistributiveChannel;
    procedure MovementCommandCoversChannelAndDirectionEdges;
    procedure MovementCommandStartSpeedFallsBackAboveLimit;
    procedure BuildsNonDistributiveBypassCommand;
    procedure BuildsNonDistributiveRestoreCommand;
    procedure RejectsDistributiveValveCommand;
    procedure RejectsUnsupportedNonDistributiveValveChannel;
    procedure ValveCommandCoversAllChannels;
    procedure BuildsPlungerOnlyDispenseCommand;
    procedure BuildsPlungerOnlyAspirateCommand;
    procedure PlungerCommandStartSpeedFallsBackAboveLimit;
    procedure PlungerCommandRejectsInvalidArguments;
    procedure FormatResponseEscapesNonPrintableAndEmpty;
    procedure FormatResponseKeepsPrintableBoundaries;
    procedure ParseStatusResponseAcceptsValidFrame;
    procedure ParseStatusResponseAcceptsBoundaryStatusBytes;
    procedure ParseStatusResponseRejectsMalformedFrames;
    procedure ParseAsciiQueryResponseStripsStatusByte;
    procedure ParseAsciiQueryResponseRejectsMalformedFrames;
    procedure ParseAsciiQueryResponseResetsPositionOnFailure;
    procedure StatusDescriptionCoversReadyBusyAndErrors;
    procedure StatusDescriptionCoversAllKnownErrorCodes;
    procedure StatusDescriptionIgnoresUpperBits;
  end;

implementation

procedure TDispenserProtocolTests.BuildsNonDistributiveChannelOneAspirate;
begin
  AssertEquals('/1Iv900V6000P12000R',
    BuildDispenserMovementCommand(1, 1, 12000, 6000, True, True));
end;

procedure TDispenserProtocolTests.BuildsNonDistributiveChannelTwoDispense;
begin
  AssertEquals('/1Ov900V6000D12000R',
    BuildDispenserMovementCommand(1, 2, 12000, 6000, False, True));
end;

procedure TDispenserProtocolTests.BuildsDistributiveChannelCommand;
begin
  AssertEquals('/2I3v100V100P250R',
    BuildDispenserMovementCommand(2, 3, 250, 100, True, False));
end;

procedure TDispenserProtocolTests.RejectsUnsupportedNonDistributiveChannel;
begin
  AssertEquals('', BuildDispenserMovementCommand(1, 3, 250, 100, True, True));
  AssertEquals('', BuildDispenserMovementCommand(1, 0, 100, 10, True, True));
  AssertEquals('', BuildDispenserMovementCommand(1, 3, 100, 10, False, True));
end;

procedure TDispenserProtocolTests.MovementCommandCoversChannelAndDirectionEdges;
begin
  AssertEquals('/1I1v1V1P1R',
    BuildDispenserMovementCommand(1, 1, 1, 1, True, False));
  AssertEquals('/15O12v900V6000D12000R',
    BuildDispenserMovementCommand(15, 12, 12000, 6000, False, False));
end;

procedure TDispenserProtocolTests.MovementCommandStartSpeedFallsBackAboveLimit;
begin
  AssertEquals('/1I1v1000V1000P10R',
    BuildDispenserMovementCommand(1, 1, 10, 1000, True, False));
  AssertEquals('/1I1v900V1001P10R',
    BuildDispenserMovementCommand(1, 1, 10, 1001, True, False));
end;

procedure TDispenserProtocolTests.BuildsNonDistributiveBypassCommand;
begin
  AssertEquals('/1BR', BuildDispenserValveCommand(1, 2, True, True));
  AssertEquals('/2BR', BuildDispenserValveCommand(2, 0, True, True));
end;

procedure TDispenserProtocolTests.BuildsNonDistributiveRestoreCommand;
begin
  AssertEquals('/1OR', BuildDispenserValveCommand(1, 2, False, True));
end;

procedure TDispenserProtocolTests.RejectsDistributiveValveCommand;
begin
  AssertEquals('', BuildDispenserValveCommand(1, 1, True, False));
  AssertEquals('', BuildDispenserValveCommand(2, 1, True, False));
end;

procedure TDispenserProtocolTests.RejectsUnsupportedNonDistributiveValveChannel;
begin
  AssertEquals('', BuildDispenserValveCommand(1, 3, False, True));
  AssertEquals('', BuildDispenserValveCommand(2, 3, False, True));
end;

procedure TDispenserProtocolTests.ValveCommandCoversAllChannels;
begin
  AssertEquals('/2IR', BuildDispenserValveCommand(2, 1, False, True));
  AssertEquals('/2OR', BuildDispenserValveCommand(2, 2, False, True));
end;

procedure TDispenserProtocolTests.BuildsPlungerOnlyDispenseCommand;
begin
  AssertEquals('/1v900V4800D24000R',
    BuildDispenserPlungerCommand(1, 24000, 4800, False));
end;

procedure TDispenserProtocolTests.BuildsPlungerOnlyAspirateCommand;
begin
  AssertEquals('/2v750V750P1200R',
    BuildDispenserPlungerCommand(2, 1200, 750, True));
end;

procedure TDispenserProtocolTests.PlungerCommandStartSpeedFallsBackAboveLimit;
begin
  AssertEquals('/1v1000V1000P10R',
    BuildDispenserPlungerCommand(1, 10, 1000, True));
  AssertEquals('/1v900V1001P10R',
    BuildDispenserPlungerCommand(1, 10, 1001, True));
end;

procedure TDispenserProtocolTests.PlungerCommandRejectsInvalidArguments;
begin
  AssertEquals('', BuildDispenserPlungerCommand(0, 10, 100, True));
  AssertEquals('', BuildDispenserPlungerCommand(16, 10, 100, True));
  AssertEquals('', BuildDispenserPlungerCommand(1, 0, 100, True));
  AssertEquals('', BuildDispenserPlungerCommand(1, -1, 100, True));
  AssertEquals('', BuildDispenserPlungerCommand(1, 10, 0, True));
  AssertEquals('', BuildDispenserPlungerCommand(1, 10, 6001, True));
  AssertEquals('/15v900V6000D1R',
    BuildDispenserPlungerCommand(15, 1, 6000, False));
end;

procedure TDispenserProtocolTests.FormatResponseEscapesNonPrintableAndEmpty;
begin
  AssertEquals('<empty>', FormatResponseForLog(''));
  AssertEquals('/0`<03><0D><0A>', FormatResponseForLog('/0`' + #3#13#10));
  AssertEquals('<7F>', FormatResponseForLog(#$7F));
end;

procedure TDispenserProtocolTests.FormatResponseKeepsPrintableBoundaries;
begin
  AssertEquals('<1F> ~<7F><80><FF>',
    FormatResponseForLog(AnsiString(AnsiChar($1F)) + ' ~' +
      AnsiChar($7F) + AnsiChar($80) + AnsiChar($FF)));
end;

procedure TDispenserProtocolTests.ParseStatusResponseAcceptsValidFrame;
var
  StatusCode: Byte;
begin
  AssertTrue(ParseStatusResponse('/0' + #$60 + #3#13#10, StatusCode));
  AssertEquals($60, StatusCode);
  // Мусор перед началом кадра пропускается.
  AssertTrue(ParseStatusResponse('xx/0' + #$21 + #3#13#10, StatusCode));
  AssertEquals($21, StatusCode);
end;

procedure TDispenserProtocolTests.ParseStatusResponseAcceptsBoundaryStatusBytes;
var
  StatusCode: Byte;
begin
  AssertTrue(ParseStatusResponse('/0' + #0 + #3#13#10, StatusCode));
  AssertEquals(0, StatusCode);
  AssertTrue(ParseStatusResponse('/0' + AnsiChar($FF) + #3#13#10, StatusCode));
  AssertEquals($FF, StatusCode);
end;

procedure TDispenserProtocolTests.ParseStatusResponseRejectsMalformedFrames;
var
  StatusCode: Byte;

  procedure AssertRejected(const AResponse: AnsiString);
  begin
    StatusCode := 99;
    AssertFalse(ParseStatusResponse(AResponse, StatusCode));
    AssertEquals(0, StatusCode);
  end;

begin
  AssertRejected('');
  AssertRejected('no frame');
  AssertRejected('/0');
  AssertRejected('/1' + #$60 + #3#13#10);
  AssertRejected('/0' + #$60 + 'X' + #13#10);
  // Слишком короткий кадр без CRLF не принимается.
  AssertRejected('/0' + #$60 + #3);
  // Берётся первый '/', даже если он не начало кадра.
  AssertRejected('/x/0' + #$60 + #3#13#10);
end;

procedure TDispenserProtocolTests.ParseAsciiQueryResponseStripsStatusByte;
var
  Position: string;
begin
  AssertTrue(ParseAsciiQueryResponse('/0`1200' + #3#13#10, Position));
  AssertEquals('1200', Position);
  AssertTrue(ParseAsciiQueryResponse('/01200' + #3#13#10, Position));
  AssertEquals('1200', Position);
  AssertTrue(ParseAsciiQueryResponse('/0`12' + #3, Position));
  AssertEquals('12', Position);
end;

procedure TDispenserProtocolTests.ParseAsciiQueryResponseRejectsMalformedFrames;
var
  Position: string;
begin
  AssertFalse(ParseAsciiQueryResponse('', Position));
  AssertEquals('', Position);
  AssertFalse(ParseAsciiQueryResponse('/0', Position));
  AssertFalse(ParseAsciiQueryResponse('/11200' + #3, Position));
  AssertFalse(ParseAsciiQueryResponse('/01200', Position));
  AssertFalse(ParseAsciiQueryResponse('/0' + #3, Position));
  AssertFalse(ParseAsciiQueryResponse('/0`' + #3, Position));
end;

procedure TDispenserProtocolTests.ParseAsciiQueryResponseResetsPositionOnFailure;
var
  Position: string;
begin
  AssertTrue(ParseAsciiQueryResponse('/0`1200' + #3, Position));
  AssertEquals('1200', Position);
  AssertFalse(ParseAsciiQueryResponse('/1junk' + #3, Position));
  AssertEquals('', Position);
end;

procedure TDispenserProtocolTests.StatusDescriptionCoversReadyBusyAndErrors;
begin
  AssertEquals('готов', StatusDescription($20));
  AssertEquals('занят', StatusDescription(0));
  AssertEquals('готов, не инициализирован', StatusDescription($27));
  AssertEquals('занят, ошибка инициализации', StatusDescription(1));
  AssertEquals('готов, перегрузка плунжера', StatusDescription($29));
  AssertEquals('готов, код ошибки 4', StatusDescription($24));
end;

procedure TDispenserProtocolTests.StatusDescriptionCoversAllKnownErrorCodes;
begin
  AssertEquals('занят, неверная команда', StatusDescription(2));
  AssertEquals('занят, неверный параметр', StatusDescription(3));
  AssertEquals('занят, ошибка EEPROM', StatusDescription(6));
  AssertEquals('занят, перегрузка клапана', StatusDescription(10));
  AssertEquals('занят, перемещение плунжера запрещено', StatusDescription(11));
  AssertEquals('занят, внутренняя ошибка', StatusDescription(12));
  AssertEquals('занят, ошибка A/D-преобразователя', StatusDescription(14));
  AssertEquals('занят, переполнение команды', StatusDescription(15));
  AssertEquals('занят, код ошибки 5', StatusDescription(5));
  AssertEquals('занят, код ошибки 13', StatusDescription(13));
end;

procedure TDispenserProtocolTests.StatusDescriptionIgnoresUpperBits;
begin
  AssertEquals('готов', StatusDescription($F0));
  AssertEquals('занят', StatusDescription($D0));
end;

initialization
  RegisterTest(TDispenserProtocolTests);
end.
