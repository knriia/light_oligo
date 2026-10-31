unit ProtocolFormat;
// Формат файла протокола синтеза (.pro).
//
// Протокол состоит из блоков, в блоке идут операции, у операции SyrSt
// параметры записаны вложенными строками. Отступы - табуляция, как их
// сохраняет дерево протокола:
//
//   Block=Condensation;
//   	SyrSt;
//   		Dispensers=A/Act;
//   		Valves=2/2;
//   		Volumes=100/100;
//   		VolumeUnit=мкл;
//   		Speeds=10/10;
//   		SpeedUnit=мкл/с;
//   	Pause=30;
//   	Vacuum=1;
//   	Laser=5; Time=3;
//   	Comment=текст;
//
// В списках SyrSt значения разделяются "/": одно значение на дозатор
// или одно общее для всех.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  KEY_BLOCK = 'Block';
  KEY_SYRINGE = 'SyrSt';
  KEY_PAUSE = 'Pause';
  KEY_VACUUM = 'Vacuum';
  KEY_LASER = 'Laser';
  KEY_LASER_TIME = 'Time';
  KEY_COMMENT = 'Comment';

  KEY_DISPENSERS = 'Dispensers';
  KEY_VALVES = 'Valves';
  KEY_VOLUMES = 'Volumes';
  KEY_VOLUME_UNIT = 'VolumeUnit';
  KEY_SPEEDS = 'Speeds';
  KEY_SPEED_UNIT = 'SpeedUnit';

  MAX_DISPENSER_NAME_LENGTH = 3;

  VOLUME_UNITS: array[0..2] of string = ('нл', 'мкл', 'мл');
  SPEED_UNITS: array[0..2] of string = ('нл/с', 'мкл/с', 'мл/с');

type
  // Параметры подачи из шприцевой станции, как они записаны в протоколе.
  TSyringeStep = record
    Dispensers: string; // имена дозаторов через /
    Valves: string;     // каналы клапанов через /
    Volumes: string;    // объёмы через /
    VolumeUnit: string; // нл, мкл, мл
    Speeds: string;     // скорости через /
    SpeedUnit: string;  // нл/с, мкл/с, мл/с
  end;

  TProtocolStepKind = (pskComment, pskSyringe, pskVacuum, pskLaser, pskPause);

  TProtocolStep = record
    Kind: TProtocolStepKind;
    LineNumber: Integer;   // строка файла, где начинается операция
    Text: string;          // текст комментария
    IntValue: Integer;     // пауза, с; число повторов лазера
    FloatValue: Double;    // время лазера, с
    BoolValue: Boolean;    // вакуум вкл/выкл
    Syringe: TSyringeStep;
  end;

  TProtocolBlock = record
    Name: string;
    LineNumber: Integer;
    Steps: array of TProtocolStep;
  end;

  TProtocolDocument = array of TProtocolBlock;

// Разбор текста протокола. При ошибке ErrorText начинается с номера строки.
function ParseProtocolText(const AText: string; out ADocument: TProtocolDocument;
  out ErrorText: string): Boolean;

// Списки значений через "/" (пустые элементы недопустимы).
function SplitSlashValues(const AText: string; AValues: TStrings): Boolean;
function VolumeUnitScale(const AUnit: string; out AScale: Int64): Boolean;
function SpeedUnitScale(const AUnit: string; out AScale: Int64): Boolean;

// Проверка записи SyrSt без привязки к конфигурации станции:
//  - имена дозаторов: латинские буквы, цифры, точка, не длиннее 3 символов, без повторов;
//  - клапаны, объёмы, скорости: целые числа больше нуля;
//  - значения через "/", без "//" и без "/" в начале или конце;
//  - в каждом поле одно значение на всех или по одному на каждый дозатор;
//  - единицы объёма и скорости из списка.
function CheckSyringeStep(const AStep: TSyringeStep;
  out ErrorText: string): Boolean;

// Проверка одного имени дозатора (общая для протокола и конфигуратора):
// не пустое, до MAX_DISPENSER_NAME_LENGTH символов, только латинские буквы,
// цифры и точка.
function CheckDispenserName(const AName: string; out ErrorText: string): Boolean;

// Строки параметров SyrSt для дерева протокола (без отступов).
function SyringeStepParamLines(const AStep: TSyringeStep): TStringArray;
// Короткое описание SyrSt для журнала.
function SyringeStepSummary(const AStep: TSyringeStep): string;

implementation

uses
  StrUtils;

