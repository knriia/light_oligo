unit ProtocolModel;
// Протокол синтеза в памяти: блоки, а в блоках операции (шприцевая станция,
// вакуум, лазер, пауза, комментарий). Редактор меняет только эту модель, а
// дерево на экране строится из неё. Формат файла - ProtocolFormat; модель
// читает и пишет его, проверяя всё перед записью и объясняя ошибки.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat;

type
  TProtocolModel = class
  private
    FBlocks: TProtocolDocument;
    procedure CheckBlockIndex(AIndex, AMax: Integer);
    procedure CheckStepIndex(ABlock, AIndex, AMax: Integer);
    function GetBlockName(AIndex: Integer): string;
    function GetBlockCount: Integer;
    function GetStep(ABlock, AIndex: Integer): TProtocolStep;
  public
    // Индекс вне границ - ошибка программы, поднимается EListError.
    function AddBlock(const AName: string): Integer;
    procedure InsertBlock(AIndex: Integer; const AName: string);
    procedure RenameBlock(AIndex: Integer; const AName: string);
    procedure DeleteBlock(AIndex: Integer);
    procedure MoveBlock(AFromIndex, AToIndex: Integer);

    function StepCount(ABlock: Integer): Integer;
    function AddStep(ABlock: Integer; const AStep: TProtocolStep): Integer;
    procedure InsertStep(ABlock, AIndex: Integer; const AStep: TProtocolStep);
    procedure ReplaceStep(ABlock, AIndex: Integer; const AStep: TProtocolStep);
    procedure DeleteStep(ABlock, AIndex: Integer);
    // Переносит операцию внутри блока, остальные сдвигаются.
    procedure MoveStep(ABlock, AFromIndex, AToIndex: Integer);

    procedure Clear;
    procedure Assign(AOther: TProtocolModel);

    // Проверка всего протокола перед записью: имена блоков, операции.
    // Ошибка называет блок и номер операции.
    function Check(out AErrorText: string): Boolean;
    function ToText: string;
    // Разбор текста протокола. Пустой текст - пустой протокол. При ошибке
    // модель не меняется, а текст ошибки начинается с номера строки.
    function LoadFromText(const AText: string; out AErrorText: string): Boolean;
    function LoadFromFile(const AFileName: string;
      out AErrorText: string): Boolean;
    // Сначала проверяет протокол; при ошибке файл не трогает.
    function SaveToFile(const AFileName: string;
      out AErrorText: string): Boolean;

    property BlockCount: Integer read GetBlockCount;
    property BlockNames[AIndex: Integer]: string read GetBlockName;
    property Steps[ABlock, AIndex: Integer]: TProtocolStep read GetStep;
  end;

// Проверка имени блока: не пустое и пригодное для записи в файл.
function CheckProtocolBlockName(const AName: string;
  out AErrorText: string): Boolean;

implementation

uses
  TextFileUtils;

function CheckProtocolBlockName(const AName: string;
  out AErrorText: string): Boolean;
begin
  AErrorText := '';
  if Trim(AName) = '' then
  begin
    AErrorText := 'Имя блока не задано.';
    Exit(False);
  end;
  Result := CheckProtocolText(AName, 'Имя блока', AErrorText);
end;

procedure TProtocolModel.CheckBlockIndex(AIndex, AMax: Integer);
begin
  if (AIndex < 0) or (AIndex > AMax) then
    raise EListError.CreateFmt('Protocol block index %d is out of range 0..%d',
      [AIndex, AMax]);
end;

procedure TProtocolModel.CheckStepIndex(ABlock, AIndex, AMax: Integer);
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  if (AIndex < 0) or (AIndex > AMax) then
    raise EListError.CreateFmt('Protocol step index %d is out of range 0..%d',
      [AIndex, AMax]);
end;

function TProtocolModel.GetBlockCount: Integer;
begin
  Result := Length(FBlocks);
end;

function TProtocolModel.GetBlockName(AIndex: Integer): string;
begin
  CheckBlockIndex(AIndex, High(FBlocks));
  Result := FBlocks[AIndex].Name;
