unit UProtocolForm;
// Вкладка «Протокол»: редактор протокола синтеза. Протокол живёт в
// ProtocolModel, дерево на экране строится из неё и только для чтения;
// менять протокол можно кнопками и двойным щелчком по узлу (открывается окно
// блока или операции). Правила вставки, удаления и перестановки - в
// ProtocolEditing, формат файла - в ProtocolFormat.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  IniFiles, ProtocolFormat, ProtocolModel, ProtocolEditing;

type

  { TProtocolForm }

  TProtocolForm = class(TForm)
    B_AddBlock: TButton;
    B_AddOperation: TButton;
    B_Delete: TButton;
    B_MoveDown: TButton;
    B_MoveUp: TButton;
    B_New: TButton;
    B_Open: TButton;
    B_Save: TButton;
    L_File: TLabel;
    OD_File: TOpenDialog;
    P_Buttons: TPanel;
    SD_File: TSaveDialog;
    TV_Protocol: TTreeView;
    procedure B_AddBlockClick(Sender: TObject);
    procedure B_AddOperationClick(Sender: TObject);
    procedure B_DeleteClick(Sender: TObject);
    procedure B_MoveDownClick(Sender: TObject);
    procedure B_MoveUpClick(Sender: TObject);
    procedure B_NewClick(Sender: TObject);
    procedure B_OpenClick(Sender: TObject);
    procedure B_SaveClick(Sender: TObject);
    procedure TV_ProtocolDblClick(Sender: TObject);
    procedure TV_ProtocolSelectionChanged(Sender: TObject);
  private
    FModel: TProtocolModel;
    FFileName: string;
    FModified: Boolean;           // протокол менялся после открытия или сохранения
    FCaptions: TCustomIniFile;    // подписи окон (не владеем)
    function PositionOfNode(ANode: TTreeNode): TProtocolPosition;
    function SelectedPosition: TProtocolPosition;
    procedure SelectPosition(const APosition: TProtocolPosition);
    procedure RebuildTree(const ASelect: TProtocolPosition);
    procedure UpdateControls;
    procedure Changed(const ASelect: TProtocolPosition);
    procedure EditNode(const APosition: TProtocolPosition);
    function ConfirmSaveChanges: Boolean;
    function SaveProtocol: Boolean;
    procedure ClearProtocol;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCaptions(AIni: TCustomIniFile);
    // Открывает протокол из файла (без вопросов); при ошибке остаётся прежний.
    function OpenFile(const AFileName: string; out AErrorText: string): Boolean;
    // Вопрос о несохранённых изменениях перед закрытием программы.
    function CanCloseFromHost: Boolean;
  end;

implementation

{$R *.lfm}

uses
  AppPaths, UOperationForm, UBlockNameForm;

const
  CAPTIONS_SECTION = 'Protocol';

constructor TProtocolForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FModel := TProtocolModel.Create;
  TV_Protocol.Options := TV_Protocol.Options + [tvoNoDoubleClickExpand];
  UpdateControls;
end;

destructor TProtocolForm.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

procedure TProtocolForm.ApplyCaptions(AIni: TCustomIniFile);
begin
  FCaptions := AIni;
  B_New.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_NewProtocol', 'Создать');
  B_Open.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_LoadProtocolLayer', 'Открыть');
  B_Save.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_SaveProtocolLayer', 'Сохранить');
  B_AddBlock.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_AddBlockInProtocol', 'Добавить блок');
  B_AddOperation.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_AddOperInProtocol', 'Добавить операцию');
  B_Delete.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_RemoveNode', 'Удалить');
  B_MoveUp.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_MoveNodeUp', 'Вверх');
  B_MoveDown.Caption := AIni.ReadString(CAPTIONS_SECTION, 'B_MoveNodeDown', 'Вниз');
  UpdateControls;
end;

function TProtocolForm.PositionOfNode(ANode: TTreeNode): TProtocolPosition;
// Узлы: блок, его операция, параметр операции SyrSt (относится к операции)
begin
  Result := NoPosition;
  if ANode = nil then
    Exit;
  case ANode.Level of
    0: Result := BlockPosition(ANode.Index);
    1: Result := StepPosition(ANode.Parent.Index, ANode.Index);
    2: Result := StepPosition(ANode.Parent.Parent.Index, ANode.Parent.Index);
  end;
end;

function TProtocolForm.SelectedPosition: TProtocolPosition;
begin
  Result := PositionOfNode(TV_Protocol.Selected);
  if not PositionExists(FModel, Result) then
    Result := NoPosition;
end;

