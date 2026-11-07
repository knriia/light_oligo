unit TextFileUtils;
// Чтение и запись текстовых файлов в UTF-8 целиком.
// При чтении BOM UTF-8 отбрасывается; ошибки возвращаются текстом.

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function ReadUtf8TextFile(const AFileName: string;
  out AContent: UTF8String; out AErrorText: string): Boolean;
function WriteUtf8TextFile(const AFileName: string;
  const AContent: UTF8String; out AErrorText: string): Boolean;

implementation

uses
  Classes;

function ReadUtf8TextFile(const AFileName: string;
  out AContent: UTF8String; out AErrorText: string): Boolean;
var
  Stream: TFileStream;
  Utf8Content: UTF8String;
begin
  Result := False;
  AContent := '';
  AErrorText := '';
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size > High(Integer) then
        raise EStreamError.Create('Файл слишком большой.');
      SetLength(Utf8Content, Integer(Stream.Size));
      if Length(Utf8Content) > 0 then
        Stream.ReadBuffer(Utf8Content[1], Length(Utf8Content));
    finally
      Stream.Free;
    end;

    if (Length(Utf8Content) >= 3) and (Utf8Content[1] = #$EF) and
      (Utf8Content[2] = #$BB) and (Utf8Content[3] = #$BF) then
      Delete(Utf8Content, 1, 3);
    AContent := Utf8Content;
    Result := True;
  except
    on E: Exception do
      AErrorText := E.Message;
  end;
end;

function WriteUtf8TextFile(const AFileName: string;
  const AContent: UTF8String; out AErrorText: string): Boolean;
var
  Stream: TFileStream;
  Utf8Content: UTF8String;
begin
  Result := False;
  AErrorText := '';
  try
    Utf8Content := AContent;
    Stream := TFileStream.Create(AFileName, fmCreate);
    try
      if Length(Utf8Content) > 0 then
        Stream.WriteBuffer(Utf8Content[1], Length(Utf8Content));
    finally
      Stream.Free;
    end;
    Result := True;
  except
    on E: Exception do
      AErrorText := E.Message;
  end;
end;

end.