end;

function TProtocolModel.GetStep(ABlock, AIndex: Integer): TProtocolStep;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  CheckStepIndex(ABlock, AIndex, High(FBlocks[ABlock].Steps));
  Result := FBlocks[ABlock].Steps[AIndex];
end;

function TProtocolModel.AddBlock(const AName: string): Integer;
begin
  SetLength(FBlocks, Length(FBlocks) + 1);
  Result := High(FBlocks);
  FBlocks[Result] := Default(TProtocolBlock);
  FBlocks[Result].Name := AName;
end;

procedure TProtocolModel.InsertBlock(AIndex: Integer; const AName: string);
var
  I: Integer;
begin
  CheckBlockIndex(AIndex, Length(FBlocks)); // можно и в конец
  SetLength(FBlocks, Length(FBlocks) + 1);
  for I := High(FBlocks) downto AIndex + 1 do
    FBlocks[I] := FBlocks[I - 1];
  FBlocks[AIndex] := Default(TProtocolBlock);
  FBlocks[AIndex].Name := AName;
end;

procedure TProtocolModel.RenameBlock(AIndex: Integer; const AName: string);
begin
  CheckBlockIndex(AIndex, High(FBlocks));
  FBlocks[AIndex].Name := AName;
end;

procedure TProtocolModel.DeleteBlock(AIndex: Integer);
var
  I: Integer;
begin
  CheckBlockIndex(AIndex, High(FBlocks));
  for I := AIndex to High(FBlocks) - 1 do
    FBlocks[I] := FBlocks[I + 1];
  SetLength(FBlocks, Length(FBlocks) - 1);
end;

procedure TProtocolModel.MoveBlock(AFromIndex, AToIndex: Integer);
var
  Block: TProtocolBlock;
  I: Integer;
begin
  CheckBlockIndex(AFromIndex, High(FBlocks));
  CheckBlockIndex(AToIndex, High(FBlocks));
  Block := FBlocks[AFromIndex];
  if AFromIndex < AToIndex then
    for I := AFromIndex to AToIndex - 1 do
      FBlocks[I] := FBlocks[I + 1]
  else
    for I := AFromIndex downto AToIndex + 1 do
      FBlocks[I] := FBlocks[I - 1];
  FBlocks[AToIndex] := Block;
end;

function TProtocolModel.StepCount(ABlock: Integer): Integer;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  Result := Length(FBlocks[ABlock].Steps);
end;

function TProtocolModel.AddStep(ABlock: Integer;
  const AStep: TProtocolStep): Integer;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  SetLength(FBlocks[ABlock].Steps, Length(FBlocks[ABlock].Steps) + 1);
  Result := High(FBlocks[ABlock].Steps);
  FBlocks[ABlock].Steps[Result] := AStep;
end;

procedure TProtocolModel.InsertStep(ABlock, AIndex: Integer;
  const AStep: TProtocolStep);
var
  I: Integer;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  CheckStepIndex(ABlock, AIndex, Length(FBlocks[ABlock].Steps)); // и в конец
  SetLength(FBlocks[ABlock].Steps, Length(FBlocks[ABlock].Steps) + 1);
  for I := High(FBlocks[ABlock].Steps) downto AIndex + 1 do
    FBlocks[ABlock].Steps[I] := FBlocks[ABlock].Steps[I - 1];
  FBlocks[ABlock].Steps[AIndex] := AStep;
end;

procedure TProtocolModel.ReplaceStep(ABlock, AIndex: Integer;
  const AStep: TProtocolStep);
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  CheckStepIndex(ABlock, AIndex, High(FBlocks[ABlock].Steps));
  FBlocks[ABlock].Steps[AIndex] := AStep;
end;

procedure TProtocolModel.DeleteStep(ABlock, AIndex: Integer);
var
  I: Integer;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  CheckStepIndex(ABlock, AIndex, High(FBlocks[ABlock].Steps));
  for I := AIndex to High(FBlocks[ABlock].Steps) - 1 do
    FBlocks[ABlock].Steps[I] := FBlocks[ABlock].Steps[I + 1];
  SetLength(FBlocks[ABlock].Steps, Length(FBlocks[ABlock].Steps) - 1);
