unit LaserTests;
// Тесты вспомогательной логики лазера: текст результатов MarkEzd.dll.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Lmc1Results;

type
  TLmc1ResultsTests = class(TTestCase)
  published
    procedure TextStartsWithFunctionAndCode;
    procedure KnownAndUnknownCodesDiffer;
    procedure EveryDocumentedCodeHasOwnText;
  end;

implementation

procedure TLmc1ResultsTests.TextStartsWithFunctionAndCode;
begin
  AssertEquals(1, Pos('lmc1_Initial2 -> 0 ', Lmc1ResultText('lmc1_Initial2', 0)));
  AssertEquals(1, Pos('lmc1_Close -> 4 ', Lmc1ResultText('lmc1_Close', 4)));
  AssertEquals(1, Pos('f -> -1 ', Lmc1ResultText('f', -1)));
end;

procedure TLmc1ResultsTests.KnownAndUnknownCodesDiffer;
begin
  AssertTrue(Lmc1ResultText('f', 99) = Lmc1ResultText('f', 20) .Replace(' 20 ', ' 99 '));
  AssertFalse(Lmc1ResultText('f', 0) = Lmc1ResultText('f', 99).Replace(' 99 ', ' 0 '));
end;

procedure TLmc1ResultsTests.EveryDocumentedCodeHasOwnText;
var
  Texts: TStringList;
  Code: Integer;
  Text: string;
begin
  Texts := TStringList.Create;
  try
    for Code := 0 to 21 do
    begin
      if Code = 20 then
        Continue; // кода 20 нет в документации SDK
      Text := Lmc1ResultText('f', Code);
      Text := Copy(Text, Pos(' ', Copy(Text, 6, MaxInt)) + 6, MaxInt);
      AssertEquals('код ' + IntToStr(Code), -1, Texts.IndexOf(Text));
      Texts.Add(Text);
    end;
  finally
    Texts.Free;
  end;
end;

initialization
  RegisterTest(TLmc1ResultsTests);

end.