function SplitSlashValues(const AText: string; AValues: TStrings): Boolean;
var
  StartAt: Integer;
  SlashAt: Integer;
  ValueText: string;
begin
  AValues.Clear;
  StartAt := 1;
  repeat
    SlashAt := PosEx('/', AText, StartAt);
    if SlashAt = 0 then
      ValueText := Copy(AText, StartAt, MaxInt)
    else
      ValueText := Copy(AText, StartAt, SlashAt - StartAt);
    ValueText := Trim(ValueText);
    if ValueText = '' then
      Exit(False);
    AValues.Add(ValueText);
    if SlashAt = 0 then
      Break;
    StartAt := SlashAt + 1;
  until False;
  Result := AValues.Count > 0;
end;

function VolumeUnitScale(const AUnit: string; out AScale: Int64): Boolean;
begin
  AScale := 0;
  if SameText(Trim(AUnit), 'нл') then
    AScale := 1
  else if SameText(Trim(AUnit), 'мкл') then
    AScale := 1000
  else if SameText(Trim(AUnit), 'мл') then
    AScale := 1000000;
  Result := AScale > 0;
end;

function SpeedUnitScale(const AUnit: string; out AScale: Int64): Boolean;
begin
  AScale := 0;
  if SameText(Trim(AUnit), 'нл/с') then
    AScale := 1
  else if SameText(Trim(AUnit), 'мкл/с') then
    AScale := 1000
  else if SameText(Trim(AUnit), 'мл/с') then
    AScale := 1000000;
  Result := AScale > 0;
end;

// UTF-8 байты в обычной string без перекодировки. Результат UTF8Encode при
// склейке с string конвертируется в системную кодовую страницу и портит
// кириллицу, если она не UTF-8 (консольные тесты).
function Utf8Text(const AText: UnicodeString): string;
var
  Bytes: RawByteString;
begin
  Bytes := UTF8Encode(AText);
  SetCodePage(Bytes, DefaultSystemCodePage, False);
  Result := Bytes;
end;

// Только латинские буквы, цифры и точка.
function IsNameChar(C: UnicodeChar): Boolean;
begin
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
    ((C >= '0') and (C <= '9')) or (C = '.');
end;

function CheckDispenserName(const AName: string; out ErrorText: string): Boolean;
var
  Name: UnicodeString;
  I: Integer;
begin
  Result := False;
  ErrorText := '';
  Name := UTF8Decode(AName);
  if Name = '' then
  begin
    ErrorText := 'Имя дозатора не задано.';
    Exit;
  end;
  for I := 1 to Length(Name) do
    if not IsNameChar(Name[I]) then
    begin
      ErrorText := 'В имени дозатора "' + AName + '" допустимы только латинские буквы, ' +
        'цифры и точка (недопустимый символ "' +
        Utf8Text(UnicodeString(Name[I])) + '").';
      Exit;
    end;
  if Length(Name) > MAX_DISPENSER_NAME_LENGTH then
  begin
    ErrorText := 'Имя дозатора "' + AName + '" длиннее ' +
      IntToStr(MAX_DISPENSER_NAME_LENGTH) + ' символов.';
    Exit;
  end;
  Result := True;
end;

type
  TListFieldKind = (lfkNames, lfkNumbers);

// Проверяет список значений через "/":
//  - не пустой, не начинается и не заканчивается "/", нет "//";
//  - имена: латинские буквы, цифры и точка, не длиннее MAX_DISPENSER_NAME_LENGTH;
//  - числа: только цифры, значение больше нуля.
function CheckListField(const AText, ACaption: string; AKind: TListFieldKind;
  AValues: TStrings; out ErrorText: string): Boolean;
var
  Text: UnicodeString;
  Value: UnicodeString;
  C: UnicodeChar;
  I: Integer;
  Number: Int64;