end;

procedure TProtocolModel.MoveStep(ABlock, AFromIndex, AToIndex: Integer);
var
  Step: TProtocolStep;
  I: Integer;
begin
  CheckBlockIndex(ABlock, High(FBlocks));
  CheckStepIndex(ABlock, AFromIndex, High(FBlocks[ABlock].Steps));
  CheckStepIndex(ABlock, AToIndex, High(FBlocks[ABlock].Steps));
  Step := FBlocks[ABlock].Steps[AFromIndex];
  if AFromIndex < AToIndex then
    for I := AFromIndex to AToIndex - 1 do
      FBlocks[ABlock].Steps[I] := FBlocks[ABlock].Steps[I + 1]
  else
    for I := AFromIndex downto AToIndex + 1 do
      FBlocks[ABlock].Steps[I] := FBlocks[ABlock].Steps[I - 1];
  FBlocks[ABlock].Steps[AToIndex] := Step;
end;

procedure TProtocolModel.Clear;
begin
  FBlocks := nil;
end;

procedure TProtocolModel.Assign(AOther: TProtocolModel);
var
  I: Integer;
begin
  FBlocks := Copy(AOther.FBlocks);
  for I := 0 to High(FBlocks) do
    FBlocks[I].Steps := Copy(AOther.FBlocks[I].Steps); // операции не общие
end;

function TProtocolModel.Check(out AErrorText: string): Boolean;
var
  B, S: Integer;
  ItemError: string;
begin
  Result := False;
  AErrorText := '';
  for B := 0 to High(FBlocks) do
  begin
    if not CheckProtocolBlockName(FBlocks[B].Name, ItemError) then
    begin
      AErrorText := 'Блок ' + IntToStr(B + 1) + ': ' + ItemError;
      Exit;
    end;
    for S := 0 to High(FBlocks[B].Steps) do
      if not CheckProtocolStep(FBlocks[B].Steps[S], ItemError) then
      begin
        AErrorText := 'Блок ' + IntToStr(B + 1) + ' "' + FBlocks[B].Name +
          '", операция ' + IntToStr(S + 1) + ': ' + ItemError;
        Exit;
      end;
  end;
  Result := True;
end;

function TProtocolModel.ToText: string;
begin
  Result := ProtocolDocumentToText(FBlocks);
end;

function TProtocolModel.LoadFromText(const AText: string;
  out AErrorText: string): Boolean;
var
  Parsed: TProtocolDocument;
begin
  Result := ParseProtocolText(AText, Parsed, AErrorText);
  if Result then
    FBlocks := Parsed;
end;

function TProtocolModel.LoadFromFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  Content: UTF8String;
  ReadError: string;
begin
  Result := False;
  if not ReadUtf8TextFile(AFileName, Content, ReadError) then
  begin
    AErrorText := 'Не удалось прочитать файл протокола:' + LineEnding +
      AFileName + LineEnding + ReadError;
    Exit;
  end;
  if not LoadFromText(Content, ReadError) then
  begin
    AErrorText := 'Протокол не загружен, ' + ExtractFileName(AFileName) + ':' +
      LineEnding + ReadError;
    Exit;
  end;
  AErrorText := '';
  Result := True;
end;

function TProtocolModel.SaveToFile(const AFileName: string;
  out AErrorText: string): Boolean;
var
  ItemError: string;
begin
  Result := False;
  if not Check(ItemError) then
  begin
    AErrorText := 'Файл не сохранён: ' + ItemError;
    Exit;
  end;
  if not WriteUtf8TextFile(AFileName, ToText, ItemError) then
  begin
    AErrorText := 'Не удалось сохранить файл протокола:' + LineEnding +
      AFileName + LineEnding + ItemError;
    Exit;
  end;
  AErrorText := '';
  Result := True;
end;

end.
