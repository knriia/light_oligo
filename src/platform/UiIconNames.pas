unit UiIconNames;
// Имена значков из набора UiIcons (файл icons\<размер>\<имя>.png) и пути к
// файлам. Без LCL, поэтому проверяется в platform_tests.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

const
  ICON_NEW = 'new';
  ICON_OPEN = 'open';
  ICON_SAVE = 'save';
  ICON_SAVE_AS = 'save_as';
  ICON_CLOSE = 'close';
  ICON_ADD = 'add';
  ICON_DELETE = 'delete';
  ICON_EDIT = 'edit';
  ICON_REFRESH = 'refresh';
  ICON_SETTINGS = 'settings';
  ICON_RUN = 'run';
  ICON_STOP = 'stop';
  ICON_PAUSE = 'pause';
  ICON_CANCEL = 'cancel';
  ICON_OK = 'ok';
  ICON_EXIT = 'exit';
  ICON_FOLDER = 'folder';
  ICON_INFO = 'info';
  ICON_EXPORT = 'export';
  ICON_UP = 'up';
  ICON_DOWN = 'down';
  ICON_PROJECT_NEW = 'project_new';
  ICON_PROJECT_OPEN = 'project_open';

  ICON_COUNT = 23;

  ICON_ALL: array[0..ICON_COUNT - 1] of string = (
    ICON_NEW, ICON_OPEN, ICON_SAVE, ICON_SAVE_AS, ICON_CLOSE, ICON_ADD,
    ICON_DELETE, ICON_EDIT, ICON_REFRESH, ICON_SETTINGS, ICON_RUN, ICON_STOP,
    ICON_PAUSE, ICON_CANCEL, ICON_OK, ICON_EXIT, ICON_FOLDER, ICON_INFO,
    ICON_EXPORT, ICON_UP, ICON_DOWN, ICON_PROJECT_NEW, ICON_PROJECT_OPEN);

// Папка с PNG одного размера, с завершающим разделителем. Пустой AIconsRoot -
// папка icons рядом с exe.
function IconsDir(ASize: Integer; const AIconsRoot: string = ''): string;

// Индекс значка в списке, созданном UiIcons.CreateIconList; -1, если имени нет.
function IconIndex(const AName: string): Integer;

implementation

uses
  SysUtils, AppPaths;

function IconsDir(ASize: Integer; const AIconsRoot: string): string;
var
  Root: string;
begin
  Root := AIconsRoot;
  if Root = '' then
    Root := AppDir + 'icons';
  Result := IncludeTrailingPathDelimiter(Root) + IntToStr(ASize) + PathDelim;
end;

function IconIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := Low(ICON_ALL) to High(ICON_ALL) do
    if ICON_ALL[I] = AName then
      Exit(I);
  Result := -1;
end;

end.