procedure TProtocolForm.SelectPosition(const APosition: TProtocolPosition);
var
  Node: TTreeNode;
  I: Integer;
begin
  TV_Protocol.Selected := nil;
  if IsNoPosition(APosition) then
    Exit;
  Node := TV_Protocol.Items.GetFirstNode;
  for I := 1 to APosition.Block do
    if Node <> nil then
      Node := Node.GetNextSibling;
  if (Node <> nil) and (APosition.Step >= 0) then
  begin
    Node := Node.GetFirstChild;
    for I := 1 to APosition.Step do
      if Node <> nil then
        Node := Node.GetNextSibling;
  end;
  TV_Protocol.Selected := Node;
end;

procedure TProtocolForm.RebuildTree(const ASelect: TProtocolPosition);
// Верхний уровень - блоки, под ними операции; у SyrSt ниже её параметры.
// Узел показывает строку файла, как раньше.
var
  B, S, I: Integer;
  BlockNode, StepNode: TTreeNode;
  Lines: TStringArray;
begin
  TV_Protocol.Items.BeginUpdate;
  try
    TV_Protocol.Items.Clear;
    for B := 0 to FModel.BlockCount - 1 do
    begin
      BlockNode := TV_Protocol.Items.Add(nil, KEY_BLOCK + '=' +
        FModel.BlockNames[B] + ';');
      for S := 0 to FModel.StepCount(B) - 1 do
      begin
        Lines := Trim(ProtocolStepToText(FModel.Steps[B, S], 0)).Split(LineEnding);
        StepNode := TV_Protocol.Items.AddChild(BlockNode, Trim(Lines[0]));
        for I := 1 to High(Lines) do
          // Split делит по каждому из символов #13 и #10: между ними пустые
          if Trim(Lines[I]) <> '' then
            TV_Protocol.Items.AddChild(StepNode, Trim(Lines[I]));
      end;
    end;
  finally
    TV_Protocol.Items.EndUpdate;
  end;
  TV_Protocol.FullExpand;
  SelectPosition(ASelect);
  UpdateControls;
end;

procedure TProtocolForm.UpdateControls;
var
  Selected: TProtocolPosition;
  StatusText: string;
begin
  Selected := SelectedPosition;
  B_Delete.Enabled := not IsNoPosition(Selected);
  B_MoveUp.Enabled := CanMoveUp(FModel, Selected);
  B_MoveDown.Enabled := CanMoveDown(FModel, Selected);
  B_Save.Enabled := FModified or ((FFileName = '') and (FModel.BlockCount > 0));

  if FFileName <> '' then
    StatusText := ExtractFileName(FFileName)
  else
    StatusText := 'Протокол без файла';
  if FModified then
    StatusText := StatusText + ' (изменён)';
  L_File.Caption := StatusText;
  L_File.Hint := FFileName;
  L_File.ShowHint := FFileName <> '';
end;

procedure TProtocolForm.Changed(const ASelect: TProtocolPosition);
begin
  FModified := True;
  RebuildTree(ASelect);
end;

procedure TProtocolForm.TV_ProtocolSelectionChanged(Sender: TObject);
begin
  UpdateControls;
end;

procedure TProtocolForm.EditNode(const APosition: TProtocolPosition);
var
  BlockText: string;
  Step: TProtocolStep;
begin
  if IsBlockPosition(APosition) then
  begin
    BlockText := FModel.BlockNames[APosition.Block];
    if not EditBlockName('Изменение блока', BlockText, FCaptions) then
      Exit;
    FModel.RenameBlock(APosition.Block, BlockText);
  end
  else
  begin
    Step := FModel.Steps[APosition.Block, APosition.Step];
    if not EditOperation('Изменение операции', ALL_OPERATION_KINDS, Step,
      FCaptions) then
      Exit;
    FModel.ReplaceStep(APosition.Block, APosition.Step, Step);
  end;
  Changed(APosition);
end;

procedure TProtocolForm.TV_ProtocolDblClick(Sender: TObject);
// Двойной щелчок по узлу блока, операции или её параметра открывает окно
var
  Point: TPoint;
  NodePosition: TProtocolPosition;
begin
  Point := TV_Protocol.ScreenToClient(Mouse.CursorPos);
  NodePosition := PositionOfNode(TV_Protocol.GetNodeAt(Point.X, Point.Y));
  if PositionExists(FModel, NodePosition) then
    EditNode(NodePosition);
end;

procedure TProtocolForm.B_AddBlockClick(Sender: TObject);
var
  BlockText: string;
