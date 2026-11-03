unit ScenarioList;
// Сценарии шприцевой станции: список из сценариев (команда подачи SyrSt)
// и задержек (Pause) между ними.
//
// Поля сценария и их проверка те же, что у операции SyrSt в протоколе
// синтеза (ProtocolFormat). Файл сценариев - это протокол из одного блока,
// в котором есть только SyrSt и Pause:
//
//   Block=Scenario;
//   	SyrSt;
//   		Dispensers=A/Act;
//   		Valves=2/2;
//   		Volumes=100/100;
//   		VolumeUnit=мкл;
//   		Speeds=10/10;
//   		SpeedUnit=мкл/с;
//   	Pause=30;
//
// Поэтому такой файл читает и станция, и протокол синтеза.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat;

const
  SCENARIO_BLOCK_NAME = 'Scenario'; // имя единственного блока в файле
  SCENARIO_FILE_EXT = '.scn';

type
  TScenarioItemKind = (sikScenario, sikDelay);

  TScenarioItem = record
    Kind: TScenarioItemKind;
    Syringe: TSyringeStep;  // параметры подачи (для сценария)
    DelaySeconds: Integer;  // пауза, с (для задержки)
  end;

  TScenarioList = class
  private
    FItems: array of TScenarioItem;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TScenarioItem;
    procedure CheckIndex(AIndex, AMax: Integer);
  public
    // Индекс вне списка - ошибка программы, поднимается EListError.
    function Add(const AItem: TScenarioItem): Integer;
    procedure Insert(AIndex: Integer; const AItem: TScenarioItem);
    procedure Replace(AIndex: Integer; const AItem: TScenarioItem);
    procedure Delete(AIndex: Integer);
    // Переносит элемент на новое место, остальные сдвигаются.
    procedure Move(AFromIndex, AToIndex: Integer);
    procedure Clear;
    procedure Assign(AOther: TScenarioList);
    // Сколько в списке сценариев (задержки не считаются).
    function ScenarioCount: Integer;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TScenarioItem read GetItem; default;
  end;

function MakeScenario(const ASyringe: TSyringeStep): TScenarioItem;
function MakeDelay(ASeconds: Integer): TScenarioItem;

// Проверка элемента: сценарий - как операция SyrSt, задержка - целое число
// секунд не меньше нуля. При ошибке текст объясняет, что не так.
function CheckScenarioItem(const AItem: TScenarioItem;
  out AErrorText: string): Boolean;
// Короткое описание для списка на экране и журнала.
function ScenarioItemSummary(const AItem: TScenarioItem): string;

// Текст файла сценариев (формат выше).
function ScenarioListToText(AList: TScenarioList): string;
// Разбор текста. Пустой текст - пустой список. При ошибке список не
// меняется, а текст ошибки начинается с номера строки.
function ParseScenarioText(const AText: string; AList: TScenarioList;
  out AErrorText: string): Boolean;

// Чтение и запись файла. Запись сначала проверяет все элементы.
function LoadScenarioFile(const AFileName: string; AList: TScenarioList;
  out AErrorText: string): Boolean;
function SaveScenarioFile(const AFileName: string; AList: TScenarioList;
  out AErrorText: string): Boolean;

implementation

uses
  TextFileUtils;

function TScenarioList.GetCount: Integer;
begin
  Result := Length(FItems);
end;

function TScenarioList.GetItem(AIndex: Integer): TScenarioItem;
begin
  CheckIndex(AIndex, High(FItems));
  Result := FItems[AIndex];
end;

procedure TScenarioList.CheckIndex(AIndex, AMax: Integer);
begin
  if (AIndex < 0) or (AIndex > AMax) then
    raise EListError.CreateFmt('Scenario index %d is out of range 0..%d',
      [AIndex, AMax]);
end;

function TScenarioList.Add(const AItem: TScenarioItem): Integer;
begin
  SetLength(FItems, Length(FItems) + 1);
  Result := High(FItems);
  FItems[Result] := AItem;
end;

procedure TScenarioList.Insert(AIndex: Integer; const AItem: TScenarioItem);
var
  I: Integer;
begin
  CheckIndex(AIndex, Length(FItems)); // можно и в конец
  SetLength(FItems, Length(FItems) + 1);
  for I := High(FItems) downto AIndex + 1 do
    FItems[I] := FItems[I - 1];
  FItems[AIndex] := AItem;
end;

procedure TScenarioList.Replace(AIndex: Integer; const AItem: TScenarioItem);
begin
  CheckIndex(AIndex, High(FItems));
  FItems[AIndex] := AItem;
end;

procedure TScenarioList.Delete(AIndex: Integer);
var
  I: Integer;
begin
  CheckIndex(AIndex, High(FItems));
  for I := AIndex to High(FItems) - 1 do
    FItems[I] := FItems[I + 1];
  SetLength(FItems, Length(FItems) - 1);
end;

procedure TScenarioList.Move(AFromIndex, AToIndex: Integer);
var
  Item: TScenarioItem;
  I: Integer;
begin
  CheckIndex(AFromIndex, High(FItems));
  CheckIndex(AToIndex, High(FItems));
  Item := FItems[AFromIndex];
  if AFromIndex < AToIndex then
    for I := AFromIndex to AToIndex - 1 do
      FItems[I] := FItems[I + 1]
  else
    for I := AFromIndex downto AToIndex + 1 do
      FItems[I] := FItems[I - 1];
  FItems[AToIndex] := Item;
end;

procedure TScenarioList.Clear;
begin
  FItems := nil;
end;

