unit ProtocolEditingTests;
// Тесты правил редактирования протокола: вставка, удаление, перестановка по
// выбранному узлу.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ProtocolFormat, ProtocolModel,
  ProtocolEditing;

type
  TProtocolEditingTests = class(TTestCase)
  private
    FModel: TProtocolModel;
    function Layout: string;
    procedure AssertPos(const AWhat: string; ABlock, AStep: Integer;
      const APosition: TProtocolPosition);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure PositionHelpersDescribeSelection;
    procedure NewBlockGoesToEndWithoutSelection;
    procedure NewBlockGoesAfterSelectedBlockOrItsStepBlock;
    procedure StepCannotBeAddedWithoutBlocks;
    procedure StepGoesToEndOfLastBlockWithoutSelection;
    procedure StepGoesToEndOfSelectedBlock;
    procedure StepGoesAfterSelectedStep;
    procedure StaleSelectionIsTreatedAsNone;
    procedure DeleteStepSelectsNeighbour;
    procedure DeleteLastStepSelectsPreviousOne;
    procedure DeleteOnlyStepSelectsBlock;
    procedure DeleteBlockSelectsNeighbour;
    procedure DeleteOnlyBlockSelectsNothing;
    procedure DeleteWithoutSelectionDoesNothing;
    procedure MoveStepInsideItsBlock;
    procedure MoveBlockKeepsItsSteps;
    procedure MoveFlagsAtEdges;
    procedure MoveAtEdgeChangesNothing;
  end;

implementation

function Comment(const AText: string): TProtocolStep;
begin
  Result := Default(TProtocolStep);
  Result.Kind := pskComment;
  Result.Text := AText;
end;

procedure TProtocolEditingTests.SetUp;
begin
  inherited SetUp;
  FModel := TProtocolModel.Create;
end;

procedure TProtocolEditingTests.TearDown;
begin
  FModel.Free;
  inherited TearDown;
end;

function TProtocolEditingTests.Layout: string;
// "A[a1 a2] B[b1]" - блоки и их операции
var
  B, S: Integer;
begin
  Result := '';
  for B := 0 to FModel.BlockCount - 1 do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + FModel.BlockNames[B] + '[';
    for S := 0 to FModel.StepCount(B) - 1 do
    begin
      if S > 0 then
        Result := Result + ' ';
      Result := Result + FModel.Steps[B, S].Text;
    end;
    Result := Result + ']';
  end;
end;

procedure TProtocolEditingTests.AssertPos(const AWhat: string; ABlock,
  AStep: Integer; const APosition: TProtocolPosition);
begin
  AssertEquals(AWhat + ' (блок)', ABlock, APosition.Block);
  AssertEquals(AWhat + ' (операция)', AStep, APosition.Step);
end;

procedure TProtocolEditingTests.PositionHelpersDescribeSelection;
begin
  AssertTrue(IsNoPosition(NoPosition));
  AssertFalse(IsNoPosition(BlockPosition(0)));
  AssertTrue(IsBlockPosition(BlockPosition(2)));
  AssertFalse(IsBlockPosition(StepPosition(2, 0)));
  AssertFalse(IsBlockPosition(NoPosition));

  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  AssertTrue(PositionExists(FModel, BlockPosition(0)));
  AssertTrue(PositionExists(FModel, StepPosition(0, 0)));
  AssertFalse(PositionExists(FModel, StepPosition(0, 1)));
  AssertFalse(PositionExists(FModel, BlockPosition(1)));
  AssertFalse(PositionExists(FModel, NoPosition));
end;

procedure TProtocolEditingTests.NewBlockGoesToEndWithoutSelection;
var
  P: TProtocolPosition;
begin
  P := InsertBlockAfter(FModel, NoPosition, 'A');
  AssertPos('первый блок', 0, -1, P);
  P := InsertBlockAfter(FModel, NoPosition, 'B');
  AssertPos('второй блок', 1, -1, P);
  AssertEquals('A[] B[]', Layout);