begin
  BlockText := 'BlockName';
  if EditBlockName('', BlockText, FCaptions) then
    Changed(InsertBlockAfter(FModel, SelectedPosition, BlockText));
end;

procedure TProtocolForm.B_AddOperationClick(Sender: TObject);
var
  Step: TProtocolStep;
  NewPosition: TProtocolPosition;
  ErrorText: string;
begin
  if FModel.BlockCount = 0 then
  begin
    ShowMessage('Сначала добавьте блок: операции находятся внутри блоков.');
    Exit;
  end;
  Step := DefaultOperation(pskSyringe);
  if not EditOperation('', ALL_OPERATION_KINDS, Step, FCaptions) then
    Exit;
  if InsertStepAfter(FModel, SelectedPosition, Step, NewPosition, ErrorText) then
    Changed(NewPosition)
  else
    ShowMessage(ErrorText);
end;

procedure TProtocolForm.B_DeleteClick(Sender: TObject);
var
  NodePosition: TProtocolPosition;
  Question: string;
begin
  NodePosition := SelectedPosition;
  if IsNoPosition(NodePosition) then
  begin
    ShowMessage('Выделите блок или операцию.');
    Exit;
  end;
  if IsBlockPosition(NodePosition) then
    Question := 'Удалить блок "' + FModel.BlockNames[NodePosition.Block] +
      '" и все его операции (' + IntToStr(FModel.StepCount(NodePosition.Block)) +
      ')?'
  else
    Question := 'Удалить операцию "' +
      Trim(ProtocolStepToText(FModel.Steps[NodePosition.Block, NodePosition.Step], 0)
      .Split(LineEnding)[0]) + '"?';
  if MessageDlg(Question, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  Changed(DeleteAt(FModel, NodePosition));
end;

procedure TProtocolForm.B_MoveUpClick(Sender: TObject);
begin
  Changed(MoveUp(FModel, SelectedPosition));
end;

procedure TProtocolForm.B_MoveDownClick(Sender: TObject);
begin
  Changed(MoveDown(FModel, SelectedPosition));
end;

function TProtocolForm.SaveProtocol: Boolean;
var
  FileName, ErrorText: string;
begin
  Result := False;
  FileName := FFileName;
  if FileName = '' then
  begin
    ForceDirectories(ProtocolsDir);
    SD_File.Filter := 'Протокол|*.pro';
    SD_File.DefaultExt := 'pro';
    SD_File.InitialDir := ProtocolsDir;
    SD_File.FileName := '';
    if not SD_File.Execute then
      Exit;
    FileName := SD_File.FileName;
  end;
  if not FModel.SaveToFile(FileName, ErrorText) then
  begin
    MessageDlg(ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  FFileName := ExpandFileName(FileName);
  FModified := False;
  UpdateControls;
  Result := True;
end;

function TProtocolForm.ConfirmSaveChanges: Boolean;
// True - можно продолжать: изменений нет, их сохранили или от них отказались.
begin
  Result := True;
  if not FModified then
    Exit;
  case MessageDlg('Протокол изменён. Сохранить изменения?', mtConfirmation,
    [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SaveProtocol;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

procedure TProtocolForm.ClearProtocol;
begin
  FModel.Clear;
  FFileName := '';
  FModified := False;
  RebuildTree(NoPosition);
end;

procedure TProtocolForm.B_NewClick(Sender: TObject);
begin
  if ConfirmSaveChanges then
    ClearProtocol;
end;

procedure TProtocolForm.B_OpenClick(Sender: TObject);
var
  ErrorText: string;
begin
  if not ConfirmSaveChanges then
    Exit;
  ForceDirectories(ProtocolsDir);
  OD_File.Filter := 'Протокол|*.pro';
  OD_File.InitialDir := ProtocolsDir;
  OD_File.FilterIndex := 1;
  OD_File.FileName := '';
  if not OD_File.Execute then
    Exit;
  if not OpenFile(OD_File.FileName, ErrorText) then
    MessageDlg(ErrorText, mtError, [mbOK], 0);
end;

function TProtocolForm.OpenFile(const AFileName: string;
  out AErrorText: string): Boolean;
begin
  Result := FModel.LoadFromFile(AFileName, AErrorText);
  if not Result then
    Exit;
  FFileName := ExpandFileName(AFileName);
  FModified := False;
  RebuildTree(NoPosition);
end;

procedure TProtocolForm.B_SaveClick(Sender: TObject);
begin
  SaveProtocol;
end;

function TProtocolForm.CanCloseFromHost: Boolean;
begin
  Result := ConfirmSaveChanges;
end;

end.
