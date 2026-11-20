unit UiFont;
// Единый шрифт окон (см. UiTheme).

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

// Ставит шрифт UI_FONT_NAME / UI_FONT_SIZE каждому окну сразу после создания.
// Вызвать один раз при старте, после Application.Initialize и до создания окон.
// Повторный вызов ничего не меняет. Окно создаётся раньше, чем читается его
// .lfm, поэтому значения шрифта из .lfm и элементы с ParentFont = False
// остаются приоритетнее.
procedure InstallUiFont;

implementation

uses
  Classes, Forms, UiTheme;

type
  TUiFontHook = class
    procedure FormAdded(Sender: TObject; Form: TCustomForm);
  end;

var
  Hook: TUiFontHook = nil;

procedure TUiFontHook.FormAdded(Sender: TObject; Form: TCustomForm);
begin
  Form.Font.Name := UI_FONT_NAME;
  Form.Font.Size := UI_FONT_SIZE;
end;

procedure InstallUiFont;
begin
  if Hook <> nil then
    Exit;
  Hook := TUiFontHook.Create;
  Screen.AddHandlerFormAdded(@Hook.FormAdded);
end;

finalization
  if Hook <> nil then
  begin
    if Assigned(Screen) then
      Screen.RemoveHandlerFormAdded(@Hook.FormAdded);
    Hook.Free;
  end;

end.
