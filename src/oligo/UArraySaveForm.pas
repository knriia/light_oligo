unit UArraySaveForm;
// Окно сохранения проекта: папка проектов (можно выбрать любую) и имя проекта.
// CSV массива пишется в <папка проектов>\<имя проекта>\<имя проекта>.csv.
// Папки проекта может ещё не быть - её создаст сохранение.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls;

type

  { TArraySaveForm }

  TArraySaveForm = class(TForm)
    B_Browse: TButton;
    B_Cancel: TButton;
    B_Save: TButton;
    E_ArrayFile: TEdit;
    E_Folder: TEdit;
    E_Name: TEdit;
    L_ArrayFile: TLabel;
    L_Folder: TLabel;
    L_Name: TLabel;
    SDD_Folder: TSelectDirectoryDialog;
    procedure B_BrowseClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FFilePath: string;
  public
    constructor Create(TheOwner: TComponent); override;
    // Показывает окно с AFolder (папка проектов, проект лежит в <папка>\<имя>), AName (имя проекта) и
    // AArrayFile (имя файла последовательностей без расширения).
    // True - нажали «Сохранить» и путь допустим: тогда в параметрах введённые
    // значения, а в AFilePath - полный путь к .csv проекта.
    // При отмене параметры не меняются.
    class function Execute(var AFolder, AName, AArrayFile: string;
      out AFilePath: string): Boolean;
  end;

implementation

uses
  AppPaths;

{$R *.lfm}

const
  ARRAY_EXT = '.csv';

{ TArraySaveForm }

constructor TArraySaveForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  Caption:='Сохранение проекта';
  L_Folder.Caption:='Папка проектов:';
  L_Name.Caption:='Имя проекта:';
  L_ArrayFile.Caption:='Имя файла последовательностей:';
  B_Browse.Caption:='Обзор…';
  B_Save.Caption:='Сохранить';
  B_Cancel.Caption:='Отмена';
end;

procedure TArraySaveForm.B_BrowseClick(Sender: TObject);
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

procedure TArraySaveForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
// «Сохранить» закрывает окно только при допустимых папке и имени проекта
var
  ErrorText, ProjectName, ProjectFolder: string;
begin
  if ModalResult<>mrOK then
    Exit;
  ProjectName:=Trim(E_Name.Text);
  CanClose:=CheckFileNamePart(ProjectName, 'Имя проекта', ErrorText) and
    CheckFolderPath(E_Folder.Text, ErrorText);
  if CanClose then
  begin
    ProjectFolder:=IncludeTrailingPathDelimiter(
      ExcludeTrailingPathDelimiter(Trim(E_Folder.Text)))+ProjectName;
    CanClose:=MakeFilePathInFolder(ProjectFolder, E_ArrayFile.Text, ARRAY_EXT,
      FFilePath, ErrorText);
  end;
  if not CanClose then
    ShowMessage(ErrorText);
end;

class function TArraySaveForm.Execute(var AFolder, AName, AArrayFile: string;
  out AFilePath: string): Boolean;
var
  Form: TArraySaveForm;
begin
  AFilePath:='';
  Form:=TArraySaveForm.Create(nil);
  try
    Form.E_Folder.Text:=AFolder;
    Form.E_Name.Text:=AName;
    Form.E_ArrayFile.Text:=AArrayFile;
    Result:=Form.ShowModal=mrOK;
    if Result then
    begin
      AFolder:=Trim(Form.E_Folder.Text);
      AName:=Trim(Form.E_Name.Text);
      AArrayFile:=Trim(Form.E_ArrayFile.Text);
      AFilePath:=Form.FFilePath;
    end;
  finally
    Form.Free;
  end;
end;

end.