procedure TScenarioList.Assign(AOther: TScenarioList);
begin
  FItems := Copy(AOther.FItems);
end;

function TScenarioList.ScenarioCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do
    if FItems[I].Kind = sikScenario then
      Inc(Result);
end;

function MakeScenario(const ASyringe: TSyringeStep): TScenarioItem;
begin
  Result := Default(TScenarioItem);
  Result.Kind := sikScenario;
  Result.Syringe := ASyringe;
end;

function MakeDelay(ASeconds: Integer): TScenarioItem;
begin
  Result := Default(TScenarioItem);
  Result.Kind := sikDelay;
  Result.DelaySeconds := ASeconds;
end;

function CheckScenarioItem(const AItem: TScenarioItem;
  out AErrorText: string): Boolean;
begin
  AErrorText := '';
  case AItem.Kind of
    sikScenario:
      Result := CheckSyringeStep(AItem.Syringe, AErrorText);
  else
    begin
      Result := AItem.DelaySeconds >= 0;
      if not Result then
        AErrorText := 'Задержка должна быть целым числом секунд не меньше нуля.';
    end;
  end;
end;

function ScenarioItemSummary(const AItem: TScenarioItem): string;
begin
  case AItem.Kind of
    sikScenario:
      Result := SyringeStepSummary(AItem.Syringe);
  else
    Result := 'Задержка: ' + IntToStr(AItem.DelaySeconds) + ' с';
  end;
end;

function ScenarioListToText(AList: TScenarioList): string;
var
  I, J: Integer;
  Lines: TStringArray;
begin
  Result := KEY_BLOCK + '=' + SCENARIO_BLOCK_NAME + ';' + LineEnding;
  for I := 0 to AList.Count - 1 do
    case AList[I].Kind of
      sikScenario:
        begin
          Result := Result + #9 + KEY_SYRINGE + ';' + LineEnding;
          Lines := SyringeStepParamLines(AList[I].Syringe);
          for J := 0 to High(Lines) do
            Result := Result + #9#9 + Lines[J] + LineEnding;
        end;
      sikDelay:
        Result := Result + #9 + KEY_PAUSE + '=' +
          IntToStr(AList[I].DelaySeconds) + ';' + LineEnding;
    end;
end;

function StepKey(AKind: TProtocolStepKind): string;
begin
  case AKind of
    pskComment: Result := KEY_COMMENT;
    pskSyringe: Result := KEY_SYRINGE;
    pskVacuum: Result := KEY_VACUUM;
    pskLaser: Result := KEY_LASER;
  else
    Result := KEY_PAUSE;
  end;
end;

function ParseScenarioText(const AText: string; AList: TScenarioList;
  out AErrorText: string): Boolean;
var
  Document: TProtocolDocument;
  Parsed: TScenarioList;
  Step: TProtocolStep;
  I: Integer;
begin
  Result := False;
  if not ParseProtocolText(AText, Document, AErrorText) then
    Exit;
  if Length(Document) > 1 then
  begin
    AErrorText := 'Строка ' + IntToStr(Document[1].LineNumber) +
      ': в файле сценариев должен быть один список (Block=...), найдено ' +
      'блоков: ' + IntToStr(Length(Document)) + '.';
    Exit;
  end;
  Parsed := TScenarioList.Create;
  try
    if Length(Document) = 1 then
      for I := 0 to High(Document[0].Steps) do
      begin
        Step := Document[0].Steps[I];
        case Step.Kind of
          pskSyringe: Parsed.Add(MakeScenario(Step.Syringe));
          pskPause: Parsed.Add(MakeDelay(Step.IntValue));
        else
          begin
            AErrorText := 'Строка ' + IntToStr(Step.LineNumber) +
              ': в сценариях допускаются только SyrSt и Pause, а здесь ' +
              StepKey(Step.Kind) + '.';
            Exit;
          end;
        end;
      end;
    AList.Assign(Parsed);
    AErrorText := '';
    Result := True;
  finally
    Parsed.Free;
  end;
end;

function LoadScenarioFile(const AFileName: string; AList: TScenarioList;
  out AErrorText: string): Boolean;
var
  Content: UTF8String;
  ReadError: string;
begin
  Result := False;
  if not ReadUtf8TextFile(AFileName, Content, ReadError) then
  begin
    AErrorText := 'Не удалось прочитать файл сценариев:' + LineEnding +
      AFileName + LineEnding + ReadError;
    Exit;
  end;
  if not ParseScenarioText(Content, AList, ReadError) then
  begin
    AErrorText := 'Файл сценариев не загружен, ' + ExtractFileName(AFileName) +
      ':' + LineEnding + ReadError;
    Exit;
  end;
  AErrorText := '';
  Result := True;
end;

function SaveScenarioFile(const AFileName: string; AList: TScenarioList;
  out AErrorText: string): Boolean;
var
  I: Integer;
  ItemError, WriteError: string;
begin
  Result := False;
  for I := 0 to AList.Count - 1 do
    if not CheckScenarioItem(AList[I], ItemError) then
    begin
      AErrorText := 'Файл не сохранён: элемент ' + IntToStr(I + 1) +
        ' заполнен неверно.' + LineEnding + ItemError;
      Exit;
    end;
  if not WriteUtf8TextFile(AFileName, ScenarioListToText(AList), WriteError) then
  begin
    AErrorText := 'Не удалось сохранить файл сценариев:' + LineEnding +
      AFileName + LineEnding + WriteError;
    Exit;
  end;
  AErrorText := '';
  Result := True;
end;

end.
