unit UProjectCreateForm;
// Окно создания проекта: папка проектов (можно выбрать любую) и имя проекта.
// Папки проекта может ещё не быть - её создаст CreateProject.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls;

type

  { TProjectCreateForm }

  TProjectCreateForm = class(TForm)
    B_Browse: TButton;
    B_Cancel: TButton;
    B_Create: TButton;
    E_Folder: TEdit;
    E_Name: TEdit;
    L_Folder: TLabel;
    L_Name: TLabel;
    SDD_Folder: TSelectDirectoryDialog;
    procedure B_BrowseClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor Create(TheOwner: TComponent); override;
    // Показывает окно с AFolder (папка проектов, проект лежит в <папка>\<имя>)
    // и AName (имя проекта). True - нажали «Создать» и папка с именем
    // допустимы: тогда в параметрах введённые значения. При отмене параметры
    // не меняются.
    class function ExecuteProject(var AFolder, AName: string): Boolean;
  end;

implementation

uses
  AppPaths;

{$R *.lfm}

{ TProjectCreateForm }

constructor TProjectCreateForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  Caption:='Создание проекта';
  L_Folder.Caption:='Папка проектов:';
  L_Name.Caption:='Имя проекта:';
  B_Browse.Caption:='Обзор…';
  B_Create.Caption:='Создать';
  B_Cancel.Caption:='Отмена';
end;

procedure TProjectCreateForm.B_BrowseClick(Sender: TObject);
// выбор папки; начинаем с ближайшей существующей папки из поля
var
  Dir: string;
begin
  Dir:=ExcludeTrailingPathDelimiter(Trim(E_Folder.Text));
  while (Dir<>'') and not DirectoryExists(Dir) and
        (ExtractFileDir(Dir)<>Dir) do
    Dir:=ExtractFileDir(Dir);
  SDD_Folder.InitialDir:=Dir;
  SDD_Folder.FileName:='';
  if SDD_Folder.Execute then
    E_Folder.Text:=SDD_Folder.FileName;
end;

procedure TProjectCreateForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
// «Создать» закрывает окно только при допустимых папке и имени проекта
var
  ErrorText: string;
begin
  if ModalResult<>mrOK then
    Exit;
  CanClose:=CheckFileNamePart(Trim(E_Name.Text), 'Имя проекта', ErrorText) and
    CheckFolderPath(E_Folder.Text, ErrorText);
  if not CanClose then
    ShowMessage(ErrorText);
end;

class function TProjectCreateForm.ExecuteProject(var AFolder, AName: string): Boolean;
var
  Form: TProjectCreateForm;
begin
  Form:=TProjectCreateForm.Create(nil);
  try
    Form.E_Folder.Text:=AFolder;
    Form.E_Name.Text:=AName;
    Result:=Form.ShowModal=mrOK;
    if Result then
    begin
      AFolder:=Trim(Form.E_Folder.Text);
      AName:=Trim(Form.E_Name.Text);
    end;
  finally
    Form.Free;
  end;
end;

end.
