unit IniNumbers;
// Дробные числа в ini-файлах настроек: пишутся с точкой независимо от
// региональных настроек Windows, читаются и с точкой, и с запятой.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, IniFiles;

// Нет ключа или не число - ADefault.
function ReadIniFloat(AIni: TCustomIniFile; const ASection, AKey: string;
  ADefault: Double): Double;
procedure WriteIniFloat(AIni: TCustomIniFile; const ASection, AKey: string;
  AValue: Double);

implementation

function PointFormat: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function ReadIniFloat(AIni: TCustomIniFile; const ASection, AKey: string;
  ADefault: Double): Double;
var
  Text: string;
begin
  Text := StringReplace(Trim(AIni.ReadString(ASection, AKey, '')), ',', '.', []);
  if not TryStrToFloat(Text, Result, PointFormat) then
    Result := ADefault;
end;

procedure WriteIniFloat(AIni: TCustomIniFile; const ASection, AKey: string;
  AValue: Double);
begin
  AIni.WriteString(ASection, AKey, FloatToStr(AValue, PointFormat));
end;

end.
