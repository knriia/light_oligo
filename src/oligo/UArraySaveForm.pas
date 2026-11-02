unit UArraySaveForm;
// Окно сохранения массива олигов: папка (можно выбрать любую) и имя файла.
// Папки может ещё не быть - её создаст сохранение.

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
    E_FileName: TEdit;
    E_Folder: TEdit;
    L_Ext: TLabel;
    L_FileName: TLabel;
    L_Folder: TLabel;
    SDD_Folder: TSelectDirectoryDialog;
    procedure B_BrowseClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FFilePath: string;
  public
    constructor Create(TheOwner: TComponent); override;
    // Показывает окно с AFolder и AFileName. True - нажали «Сохранить»
    // и путь допустим: тогда в параметрах введённые значения, а в
    // AFilePath - полный путь к .csv. При отмене параметры не меняются.
    class function Execute(var AFolder, AFileName: string;
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
  Caption:='Сохранение массива олигов';
  L_Folder.Caption:='Папка:';
  L_FileName.Caption:='Имя файла:';
  L_Ext.Caption:=ARRAY_EXT;
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
// «Сохранить» закрывает окно только при допустимых папке и имени
var
  ErrorText: string;
begin
  if ModalResult<>mrOK then
    Exit;
  CanClose:=MakeFilePathInFolder(E_Folder.Text, E_FileName.Text, ARRAY_EXT,
    FFilePath, ErrorText);
  if not CanClose then
    ShowMessage(ErrorText);
end;

class function TArraySaveForm.Execute(var AFolder, AFileName: string;
  out AFilePath: string): Boolean;
var
  Form: TArraySaveForm;
begin
  AFilePath:='';
  Form:=TArraySaveForm.Create(nil);
  try
    Form.E_Folder.Text:=AFolder;
    Form.E_FileName.Text:=AFileName;
    Result:=Form.ShowModal=mrOK;
    if Result then
    begin
      AFolder:=Trim(Form.E_Folder.Text);
      AFileName:=Trim(Form.E_FileName.Text);
      AFilePath:=Form.FFilePath;
    end;
  finally
    Form.Free;
  end;
end;

end.
