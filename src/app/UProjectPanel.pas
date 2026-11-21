unit UProjectPanel;
// Панель менеджера проекта: дерево открытых проектов (у каждого массив,
// слайсинги и их синтезы). Проект в дереве и есть открытый; проектов может быть
// несколько. Строки дерева берутся из ProjectNodes, панель сама ничего не
// открывает, а сообщает о двойном щелчке через OnOpenItem.
// Раздел «Протоколы» добавится, когда протоколы можно будет открывать из дерева.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, ExtCtrls, ComCtrls, Menus,
  ProjectModel;

type
  TProjectItemEvent = procedure(AKind: TProjectNodeKind;
    const APath: string) of object;

  TProjectTreeItem = record
    Kind: TProjectNodeKind;
    Path: string;
    ProjectIndex: Integer;
  end;

  { TProjectPanel }

  TProjectPanel = class(TPanel)
  private
    FTree: TTreeView;
    FProjects: array of TProject;
    FItems: array of TProjectTreeItem;  // строки дерева; в Node.Data - индекс + 1
    FOnOpenItem: TProjectItemEvent;
    function GetProjectCount: Integer;
    function GetProject(AIndex: Integer): TProject;
    function IndexOfProjectDir(const ADir: string): Integer;
    procedure Rebuild;
    procedure SelectProject(AIndex: Integer);
    procedure TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SetTreeMenu(AValue: TPopupMenu);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Добавляет открытый проект; панель становится его владельцем. Если проект
    // с такой папкой уже в дереве, AProject освобождается, а в дереве
    // выделяется прежний.
    procedure AddProject(AProject: TProject);
    // Убирает проект из дерева (на диске ничего не меняется).
    procedure RemoveProject(AIndex: Integer);
    // Перечитывает все проекты с диска и перестраивает дерево. Ошибка - False,
    // текст объясняет; проект с ошибкой остаётся прежним.
    function Refresh(out AErrorText: string): Boolean;
    // Индекс проекта выделенной строки дерева; -1 - ничего не выделено.
    function SelectedProjectIndex: Integer;
    property ProjectCount: Integer read GetProjectCount;
    property Projects[AIndex: Integer]: TProject read GetProject;
    // Контекстное меню дерева.
    property TreeMenu: TPopupMenu write SetTreeMenu;
    property OnOpenItem: TProjectItemEvent read FOnOpenItem write FOnOpenItem;
  end;

implementation

constructor TProjectPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.ReadOnly := True;
  // у корневых узлов (проекты) нет линий и значка раскрытия слева
  FTree.ShowRoot := False;
  FTree.HideSelection := False;
  FTree.OnCustomDrawItem := @TreeCustomDrawItem;
  FTree.OnDblClick := @TreeDblClick;
  FTree.OnMouseDown := @TreeMouseDown;
end;

destructor TProjectPanel.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FProjects) do
    FProjects[I].Free;
  inherited Destroy;
end;

procedure TProjectPanel.SetTreeMenu(AValue: TPopupMenu);
begin
  FTree.PopupMenu := AValue;
end;

function TProjectPanel.GetProjectCount: Integer;
begin
  Result := Length(FProjects);
end;

function TProjectPanel.GetProject(AIndex: Integer): TProject;
begin
  Result := FProjects[AIndex];
end;

function TProjectPanel.IndexOfProjectDir(const ADir: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FProjects) do
    if SameFileName(FProjects[I].Dir, ADir) then
      Exit(I);
end;

procedure TProjectPanel.AddProject(AProject: TProject);
var
  Index: Integer;
begin
  Index := IndexOfProjectDir(AProject.Dir);
  if Index >= 0 then
  begin
    AProject.Free;
    SelectProject(Index);
    Exit;
  end;
  SetLength(FProjects, Length(FProjects) + 1);
  FProjects[High(FProjects)] := AProject;
  Rebuild;
  SelectProject(High(FProjects));
end;

procedure TProjectPanel.RemoveProject(AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FProjects)) then
    Exit;
  FProjects[AIndex].Free;
  for I := AIndex to High(FProjects) - 1 do
    FProjects[I] := FProjects[I + 1];
  SetLength(FProjects, Length(FProjects) - 1);
  Rebuild;
end;

function TProjectPanel.Refresh(out AErrorText: string): Boolean;
var
  I: Integer;
  ProjectError: string;
begin
  AErrorText := '';
  for I := 0 to High(FProjects) do
    if not FProjects[I].Refresh(ProjectError) then
    begin
      if AErrorText <> '' then
        AErrorText := AErrorText + LineEnding;
      AErrorText := AErrorText + ProjectError;
    end;
  Result := AErrorText = '';
  Rebuild;
end;

procedure TProjectPanel.Rebuild;
// проект - корень; остальные узлы цепляются к последнему узлу уровнем выше
var
  Parents: array[0..2] of TTreeNode;
  Nodes: TProjectNodes;
  Node: TTreeNode;
  P, I, N: Integer;
begin
  FItems := nil;
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    for P := 0 to High(FProjects) do
    begin
      Nodes := ProjectNodes(FProjects[P]);
      for I := 0 to High(Nodes) do
      begin
        if Nodes[I].Level = 0 then
          Node := FTree.Items.Add(nil, Nodes[I].Caption)
        else
          Node := FTree.Items.AddChild(Parents[Nodes[I].Level - 1],
            Nodes[I].Caption);
        N := Length(FItems);
        SetLength(FItems, N + 1);
        FItems[N].Kind := Nodes[I].Kind;
        FItems[N].Path := Nodes[I].Path;
        FItems[N].ProjectIndex := P;
        Node.Data := Pointer(PtrInt(N + 1));
        Parents[Nodes[I].Level] := Node;
      end;
    end;
    FTree.FullExpand;
  finally
    FTree.Items.EndUpdate;
  end;
end;

procedure TProjectPanel.SelectProject(AIndex: Integer);
var
  I: Integer;
begin
  for I := 0 to FTree.Items.Count - 1 do
    if (FTree.Items[I].Level = 0) and
       (FItems[PtrInt(FTree.Items[I].Data) - 1].ProjectIndex = AIndex) then
    begin
      FTree.Selected := FTree.Items[I];
      Exit;
    end;
end;

function TProjectPanel.SelectedProjectIndex: Integer;
begin
  Result := -1;
  if (FTree.Selected <> nil) and (FTree.Selected.Data <> nil) then
    Result := FItems[PtrInt(FTree.Selected.Data) - 1].ProjectIndex;
end;

procedure TProjectPanel.TreeCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
// имя проекта (корень) жирным
begin
  if Node.Level = 0 then
    Sender.Canvas.Font.Style := [fsBold]
  else
    Sender.Canvas.Font.Style := [];
end;

procedure TProjectPanel.TreeDblClick(Sender: TObject);
var
  Node: TTreeNode;
  Index: Integer;
  Pos: TPoint;
begin
  Pos := FTree.ScreenToClient(Mouse.CursorPos);
  Node := FTree.GetNodeAt(Pos.X, Pos.Y);
  if (Node = nil) or (Node.Data = nil) then
    Exit;
  Index := PtrInt(Node.Data) - 1;
  if Assigned(FOnOpenItem) then
    FOnOpenItem(FItems[Index].Kind, FItems[Index].Path);
end;

procedure TProjectPanel.TreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
// правая кнопка выделяет узел под курсором, как в проводнике
var
  Node: TTreeNode;
begin
  if Button <> mbRight then
    Exit;
  Node := FTree.GetNodeAt(X, Y);
  if Node <> nil then
    FTree.Selected := Node;
end;

end.