begin
  Result := False;
  ErrorText := '';
  AValues.Clear;
  Text := UTF8Decode(AText);
  if Text = '' then
  begin
    ErrorText := 'Поле «' + ACaption + '» не заполнено.';
    Exit;
  end;
  if (Text[1] = '/') or (Text[Length(Text)] = '/') then
  begin
    ErrorText := 'Поле «' + ACaption + '» не может начинаться или заканчиваться символом "/".';
    Exit;
  end;
  if Pos(UnicodeString('//'), Text) > 0 then
  begin
    ErrorText := 'В поле «' + ACaption + '» два символа "/" подряд.';
    Exit;
  end;

  for I := 1 to Length(Text) do
  begin
    C := Text[I];
    if C = '/' then
      Continue;
    if (AKind = lfkNumbers) and not ((C >= '0') and (C <= '9')) then
    begin
      ErrorText := 'В поле «' + ACaption + '» допустимы только цифры и "/" ' +
        '(недопустимый символ "' + Utf8Text(UnicodeString(C)) + '").';
      Exit;
    end;
    if (AKind = lfkNames) and not IsNameChar(C) then
    begin
      ErrorText := 'В поле «' + ACaption + '» допустимы только латинские буквы, цифры, ' +
        'точка и "/" (недопустимый символ "' + Utf8Text(UnicodeString(C)) + '").';
      Exit;
    end;
  end;

  // Пустых элементов здесь уже нет: "//" и "/" по краям отсеяны выше.
  Text := Text + '/';
  Value := '';
  for I := 1 to Length(Text) do
  begin
    if Text[I] <> '/' then
    begin
      Value := Value + Text[I];
      Continue;
    end;
    if (AKind = lfkNames) and not CheckDispenserName(Utf8Text(Value), ErrorText) then
      Exit;
    if (AKind = lfkNumbers) and
      (not TryStrToInt64(Utf8Text(Value), Number) or (Number <= 0)) then
    begin
      ErrorText := 'В поле «' + ACaption + '» значение "' + Utf8Text(Value) +
        '" должно быть целым числом больше нуля.';
      Exit;
    end;
    AValues.Add(Utf8Text(Value));
    Value := '';
  end;
  Result := True;
end;

function CheckSyringeStep(const AStep: TSyringeStep;
  out ErrorText: string): Boolean;
var
  Names, Valves, Volumes, Speeds: TStringList;
  Scale: Int64;
  I, J: Integer;

  function CountMatches(AList: TStrings; const ACaption: string): Boolean;
  begin
    Result := (AList.Count = 1) or (AList.Count = Names.Count);
    if not Result then
      ErrorText := Format('Дозаторов %d, а в поле «%s» значений %d. ' +
        'Укажите одно значение для всех дозаторов или %d значений через "/".',
        [Names.Count, ACaption, AList.Count, Names.Count]);
  end;

begin
  Result := False;
  ErrorText := '';
  Names := TStringList.Create;
  Valves := TStringList.Create;
  Volumes := TStringList.Create;
  Speeds := TStringList.Create;
  try
    if not CheckListField(AStep.Dispensers, 'Дозаторы', lfkNames, Names,
        ErrorText) or
      not CheckListField(AStep.Valves, 'Клапаны', lfkNumbers, Valves,
        ErrorText) or
      not CheckListField(AStep.Volumes, 'Объёмы', lfkNumbers, Volumes,
        ErrorText) or
      not CheckListField(AStep.Speeds, 'Скорости', lfkNumbers, Speeds,
        ErrorText) then
      Exit;

    for I := 1 to Names.Count - 1 do
      for J := 0 to I - 1 do
        if SameText(Names[I], Names[J]) then
        begin
          ErrorText := 'Дозатор "' + Names[I] + '" указан несколько раз.';
          Exit;
        end;

    if not CountMatches(Valves, 'Клапаны') or
      not CountMatches(Volumes, 'Объёмы') or
      not CountMatches(Speeds, 'Скорости') then
      Exit;
    if not VolumeUnitScale(AStep.VolumeUnit, Scale) then
    begin
      ErrorText := 'Неизвестная единица объёма: "' + AStep.VolumeUnit + '".';
      Exit;
    end;
    if not SpeedUnitScale(AStep.SpeedUnit, Scale) then
    begin
      ErrorText := 'Неизвестная единица скорости: "' + AStep.SpeedUnit + '".';
      Exit;
    end;
    Result := True;
  finally
    Speeds.Free;
    Volumes.Free;
    Valves.Free;
    Names.Free;
  end;
end;

function SyringeStepParamLines(const AStep: TSyringeStep): TStringArray;
begin
  Result := nil;
  SetLength(Result, 6);
  Result[0] := KEY_DISPENSERS + '=' + AStep.Dispensers + ';';
  Result[1] := KEY_VALVES + '=' + AStep.Valves + ';';
  Result[2] := KEY_VOLUMES + '=' + AStep.Volumes + ';';
  Result[3] := KEY_VOLUME_UNIT + '=' + AStep.VolumeUnit + ';';
  Result[4] := KEY_SPEEDS + '=' + AStep.Speeds + ';';
  Result[5] := KEY_SPEED_UNIT + '=' + AStep.SpeedUnit + ';';
end;

