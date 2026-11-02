unit UFolderForm;
// Окно выбора папки: путь можно вписать или выбрать через «Обзор…».
// Папки может ещё не быть - её создаст вызывающий код.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls;

type

  { TFolderForm }

  TFolderForm = class(TForm)
    B_Browse: TButton;
    B_Cancel: TButton;
    B_OK: TButton;
    E_Folder: TEdit;
    L_Prompt: TLabel;
    SDD_Folder: TSelectDirectoryDialog;
    procedure B_BrowseClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor Create(TheOwner: TComponent); override;
    // True - нажали OK и путь допустим (полный, без недопустимых символов);
    // тогда AFolder - введённая папка без завершающего разделителя.
    // При отмене AFolder не меняется.
    class function Execute(const ACaption, APrompt: string;
      var AFolder: string): Boolean;
  end;

implementation

uses
  AppPaths;

{$R *.lfm}

{ TFolderForm }

constructor TFolderForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  B_Browse.Caption:='Обзор…';
  B_OK.Caption:='OK';
  B_Cancel.Caption:='Отмена';
end;

procedure TFolderForm.B_BrowseClick(Sender: TObject);
// начинаем с ближайшей существующей папки из поля
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

procedure TFolderForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  ErrorText: string;
begin
  if ModalResult<>mrOK then
    Exit;
  CanClose:=CheckFolderPath(E_Folder.Text, ErrorText);
  if not CanClose then
    ShowMessage(ErrorText);
end;

class function TFolderForm.Execute(const ACaption, APrompt: string;
  var AFolder: string): Boolean;
var
  Form: TFolderForm;
begin
  Form:=TFolderForm.Create(nil);
  try
    Form.Caption:=ACaption;
    Form.L_Prompt.Caption:=APrompt;
    Form.E_Folder.Text:=AFolder;
    Result:=Form.ShowModal=mrOK;
    if Result then
      AFolder:=ExcludeTrailingPathDelimiter(Trim(Form.E_Folder.Text));
  finally
    Form.Free;
  end;
end;

end.
