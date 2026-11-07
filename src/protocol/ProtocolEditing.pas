unit ProtocolEditing;
// Правила редактирования протокола по выбранному узлу дерева: куда встаёт
// новый блок или операция, что выделить после удаления, как переставлять.
// Работает с ProtocolModel и позицией (блок, операция) без дерева и окон,
// поэтому проверяется тестами. Дерево на экране только показывает результат.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, ProtocolFormat, ProtocolModel;

type
  // Выбранный узел. Block < 0 - ничего не выбрано; Step < 0 - выбран сам блок.
  TProtocolPosition = record
    Block: Integer;
    Step: Integer;
  end;

function NoPosition: TProtocolPosition;
function BlockPosition(ABlock: Integer): TProtocolPosition;
function StepPosition(ABlock, AStep: Integer): TProtocolPosition;
function IsNoPosition(const APosition: TProtocolPosition): Boolean;
function IsBlockPosition(const APosition: TProtocolPosition): Boolean;
// Позиция существует в модели.
function PositionExists(AModel: TProtocolModel;
  const APosition: TProtocolPosition): Boolean;

// Новый блок встаёт после выбранного (по выбранной операции - после её
// блока), без выбора - в конец. Возвращает позицию нового блока.
function InsertBlockAfter(AModel: TProtocolModel;
  const ASelected: TProtocolPosition; const AName: string): TProtocolPosition;

// Новая операция: после выбранной операции, у выбранного блока - в его
// конец, без выбора - в конец последнего блока. False, если блоков нет
// (операции некуда добавить); AErrorText объясняет.
function InsertStepAfter(AModel: TProtocolModel;
  const ASelected: TProtocolPosition; const AStep: TProtocolStep;
  out ANew: TProtocolPosition; out AErrorText: string): Boolean;

// Удаляет выбранный блок или операцию и возвращает, что выделить дальше:
// соседний узел или, если соседей нет, блок (или ничего).
function DeleteAt(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;

// Блок меняется местами с соседними блоками, операция - внутри своего блока.
function CanMoveUp(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): Boolean;
function CanMoveDown(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): Boolean;
// Возвращает новую позицию перенесённого узла.
function MoveUp(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;
function MoveDown(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;

implementation

function NoPosition: TProtocolPosition;
begin
  Result.Block := -1;
  Result.Step := -1;
end;

function BlockPosition(ABlock: Integer): TProtocolPosition;
begin
  Result.Block := ABlock;
  Result.Step := -1;
end;

function StepPosition(ABlock, AStep: Integer): TProtocolPosition;
begin
  Result.Block := ABlock;
  Result.Step := AStep;
end;

function IsNoPosition(const APosition: TProtocolPosition): Boolean;
begin
  Result := APosition.Block < 0;
end;

function IsBlockPosition(const APosition: TProtocolPosition): Boolean;
begin
  Result := (APosition.Block >= 0) and (APosition.Step < 0);
end;

function PositionExists(AModel: TProtocolModel;
  const APosition: TProtocolPosition): Boolean;
begin
  Result := (APosition.Block >= 0) and (APosition.Block < AModel.BlockCount);
  if Result and (APosition.Step >= 0) then
    Result := APosition.Step < AModel.StepCount(APosition.Block);
end;

function InsertBlockAfter(AModel: TProtocolModel;
  const ASelected: TProtocolPosition; const AName: string): TProtocolPosition;
var
  Index: Integer;
begin
  if PositionExists(AModel, ASelected) then
    Index := ASelected.Block + 1
  else
    Index := AModel.BlockCount;
  AModel.InsertBlock(Index, AName);
  Result := BlockPosition(Index);
end;

function InsertStepAfter(AModel: TProtocolModel;
  const ASelected: TProtocolPosition; const AStep: TProtocolStep;
  out ANew: TProtocolPosition; out AErrorText: string): Boolean;
var
  Block, Index: Integer;
begin
  Result := False;
  AErrorText := '';
  ANew := NoPosition;
  if AModel.BlockCount = 0 then
  begin
    AErrorText := 'Сначала добавьте блок: операции находятся внутри блоков.';
    Exit;
  end;
  if PositionExists(AModel, ASelected) then
  begin
    Block := ASelected.Block;
    if ASelected.Step >= 0 then
      Index := ASelected.Step + 1
    else
      Index := AModel.StepCount(Block);
  end
  else
  begin
    Block := AModel.BlockCount - 1;
    Index := AModel.StepCount(Block);
  end;
  AModel.InsertStep(Block, Index, AStep);
  ANew := StepPosition(Block, Index);
  Result := True;
end;

function DeleteAt(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;
var
  Index: Integer;
begin
  Result := NoPosition;
  if not PositionExists(AModel, ASelected) then
    Exit;
  if ASelected.Step >= 0 then
  begin
    AModel.DeleteStep(ASelected.Block, ASelected.Step);
    Index := ASelected.Step;
    if Index >= AModel.StepCount(ASelected.Block) then
      Index := AModel.StepCount(ASelected.Block) - 1;
    if Index >= 0 then
      Result := StepPosition(ASelected.Block, Index)
    else
      Result := BlockPosition(ASelected.Block);
  end
  else
  begin
    AModel.DeleteBlock(ASelected.Block);
    Index := ASelected.Block;
    if Index >= AModel.BlockCount then
      Index := AModel.BlockCount - 1;
    if Index >= 0 then
      Result := BlockPosition(Index);
  end;
end;

function CanMoveUp(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): Boolean;
begin
  if not PositionExists(AModel, ASelected) then
    Exit(False);
  if ASelected.Step >= 0 then
    Result := ASelected.Step > 0
  else
    Result := ASelected.Block > 0;
end;

function CanMoveDown(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): Boolean;
begin
  if not PositionExists(AModel, ASelected) then
    Exit(False);
  if ASelected.Step >= 0 then
    Result := ASelected.Step < AModel.StepCount(ASelected.Block) - 1
  else
    Result := ASelected.Block < AModel.BlockCount - 1;
end;

function MoveUp(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;
begin
  Result := ASelected;
  if not CanMoveUp(AModel, ASelected) then
    Exit;
  if ASelected.Step >= 0 then
  begin
    AModel.MoveStep(ASelected.Block, ASelected.Step, ASelected.Step - 1);
    Result := StepPosition(ASelected.Block, ASelected.Step - 1);
  end
  else
  begin
    AModel.MoveBlock(ASelected.Block, ASelected.Block - 1);
    Result := BlockPosition(ASelected.Block - 1);
  end;
end;

function MoveDown(AModel: TProtocolModel;
  const ASelected: TProtocolPosition): TProtocolPosition;
begin
  Result := ASelected;
  if not CanMoveDown(AModel, ASelected) then
    Exit;
  if ASelected.Step >= 0 then
  begin
    AModel.MoveStep(ASelected.Block, ASelected.Step, ASelected.Step + 1);
    Result := StepPosition(ASelected.Block, ASelected.Step + 1);
  end
  else
  begin
    AModel.MoveBlock(ASelected.Block, ASelected.Block + 1);
    Result := BlockPosition(ASelected.Block + 1);
  end;
end;

end.