end;

procedure TProtocolEditingTests.NewBlockGoesAfterSelectedBlockOrItsStepBlock;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('C');
  FModel.AddStep(0, Comment('a1'));
  P := InsertBlockAfter(FModel, BlockPosition(0), 'B');
  AssertPos('после A', 1, -1, P);
  AssertEquals('A[a1] B[] C[]', Layout);
  // выбрана операция блока A - новый блок идёт после A, а не внутрь
  P := InsertBlockAfter(FModel, StepPosition(0, 0), 'X');
  AssertPos('после блока выбранной операции', 1, -1, P);
  AssertEquals('A[a1] X[] B[] C[]', Layout);
end;

procedure TProtocolEditingTests.StepCannotBeAddedWithoutBlocks;
var
  P: TProtocolPosition;
  ErrorText: string;
begin
  AssertFalse(InsertStepAfter(FModel, NoPosition, Comment('x'), P, ErrorText));
  AssertTrue(ErrorText <> '');
  AssertTrue(IsNoPosition(P));
  AssertEquals(0, FModel.BlockCount);
end;

procedure TProtocolEditingTests.StepGoesToEndOfLastBlockWithoutSelection;
var
  P: TProtocolPosition;
  ErrorText: string;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddStep(1, Comment('b1'));
  AssertTrue(ErrorText, InsertStepAfter(FModel, NoPosition, Comment('b2'), P,
    ErrorText));
  AssertPos('в конец последнего блока', 1, 1, P);
  AssertEquals('A[] B[b1 b2]', Layout);
end;

procedure TProtocolEditingTests.StepGoesToEndOfSelectedBlock;
var
  P: TProtocolPosition;
  ErrorText: string;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddStep(0, Comment('a1'));
  AssertTrue(ErrorText, InsertStepAfter(FModel, BlockPosition(0), Comment('a2'),
    P, ErrorText));
  AssertPos('в конец выбранного блока', 0, 1, P);
  AssertEquals('A[a1 a2] B[]', Layout);
end;

procedure TProtocolEditingTests.StepGoesAfterSelectedStep;
var
  P: TProtocolPosition;
  ErrorText: string;
begin
  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a3'));
  AssertTrue(ErrorText, InsertStepAfter(FModel, StepPosition(0, 0),
    Comment('a2'), P, ErrorText));
  AssertPos('после выбранной', 0, 1, P);
  AssertEquals('A[a1 a2 a3]', Layout);
end;

procedure TProtocolEditingTests.StaleSelectionIsTreatedAsNone;
var
  P: TProtocolPosition;
  ErrorText: string;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  AssertTrue(ErrorText, InsertStepAfter(FModel, StepPosition(5, 5),
    Comment('x'), P, ErrorText));
  AssertPos('вставка по устаревшему выбору', 1, 0, P);
  P := InsertBlockAfter(FModel, BlockPosition(9), 'C');
  AssertPos('блок по устаревшему выбору', 2, -1, P);
end;

procedure TProtocolEditingTests.DeleteStepSelectsNeighbour;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a2'));
  FModel.AddStep(0, Comment('a3'));
  P := DeleteAt(FModel, StepPosition(0, 1));
  AssertEquals('A[a1 a3]', Layout);
  AssertPos('следующая операция на том же месте', 0, 1, P);
end;

procedure TProtocolEditingTests.DeleteLastStepSelectsPreviousOne;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a2'));
  P := DeleteAt(FModel, StepPosition(0, 1));
  AssertEquals('A[a1]', Layout);
  AssertPos('предыдущая операция', 0, 0, P);
end;

procedure TProtocolEditingTests.DeleteOnlyStepSelectsBlock;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  P := DeleteAt(FModel, StepPosition(0, 0));
  AssertEquals('A[]', Layout);
  AssertPos('сам блок', 0, -1, P);
end;

