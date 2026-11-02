unit OligoArrayCsv;
// Массив олигов в CSV: строка файла - строка массива, ячейки через ";".
// Буквы при чтении переводятся в верхний регистр, пустые строки пропускаются.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoArray;

const
  OLIGO_CSV_SEPARATOR = ';';

function ParseOligoCsv(const aText: String): TOligoArr;
function FormatOligoCsv(const aArr: TOligoArr): String;

function LoadOligoArrayFile(const aFileName: String; out aArr: TOligoArr;
  out aErrorText: String): Boolean;
function SaveOligoArrayFile(const aFileName: String; const aArr: TOligoArr;
  out aErrorText: String): Boolean;

implementation

uses
  TextFileUtils;

function ParseOligoCsv(const aText: String): TOligoArr;
var
  Lines: TStringList;
  Parts: TStringArray;
  i,j,Row: integer;
begin
  Result:=nil;
  Lines:=TStringList.Create;
  try
    Lines.Text:=aText;
    for i:=0 to Lines.Count-1 do
    begin
      if Lines[i]='' then
        Continue;
      Parts:=Lines[i].Split(OLIGO_CSV_SEPARATOR);
      Row:=Length(Result);
      SetLength(Result, Row+1);
      SetLength(Result[Row], Length(Parts));
      for j:=0 to High(Parts) do
        Result[Row,j]:=StringToOlig(Parts[j]);
    end;
  finally
    Lines.Free;
  end;
end;

function FormatOligoCsv(const aArr: TOligoArr): String;
var
  Lines: TStringList;
  i: integer;
begin
  Lines:=TStringList.Create;
  try
    for i:=0 to High(aArr) do
      Lines.Add(String.Join(OLIGO_CSV_SEPARATOR, aArr[i]));
    Result:=Lines.Text;
  finally
    Lines.Free;
  end;
end;

function LoadOligoArrayFile(const aFileName: String; out aArr: TOligoArr;
  out aErrorText: String): Boolean;
var
  Text: UTF8String;
begin
  aArr:=nil;
  Result:=ReadUtf8TextFile(aFileName, Text, aErrorText);
  if Result then
    aArr:=ParseOligoCsv(Text);
end;

function SaveOligoArrayFile(const aFileName: String; const aArr: TOligoArr;
  out aErrorText: String): Boolean;
begin
  Result:=WriteUtf8TextFile(aFileName, FormatOligoCsv(aArr), aErrorText);
end;

end.
