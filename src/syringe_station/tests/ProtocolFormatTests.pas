unit ProtocolFormatTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ProtocolFormat;

type
  TProtocolFormatTests = class(TTestCase)
  published
    procedure ParsesAllOperationKinds;
    procedure RejectsOperationOutsideBlock;
    procedure RejectsSyringeParamWithoutSyrSt;
    procedure RejectsUnknownOperation;
    procedure ParamLinesRoundTrip;
    procedure AcceptsValidSyringeStep;
    procedure RejectsLongOrInvalidNames;
    procedure RejectsNonDigitNumbers;
    procedure RejectsBadSlashes;
    procedure RejectsMismatchedCounts;
    procedure RejectsDuplicateNames;
  end;

function MakeStep(const ANames, AValves, AVolumes, ASpeeds: string): TSyringeStep;
function StepError(const AStep: TSyringeStep): string;

implementation

const
  FULL_PROTOCOL =
    'Block=Condensation;' + LineEnding +
    #9'Comment=начало;' + LineEnding +
    #9'SyrSt;' + LineEnding +
    #9#9'Dispensers=A/Act;' + LineEnding +
    #9#9'Valves=2/3;' + LineEnding +
    #9#9'Volumes=100/50;' + LineEnding +
    #9#9'VolumeUnit=мкл;' + LineEnding +
    #9#9'Speeds=10;' + LineEnding +
    #9#9'SpeedUnit=мкл/с;' + LineEnding +
    #9'Pause=30;' + LineEnding +
    'Block=Wash;' + LineEnding +
    #9'Vacuum=1;' + LineEnding +
    #9'Laser=5; Time=3;' + LineEnding;

procedure TProtocolFormatTests.ParsesAllOperationKinds;
var
  Document: TProtocolDocument;
  ErrorText: string;
begin
  AssertTrue(ErrorText, ParseProtocolText(FULL_PROTOCOL, Document, ErrorText));
  AssertEquals(2, Length(Document));
  AssertEquals('Condensation', Document[0].Name);
  AssertEquals(3, Length(Document[0].Steps));
  AssertTrue(Document[0].Steps[0].Kind = pskComment);
  AssertEquals('начало', Document[0].Steps[0].Text);
  AssertTrue(Document[0].Steps[1].Kind = pskSyringe);
  AssertEquals(3, Document[0].Steps[1].LineNumber);
  AssertEquals('A/Act', Document[0].Steps[1].Syringe.Dispensers);
  AssertEquals('2/3', Document[0].Steps[1].Syringe.Valves);
  AssertEquals('100/50', Document[0].Steps[1].Syringe.Volumes);
  AssertEquals('мкл', Document[0].Steps[1].Syringe.VolumeUnit);
  AssertEquals('10', Document[0].Steps[1].Syringe.Speeds);
  AssertEquals('мкл/с', Document[0].Steps[1].Syringe.SpeedUnit);
  AssertTrue(Document[0].Steps[2].Kind = pskPause);
  AssertEquals(30, Document[0].Steps[2].IntValue);
  AssertEquals('Wash', Document[1].Name);
  AssertTrue(Document[1].Steps[0].Kind = pskVacuum);
  AssertTrue(Document[1].Steps[0].BoolValue);
  AssertTrue(Document[1].Steps[1].Kind = pskLaser);
  AssertEquals(5, Document[1].Steps[1].IntValue);
  AssertEquals(3.0, Document[1].Steps[1].FloatValue, 0.0001);
end;

procedure TProtocolFormatTests.RejectsOperationOutsideBlock;
var
  Document: TProtocolDocument;
  ErrorText: string;
begin
  AssertFalse(ParseProtocolText('Pause=5;', Document, ErrorText));
  AssertTrue(Pos('внутри блока', ErrorText) > 0);
end;

procedure TProtocolFormatTests.RejectsSyringeParamWithoutSyrSt;
var
  Document: TProtocolDocument;
  ErrorText: string;