function SyringeStepSummary(const AStep: TSyringeStep): string;
begin
  Result := KEY_SYRINGE + ': ' + AStep.Dispensers +
    '; клапаны ' + AStep.Valves +
    '; объём ' + AStep.Volumes + ' ' + AStep.VolumeUnit +
    '; скорость ' + AStep.Speeds + ' ' + AStep.SpeedUnit;
end;

function IsSyringeParamKey(const AKey: string): Boolean;
begin
  Result := SameText(AKey, KEY_DISPENSERS) or SameText(AKey, KEY_VALVES) or
    SameText(AKey, KEY_VOLUMES) or SameText(AKey, KEY_VOLUME_UNIT) or
    SameText(AKey, KEY_SPEEDS) or SameText(AKey, KEY_SPEED_UNIT);
end;

// Делит строку "Key=Value; Key2=Value2;" на пары. Ключ без "=" допустим
// (например, "SyrSt;"), его значение пустое.
procedure SplitLineFields(const ALine: string; AKeys, AValues: TStrings);
var
  Parts: TStringArray;
  Part: string;
  EqAt: Integer;
begin
  AKeys.Clear;
  AValues.Clear;
  Parts := ALine.Split(';');
  for Part in Parts do
  begin
    if Trim(Part) = '' then
      Continue;
    EqAt := Pos('=', Part);
    if EqAt = 0 then
    begin
      AKeys.Add(Trim(Part));
      AValues.Add('');
    end
    else
    begin
      AKeys.Add(Trim(Copy(Part, 1, EqAt - 1)));
      AValues.Add(Trim(Copy(Part, EqAt + 1, MaxInt)));
    end;
  end;
end;

function ParseProtocolText(const AText: string; out ADocument: TProtocolDocument;
  out ErrorText: string): Boolean;
var
  Lines, Keys, Values: TStringList;
  LineIndex: Integer;
  Key, Value: string;
  Step: TProtocolStep;
  BlockIndex: Integer;
  Missing: string;
  CheckError: string;
  Seen: TStringList;

  function Fail(const AMessage: string): Boolean;
  begin
    ErrorText := 'Строка ' + IntToStr(LineIndex + 1) + ': ' + AMessage;
    Result := False;
  end;

  procedure AddStep(const AStep: TProtocolStep);
  begin
    SetLength(ADocument[BlockIndex].Steps,
      Length(ADocument[BlockIndex].Steps) + 1);
    ADocument[BlockIndex].Steps[High(ADocument[BlockIndex].Steps)] := AStep;
  end;

  // Проверяет, что у последней операции SyrSt заданы все параметры.
  function FinishSyringeStep: Boolean;
  var
    Last: TProtocolStep;
  begin
    Result := True;
    if (BlockIndex < 0) or (Length(ADocument[BlockIndex].Steps) = 0) then
      Exit;
    Last := ADocument[BlockIndex].Steps[High(ADocument[BlockIndex].Steps)];
    if Last.Kind <> pskSyringe then
      Exit;
    Missing := '';
    if Seen.IndexOf(KEY_DISPENSERS) < 0 then Missing := Missing + ' ' + KEY_DISPENSERS;
    if Seen.IndexOf(KEY_VALVES) < 0 then Missing := Missing + ' ' + KEY_VALVES;
    if Seen.IndexOf(KEY_VOLUMES) < 0 then Missing := Missing + ' ' + KEY_VOLUMES;
    if Seen.IndexOf(KEY_VOLUME_UNIT) < 0 then Missing := Missing + ' ' + KEY_VOLUME_UNIT;
    if Seen.IndexOf(KEY_SPEEDS) < 0 then Missing := Missing + ' ' + KEY_SPEEDS;
    if Seen.IndexOf(KEY_SPEED_UNIT) < 0 then Missing := Missing + ' ' + KEY_SPEED_UNIT;
    if Missing <> '' then
    begin
      ErrorText := 'Строка ' + IntToStr(Last.LineNumber) +
        ': у операции SyrSt не заданы параметры:' + Missing + '.';
      Exit(False);
    end;
    if not CheckSyringeStep(Last.Syringe, CheckError) then
    begin
      ErrorText := 'Строка ' + IntToStr(Last.LineNumber) + ': SyrSt: ' +
        CheckError;
      Exit(False);
    end;
  end;

  // Записывает параметр в последнюю операцию SyrSt.
  function SetSyringeParam(const AKey, AValue: string): Boolean;
  var
    Last: Integer;
  begin
    Result := False;
    if (BlockIndex < 0) or (Length(ADocument[BlockIndex].Steps) = 0) or
      (ADocument[BlockIndex].Steps[High(ADocument[BlockIndex].Steps)].Kind <>
        pskSyringe) then
      Exit(Fail('параметр "' + AKey + '" должен идти внутри операции SyrSt.'));
    if Seen.IndexOf(AKey) >= 0 then
      Exit(Fail('параметр "' + AKey + '" повторяется в операции SyrSt.'));
    Seen.Add(AKey);
    Last := High(ADocument[BlockIndex].Steps);
    with ADocument[BlockIndex].Steps[Last].Syringe do
      if SameText(AKey, KEY_DISPENSERS) then Dispensers := AValue
      else if SameText(AKey, KEY_VALVES) then Valves := AValue
      else if SameText(AKey, KEY_VOLUMES) then Volumes := AValue
      else if SameText(AKey, KEY_VOLUME_UNIT) then VolumeUnit := AValue
      else if SameText(AKey, KEY_SPEEDS) then Speeds := AValue
      else if SameText(AKey, KEY_SPEED_UNIT) then SpeedUnit := AValue;
    Result := True;
  end;