procedure TProtocolEditingTests.DeleteBlockSelectsNeighbour;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddBlock('C');
  FModel.AddStep(1, Comment('b1'));
  P := DeleteAt(FModel, BlockPosition(1));
  AssertEquals('A[] C[]', Layout);
  AssertPos('следующий блок на том же месте', 1, -1, P);
  P := DeleteAt(FModel, BlockPosition(1));
  AssertEquals('A[]', Layout);
  AssertPos('предыдущий блок', 0, -1, P);
end;

procedure TProtocolEditingTests.DeleteOnlyBlockSelectsNothing;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  P := DeleteAt(FModel, BlockPosition(0));
  AssertEquals('', Layout);
  AssertTrue(IsNoPosition(P));
end;

procedure TProtocolEditingTests.DeleteWithoutSelectionDoesNothing;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  P := DeleteAt(FModel, NoPosition);
  AssertEquals('A[]', Layout);
  AssertTrue(IsNoPosition(P));
  P := DeleteAt(FModel, StepPosition(4, 4));
  AssertEquals('A[]', Layout);
end;

procedure TProtocolEditingTests.MoveStepInsideItsBlock;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a2'));
  FModel.AddStep(0, Comment('a3'));
  FModel.AddStep(1, Comment('b1'));
  P := MoveDown(FModel, StepPosition(0, 0));
  AssertEquals('A[a2 a1 a3] B[b1]', Layout);
  AssertPos('операция вниз', 0, 1, P);
  P := MoveUp(FModel, StepPosition(0, 2));
  AssertEquals('A[a2 a3 a1] B[b1]', Layout);
  AssertPos('операция вверх', 0, 1, P);
end;

procedure TProtocolEditingTests.MoveBlockKeepsItsSteps;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(1, Comment('b1'));
  P := MoveDown(FModel, BlockPosition(0));
  AssertEquals('B[b1] A[a1]', Layout);
  AssertPos('блок вниз', 1, -1, P);
  P := MoveUp(FModel, BlockPosition(1));
  AssertEquals('A[a1] B[b1]', Layout);
  AssertPos('блок вверх', 0, -1, P);
end;

procedure TProtocolEditingTests.MoveFlagsAtEdges;
begin
  FModel.AddBlock('A');
  FModel.AddBlock('B');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a2'));
  AssertFalse('первая операция вверх', CanMoveUp(FModel, StepPosition(0, 0)));
  AssertTrue('первая операция вниз', CanMoveDown(FModel, StepPosition(0, 0)));
  AssertTrue('последняя операция вверх', CanMoveUp(FModel, StepPosition(0, 1)));
  AssertFalse('последняя операция вниз', CanMoveDown(FModel, StepPosition(0, 1)));
  AssertFalse('первый блок вверх', CanMoveUp(FModel, BlockPosition(0)));
  AssertTrue('первый блок вниз', CanMoveDown(FModel, BlockPosition(0)));
  AssertFalse('последний блок вниз', CanMoveDown(FModel, BlockPosition(1)));
  AssertFalse('без выбора вверх', CanMoveUp(FModel, NoPosition));
  AssertFalse('без выбора вниз', CanMoveDown(FModel, NoPosition));
  AssertFalse('устаревший выбор', CanMoveDown(FModel, StepPosition(7, 0)));
end;

procedure TProtocolEditingTests.MoveAtEdgeChangesNothing;
var
  P: TProtocolPosition;
begin
  FModel.AddBlock('A');
  FModel.AddStep(0, Comment('a1'));
  FModel.AddStep(0, Comment('a2'));
  P := MoveUp(FModel, StepPosition(0, 0));
  AssertEquals('A[a1 a2]', Layout);
  AssertPos('на месте', 0, 0, P);
  P := MoveDown(FModel, BlockPosition(0));
  AssertEquals('A[a1 a2]', Layout);
  AssertPos('блок на месте', 0, -1, P);
end;

initialization
  RegisterTest(TProtocolEditingTests);

end.