begin
  AssertFalse(ParseProtocolText('Block=B;' + LineEnding + #9'Pause=5;' +
    LineEnding + #9#9'Volumes=10;', Document, ErrorText));
  AssertTrue(Pos('внутри операции SyrSt', ErrorText) > 0);
  AssertTrue(Pos('Строка 3', ErrorText) = 1);
end;

procedure TProtocolFormatTests.RejectsUnknownOperation;
var
  Document: TProtocolDocument;
  ErrorText: string;
begin
  AssertFalse(ParseProtocolText('Block=B;' + LineEnding + #9'Heat=90;',
    Document, ErrorText));
  AssertTrue(Pos('неизвестная операция', ErrorText) > 0);
end;

procedure TProtocolFormatTests.ParamLinesRoundTrip;
var
  Step: TSyringeStep;
  Lines: TStringArray;
  Text: string;
  Line: string;
  Document: TProtocolDocument;
  ErrorText: string;
begin
  Step.Dispensers := 'W';
  Step.Valves := '2';
  Step.Volumes := '250';
  Step.VolumeUnit := 'мкл';
  Step.Speeds := '20';
  Step.SpeedUnit := 'мкл/с';
  Lines := SyringeStepParamLines(Step);
  AssertEquals(6, Length(Lines));
  Text := 'Block=B;' + LineEnding + #9'SyrSt;' + LineEnding;
  for Line in Lines do
    Text := Text + #9#9 + Line + LineEnding;
  AssertTrue(ErrorText, ParseProtocolText(Text, Document, ErrorText));
  AssertEquals('W', Document[0].Steps[0].Syringe.Dispensers);
  AssertEquals('мкл/с', Document[0].Steps[0].Syringe.SpeedUnit);
end;

function MakeStep(const ANames, AValves, AVolumes, ASpeeds: string): TSyringeStep;
begin
  Result.Dispensers := ANames;
  Result.Valves := AValves;
  Result.Volumes := AVolumes;
  Result.VolumeUnit := 'мкл';
  Result.Speeds := ASpeeds;
  Result.SpeedUnit := 'мкл/с';
end;

// Текст ошибки проверки или '' если запись верна.
function StepError(const AStep: TSyringeStep): string;
begin
  if CheckSyringeStep(AStep, Result) then
    Result := '';
end;

procedure TProtocolFormatTests.AcceptsValidSyringeStep;
begin
  AssertEquals('', StepError(MakeStep('A', '2', '100', '10')));
  AssertEquals('', StepError(MakeStep('Act/A.1/W', '2', '100/50/25', '10')));
  AssertEquals('', StepError(MakeStep('P1/Ox', '2/3', '100', '10/20')));
end;

procedure TProtocolFormatTests.RejectsLongOrInvalidNames;
begin
  AssertTrue(Pos('длиннее 3', StepError(MakeStep('Wash', '2', '1', '1'))) > 0);
  AssertTrue(Pos('недопустимый символ " "',
    StepError(MakeStep('A B', '2', '1', '1'))) > 0);
  AssertTrue(Pos('недопустимый символ "-"',
    StepError(MakeStep('A-1', '2', '1', '1'))) > 0);
  AssertTrue(Pos('недопустимый символ ":"',
    StepError(MakeStep('A:Act', '2', '1', '1'))) > 0);
  // Только латиница: русская "А" запрещена, хотя выглядит как латинская.
  AssertTrue(Pos('недопустимый символ "А"',
    StepError(MakeStep('А1', '2', '1', '1'))) > 0);
  AssertTrue(Pos('латинские буквы',
    StepError(MakeStep('Д1', '2', '1', '1'))) > 0);
end;

procedure TProtocolFormatTests.RejectsNonDigitNumbers;
begin
  AssertTrue(Pos('только цифры', StepError(MakeStep('A', '2a', '1', '1'))) > 0);
  AssertTrue(Pos('только цифры', StepError(MakeStep('A', '2', '0,5', '1'))) > 0);
  AssertTrue(Pos('только цифры', StepError(MakeStep('A', '2', '1', '1.5'))) > 0);
  AssertTrue(Pos('только цифры', StepError(MakeStep('A', '2', '-1', '1'))) > 0);
  AssertTrue(Pos('больше нуля', StepError(MakeStep('A', '0', '1', '1'))) > 0);
end;

procedure TProtocolFormatTests.RejectsBadSlashes;
begin
  AssertTrue(Pos('подряд', StepError(MakeStep('A//B', '2', '1', '1'))) > 0);
  AssertTrue(Pos('начинаться или заканчиваться',
    StepError(MakeStep('/A', '2', '1', '1'))) > 0);
  AssertTrue(Pos('начинаться или заканчиваться',
    StepError(MakeStep('A/B', '2/', '1', '1'))) > 0);
  AssertTrue(Pos('не заполнено', StepError(MakeStep('A', '', '1', '1'))) > 0);
end;

procedure TProtocolFormatTests.RejectsMismatchedCounts;
begin
  // Три дозатора: в остальных полях 1 или 3 значения.
  AssertTrue(Pos('Дозаторов 3, а в поле «Клапаны» значений 2',
    StepError(MakeStep('A/B/C', '2/3', '1', '1'))) > 0);
  AssertTrue(Pos('«Объёмы»',
    StepError(MakeStep('A/B/C', '2', '1/2/3/4', '1'))) > 0);
  AssertTrue(Pos('«Скорости»',
    StepError(MakeStep('A/B/C', '2', '1', '1/2'))) > 0);
end;

procedure TProtocolFormatTests.RejectsDuplicateNames;
begin
  AssertTrue(Pos('несколько раз', StepError(MakeStep('A/a', '2', '1', '1'))) > 0);
end;

initialization
  RegisterTest(TProtocolFormatTests);

end.