begin
  Result := False;
  ErrorText := '';
  ADocument := nil;
  BlockIndex := -1;
  Lines := TStringList.Create;
  Keys := TStringList.Create;
  Values := TStringList.Create;
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    Lines.Text := AText;
    for LineIndex := 0 to Lines.Count - 1 do
    begin
      SplitLineFields(Lines[LineIndex], Keys, Values);
      if Keys.Count = 0 then
        Continue;
      Key := Keys[0];
      Value := Values[0];

      // Параметры SyrSt относятся к последней операции.
      if IsSyringeParamKey(Key) then
      begin
        if Keys.Count > 1 then
          Exit(Fail('параметры SyrSt записываются по одному в строке.'));
        if not SetSyringeParam(Key, Value) then
          Exit;
        Continue;
      end;

      // Любая другая строка завершает предыдущую операцию SyrSt.
      if not FinishSyringeStep then
        Exit;
      Seen.Clear;

      if SameText(Key, KEY_BLOCK) then
      begin
        if Value = '' then
          Exit(Fail('у блока не задано имя.'));
        SetLength(ADocument, Length(ADocument) + 1);
        BlockIndex := High(ADocument);
        ADocument[BlockIndex].Name := Value;
        ADocument[BlockIndex].LineNumber := LineIndex + 1;
        ADocument[BlockIndex].Steps := nil;
        Continue;
      end;

      if BlockIndex < 0 then
        Exit(Fail('операция "' + Key + '" должна находиться внутри блока (Block=...).'));

      Step := Default(TProtocolStep);
      Step.LineNumber := LineIndex + 1;
      if SameText(Key, KEY_SYRINGE) then
      begin
        if (Value <> '') or (Keys.Count > 1) then
          Exit(Fail('устаревшая запись SyrSt. Параметры дозаторов задаются ' +
            'вложенными строками Dispensers, Valves, Volumes, VolumeUnit, ' +
            'Speeds, SpeedUnit.'));
        Step.Kind := pskSyringe;
      end
      else if SameText(Key, KEY_PAUSE) then
      begin
        Step.Kind := pskPause;
        if not TryStrToInt(Value, Step.IntValue) or (Step.IntValue < 0) then
          Exit(Fail('пауза должна быть целым числом секунд.'));
      end
      else if SameText(Key, KEY_VACUUM) then
      begin
        Step.Kind := pskVacuum;
        if not TryStrToBool(Value, Step.BoolValue) then
          Exit(Fail('значение вакуума должно быть 0 или 1.'));
      end
      else if SameText(Key, KEY_LASER) then
      begin
        Step.Kind := pskLaser;
        if not TryStrToInt(Value, Step.IntValue) then
          Exit(Fail('число повторов лазера должно быть целым.'));
        if (Keys.Count < 2) or not SameText(Keys[1], KEY_LASER_TIME) or
          not TryStrToFloat(Values[1], Step.FloatValue) then
          Exit(Fail('для лазера нужно время: Laser=N; Time=T;'));
      end
      else if SameText(Key, KEY_COMMENT) then
      begin
        Step.Kind := pskComment;
        Step.Text := Value;
      end
      else
        Exit(Fail('неизвестная операция "' + Key + '".'));
      AddStep(Step);
    end;

    LineIndex := Lines.Count;
    if not FinishSyringeStep then
      Exit;
    Result := True;
  finally
    Seen.Free;
    Values.Free;
    Keys.Free;
    Lines.Free;
  end;
end;

end.
