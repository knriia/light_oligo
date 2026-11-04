unit SynthesisSession;
// Что загружено для синтеза: таблица слоёв (Slices.lays) и по протоколу на
// каждую букву нуклеотида (имя файла протокола без расширения - это буква).
// Окна и поток синтеза получают сессию, а не общие переменные. Сессия
// проверяет, что синтез можно запускать: слои есть, протокол есть для каждой
// буквы слоёв.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoSlices, ProtocolFormat, ProtocolModel;

type
  TSynthesisSession = class
  private
    FLayers: TSliceLayers;
    FLetters: TStringList;   // буквы загруженных протоколов в порядке загрузки
    FProtocols: array of TProtocolModel;
    function GetLayerCount: Integer;
    function GetProtocolCount: Integer;
    function GetProtocolLetter(AIndex: Integer): string;
    function IndexOfLetter(const ALetter: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    // Слои. SetLayers копирует таблицу (так её отдаёт нарезка массива).
    procedure SetLayers(const ALayers: TSliceLayers);
    procedure ClearLayers;
    // Читает Slices.lays; при ошибке слои не меняются.
    function LoadLayersFile(const AFileName: string;
      out AErrorText: string): Boolean;

    // Буква протокола - имя файла без пути и расширения.
    class function LetterOfFile(const AFileName: string): string;
    function HasProtocol(const ALetter: string): Boolean;
    // nil, если протокола для буквы нет. Протокол принадлежит сессии.
    function ProtocolOf(const ALetter: string): TProtocolModel;
    // Загружает протокол буквы. Для буквы уже есть протокол или файл не
    // читается - False, текст объясняет, сессия не меняется.
    function AddProtocolFile(const AFileName: string; out ALetter: string;
      out AErrorText: string): Boolean;

    // Убирает протокол буквы; False - такого не было.
    function RemoveProtocol(const ALetter: string): Boolean;

    // Буквы слоёв, для которых нет протокола (без повторов, в порядке слоёв).
    function MissingLetters: TStringArray;
    // Можно ли запускать синтез; иначе текст, чего не хватает.
    function CheckReady(out AErrorText: string): Boolean;
    // Убирает слои и протоколы.
    procedure Clear;

    property Layers: TSliceLayers read FLayers;
    property LayerCount: Integer read GetLayerCount;
    property ProtocolCount: Integer read GetProtocolCount;
    property ProtocolLetters[AIndex: Integer]: string read GetProtocolLetter;
  end;

implementation

constructor TSynthesisSession.Create;
begin
  inherited Create;
  FLetters := TStringList.Create;
end;

destructor TSynthesisSession.Destroy;
begin
  Clear;
  FLetters.Free;
  inherited Destroy;
end;

function TSynthesisSession.GetLayerCount: Integer;
begin
  Result := Length(FLayers);
end;

function TSynthesisSession.GetProtocolCount: Integer;
begin
  Result := FLetters.Count;
end;

function TSynthesisSession.GetProtocolLetter(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= FLetters.Count) then
    raise EListError.CreateFmt('Protocol index %d is out of range 0..%d',
      [AIndex, FLetters.Count - 1]);
  Result := FLetters[AIndex];
end;

function TSynthesisSession.IndexOfLetter(const ALetter: string): Integer;
begin
  Result := FLetters.IndexOf(ALetter);
end;

procedure TSynthesisSession.SetLayers(const ALayers: TSliceLayers);
begin
  FLayers := Copy(ALayers);
end;

procedure TSynthesisSession.ClearLayers;
begin
  FLayers := nil;
end;

function TSynthesisSession.LoadLayersFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  Loaded: TSliceLayers;
begin
  Result := LoadSliceLayers(AFileName, Loaded, AErrorText);
  if Result then
    FLayers := Loaded;
end;

class function TSynthesisSession.LetterOfFile(const AFileName: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(AFileName), '');
end;

function TSynthesisSession.HasProtocol(const ALetter: string): Boolean;
begin
  Result := IndexOfLetter(ALetter) >= 0;
end;

function TSynthesisSession.ProtocolOf(const ALetter: string): TProtocolModel;
var
  Index: Integer;
begin
  Index := IndexOfLetter(ALetter);
  if Index < 0 then
    Result := nil
  else
    Result := FProtocols[Index];
end;

function TSynthesisSession.AddProtocolFile(const AFileName: string;
  out ALetter: string; out AErrorText: string): Boolean;
var
  Model: TProtocolModel;
begin
  Result := False;
  AErrorText := '';
  ALetter := LetterOfFile(AFileName);
  if ALetter = '' then
  begin
    AErrorText := 'Не удалось определить букву протокола по имени файла: ' +
      AFileName;
    Exit;
  end;
  if HasProtocol(ALetter) then
  begin
    AErrorText := 'Протокол для буквы "' + ALetter + '" уже загружен. ' +
      'Чтобы заменить его, сначала очистите загруженное.';
    Exit;
  end;
  Model := TProtocolModel.Create;
  if not Model.LoadFromFile(AFileName, AErrorText) then
  begin
    Model.Free;
    Exit;
  end;
  SetLength(FProtocols, Length(FProtocols) + 1);
  FProtocols[High(FProtocols)] := Model;
  FLetters.Add(ALetter);
  Result := True;
end;

function TSynthesisSession.RemoveProtocol(const ALetter: string): Boolean;
var
  Index, I: Integer;
begin
  Index := IndexOfLetter(ALetter);
  Result := Index >= 0;
  if not Result then
    Exit;
  FProtocols[Index].Free;
  for I := Index to High(FProtocols) - 1 do
    FProtocols[I] := FProtocols[I + 1];
  SetLength(FProtocols, Length(FProtocols) - 1);
  FLetters.Delete(Index);
end;

function TSynthesisSession.MissingLetters: TStringArray;
var
  I: Integer;
  Seen: TStringList;
begin
  Result := nil;
  Seen := TStringList.Create;
  try
    for I := 0 to High(FLayers) do
      if not HasProtocol(FLayers[I].Letter) and
        (Seen.IndexOf(FLayers[I].Letter) < 0) then
      begin
        Seen.Add(FLayers[I].Letter);
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := FLayers[I].Letter;
      end;
  finally
    Seen.Free;
  end;
end;

function TSynthesisSession.CheckReady(out AErrorText: string): Boolean;
var
  Missing: TStringArray;
  I: Integer;
  Letters: string;
begin
  Result := False;
  AErrorText := '';
  if Length(FLayers) = 0 then
  begin
    AErrorText := 'Не загружены слои. Загрузите файл слоёв (Slices.lays) ' +
      'или выполните слайсинг массива.';
    Exit;
  end;
  Missing := MissingLetters;
  if Length(Missing) > 0 then
  begin
    Letters := '';
    for I := 0 to High(Missing) do
    begin
      if I > 0 then
        Letters := Letters + ', ';
      Letters := Letters + Missing[I];
    end;
    AErrorText := 'Нет протоколов для букв: ' + Letters + '. Имя файла ' +
      'протокола должно совпадать с буквой, например A.pro.';
    Exit;
  end;
  Result := True;
end;

procedure TSynthesisSession.Clear;
var
  I: Integer;
begin
  for I := 0 to High(FProtocols) do
    FProtocols[I].Free;
  FProtocols := nil;
  FLetters.Clear;
  FLayers := nil;
end;

end.
