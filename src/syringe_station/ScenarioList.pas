unit ScenarioList;
// Сценарий шприцевой станции - список операций. Он хранится в файле.
// Операция "шприцевая станция" (SyrSt) - подача из дозаторов, из
// нескольких одновременно или из одного. Пауза - ожидание в секундах.
//
// Поля операции и их проверка те же, что у операции SyrSt в протоколе синтеза
// (ProtocolFormat). Файл - это записи SyrSt и Pause подряд, без строки
// Block=...:
//
//   SyrSt;
//   	Dispensers=A/Act;
//   	Valves=2/2;
//   	Volumes=100/100;
//   	VolumeUnit=мкл;
//   	Speeds=10/10;
//   	SpeedUnit=мкл/с;
//   Pause=30;
//   SyrSt;
//   	...

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat;

const
  SCENARIO_FILE_EXT = '.scn';

type
  TScenarioItemKind = (sikSyringe, sikPause);

  TScenarioItem = record
    Kind: TScenarioItemKind;
    Syringe: TSyringeStep;  // параметры подачи (шприцевая станция)
    PauseSeconds: Integer;  // пауза, с (для паузы)
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
    // Сколько в списке операций шприцевой станции (паузы не считаются).
    function SyringeCount: Integer;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TScenarioItem read GetItem; default;
  end;

function MakeSyringe(const ASyringe: TSyringeStep): TScenarioItem;
function MakePause(ASeconds: Integer): TScenarioItem;

// Связь с операцией протокола (общее окно операции и запись в файл).
// В сценарии бывают только шприцевая станция и пауза: любая другая операция
// превращается в шприцевую станцию с пустыми полями.
function ScenarioItemToStep(const AItem: TScenarioItem): TProtocolStep;
function ScenarioItemFromStep(const AStep: TProtocolStep): TScenarioItem;

// Проверка операции: шприцевая станция - как SyrSt, пауза - целое число секунд
// не меньше нуля. При ошибке текст объясняет, что не так.
function CheckScenarioItem(const AItem: TScenarioItem;
  out AErrorText: string): Boolean;
// Короткое описание для списка на экране и журнала.
function ScenarioItemSummary(const AItem: TScenarioItem): string;

// Текст файла сценария (формат выше).
function ScenarioListToText(AList: TScenarioList): string;
// Разбор текста. Пустой текст - пустой сценарий. При ошибке список не
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

function TScenarioList.SyringeCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FItems) do
    if FItems[I].Kind = sikSyringe then
      Inc(Result);
end;

function MakeSyringe(const ASyringe: TSyringeStep): TScenarioItem;
begin
  Result := Default(TScenarioItem);
  Result.Kind := sikSyringe;
  Result.Syringe := ASyringe;
end;

function MakePause(ASeconds: Integer): TScenarioItem;
begin
  Result := Default(TScenarioItem);
  Result.Kind := sikPause;
  Result.PauseSeconds := ASeconds;
end;

function ScenarioItemToStep(const AItem: TScenarioItem): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  if AItem.Kind = sikPause then
  begin
    Result.Kind := pskPause;
    Result.IntValue := AItem.PauseSeconds;
  end
  else
  begin
    Result.Kind := pskSyringe;
    Result.Syringe := AItem.Syringe;
  end;
end;

function ScenarioItemFromStep(const AStep: TProtocolStep): TScenarioItem;
begin
  if AStep.Kind = pskPause then
    Result := MakePause(AStep.IntValue)
  else
    Result := MakeSyringe(AStep.Syringe);
end;

function CheckScenarioItem(const AItem: TScenarioItem;
  out AErrorText: string): Boolean;
begin
  AErrorText := '';
  case AItem.Kind of
    sikSyringe:
      Result := CheckSyringeStep(AItem.Syringe, AErrorText);
  else
    begin
      Result := AItem.PauseSeconds >= 0;
      if not Result then
        AErrorText := 'Пауза должна быть целым числом секунд не меньше нуля.';
    end;
  end;
end;

function ScenarioItemSummary(const AItem: TScenarioItem): string;
begin
  case AItem.Kind of
    sikSyringe:
      Result := SyringeStepSummary(AItem.Syringe);
  else
    Result := 'Пауза: ' + IntToStr(AItem.PauseSeconds) + ' с';
  end;
end;

function ScenarioListToText(AList: TScenarioList): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
    // в сценарии нет блоков: операции без отступа
    Result := Result + ProtocolStepToText(ScenarioItemToStep(AList[I]), 0);
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
  if not ParseProtocolText(AText, Document, AErrorText, True) then
    Exit;
  if Length(Document) > 1 then
  begin
    AErrorText := 'Строка ' + IntToStr(Document[1].LineNumber) +
      ': в сценарии не должно быть строк Block=..., только SyrSt и Pause.';
    Exit;
  end;
  Parsed := TScenarioList.Create;
  try
    for I := 0 to High(Document[0].Steps) do
    begin
      Step := Document[0].Steps[I];
      case Step.Kind of
        pskSyringe: Parsed.Add(MakeSyringe(Step.Syringe));
        pskPause: Parsed.Add(MakePause(Step.IntValue));
      else
        begin
          AErrorText := 'Строка ' + IntToStr(Step.LineNumber) +
            ': в сценарии допускаются только SyrSt и Pause, а здесь ' +
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
    AErrorText := 'Не удалось прочитать файл сценария:' + LineEnding +
      AFileName + LineEnding + ReadError;
    Exit;
  end;
  if not ParseScenarioText(Content, AList, ReadError) then
  begin
    AErrorText := 'Сценарий не загружен, ' + ExtractFileName(AFileName) +
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
      AErrorText := 'Файл не сохранён: операция ' + IntToStr(I + 1) +
        ' заполнена неверно.' + LineEnding + ItemError;
      Exit;
    end;
  if not WriteUtf8TextFile(AFileName, ScenarioListToText(AList), WriteError) then
  begin
    AErrorText := 'Не удалось сохранить файл сценария:' + LineEnding +
      AFileName + LineEnding + WriteError;
    Exit;
  end;
  AErrorText := '';
  Result := True;
end;

end.
