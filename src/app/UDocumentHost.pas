unit UDocumentHost;
// Хост документов: полоса вкладок с крестиками. Формы создаются один раз и
// живут всё время; вкладка появляется, когда форму открывают, а закрытие
// вкладки только прячет форму (она переезжает в скрытый контейнер), поэтому
// состояние формы и работа в фоне (синтез, станция) вкладкой не прерываются.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, StdCtrls, Graphics, Types;

const
  CLOSE_MARK = '×';
  CLOSE_CLICK_WIDTH = 22; // ширина зоны крестика у правого края вкладки, px
  CLOSE_HOVER_COLOR = $004040D8;  // фон крестика под курсором (BGR)
  CLOSE_HOVER_INSET = 2;          // отступ метки крестика от краёв вкладки, px

type
  // Можно ли закрыть вкладку (например, спросить о сохранении).
  TDocumentCanCloseEvent = function: Boolean of object;

  TDocumentEntry = record
    Form: TForm;
    Caption: string;
    Modified: Boolean;                 // перед подписью вкладки - звёздочка
    CanClose: TDocumentCanCloseEvent;  // nil - закрывается без вопросов
    Sheet: TTabSheet;                  // nil - вкладка закрыта
  end;

  { TDocumentHost }

  TDocumentHost = class
  private
    FPages: TPageControl;
    FHolder: TWinControl;
    FEntries: array of TDocumentEntry;
    FHoverMark: TLabel;  // подсвеченный крестик поверх вкладки под курсором
    FHoverTab: Integer;  // вкладка, над крестиком которой курсор; -1 - нет
    function IndexOfForm(AForm: TForm): Integer;
    function IndexOfSheet(ASheet: TTabSheet): Integer;
    function TabText(const AEntry: TDocumentEntry): string;
    function CloseZoneTab(X, Y: Integer): Integer;
    procedure HoverMarkClick(Sender: TObject);
    procedure HoverMarkMouseLeave(Sender: TObject);
    procedure ShowHoverMark(ATab: Integer);
    procedure PagesMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PagesMouseLeave(Sender: TObject);
    procedure PagesMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  public
    // APages - полоса вкладок; AHolder - невидимый контейнер для форм
    // без вкладки.
    constructor Create(APages: TPageControl; AHolder: TWinControl);
    // Запоминает форму и подпись её вкладки; форма уходит в контейнер.
    procedure Register(AForm: TForm; const ACaption: string;
      ACanClose: TDocumentCanCloseEvent);
    // Показывает вкладку формы (создаёт, если закрыта) и делает активной.
    procedure Open(AForm: TForm);
    // Меняет подпись вкладки формы и признак изменений (звёздочка перед
    // подписью); у открытой вкладки - сразу.
    procedure SetCaption(AForm: TForm; const ACaption: string;
      AModified: Boolean = False);
    // Закрывает вкладку, если CanClose разрешает. True - вкладки нет.
    function Close(AForm: TForm): Boolean;
    function IsOpen(AForm: TForm): Boolean;
    // Форма активной вкладки; nil - вкладок нет.
    function ActiveForm: TForm;
  end;

implementation

constructor TDocumentHost.Create(APages: TPageControl; AHolder: TWinControl);
begin
  inherited Create;
  FPages := APages;
  FHolder := AHolder;
  // Win32 не рисует крестики у вкладок: крестик - символ в подписи, клик по
  // нему обрабатывается здесь
  FPages.OnMouseDown := @PagesMouseDown;
  // Win32 не даёт перерисовать вкладку: при наведении на крестик поверх него
  // показывается подсвеченная метка, она же и закрывает вкладку
  FHoverTab := -1;
  FHoverMark := TLabel.Create(FPages);
  FHoverMark.Parent := FPages;
  FHoverMark.AutoSize := False;
  FHoverMark.Alignment := taCenter;
  FHoverMark.Layout := tlCenter;
  FHoverMark.Caption := CLOSE_MARK;
  FHoverMark.Transparent := False;
  FHoverMark.Color := CLOSE_HOVER_COLOR;
  FHoverMark.Font.Color := clWhite;
  FHoverMark.Cursor := crHandPoint;
  FHoverMark.Visible := False;
  FHoverMark.OnClick := @HoverMarkClick;
  FHoverMark.OnMouseLeave := @HoverMarkMouseLeave;
  FPages.OnMouseMove := @PagesMouseMove;
  FPages.OnMouseLeave := @PagesMouseLeave;
end;

function TDocumentHost.TabText(const AEntry: TDocumentEntry): string;
begin
  Result := AEntry.Caption;
  if AEntry.Modified then
    Result := '*' + Result;
  Result := Result + '  ' + CLOSE_MARK;
end;

function TDocumentHost.IndexOfForm(AForm: TForm): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FEntries) do
    if FEntries[I].Form = AForm then
      Exit(I);
end;

function TDocumentHost.IndexOfSheet(ASheet: TTabSheet): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FEntries) do
    if FEntries[I].Sheet = ASheet then
      Exit(I);
end;

procedure TDocumentHost.Register(AForm: TForm; const ACaption: string;
  ACanClose: TDocumentCanCloseEvent);
var
  N: Integer;
begin
  N := Length(FEntries);
  SetLength(FEntries, N + 1);
  FEntries[N].Form := AForm;
  FEntries[N].Caption := ACaption;
  FEntries[N].Modified := False;
  FEntries[N].CanClose := ACanClose;
  FEntries[N].Sheet := nil;
  AForm.BorderStyle := bsNone;
  AForm.Parent := FHolder;
end;

procedure TDocumentHost.Open(AForm: TForm);
var
  I: Integer;
begin
  I := IndexOfForm(AForm);
  if I < 0 then
    Exit;
  if FEntries[I].Sheet = nil then
  begin
    FEntries[I].Sheet := TTabSheet.Create(FPages);
    FEntries[I].Sheet.Caption := TabText(FEntries[I]);
    FEntries[I].Sheet.PageControl := FPages;
    AForm.Parent := FEntries[I].Sheet;
    AForm.Align := alClient;
    AForm.Show;
  end;
  FPages.ActivePage := FEntries[I].Sheet;
end;

procedure TDocumentHost.SetCaption(AForm: TForm; const ACaption: string;
  AModified: Boolean);
var
  I: Integer;
begin
  I := IndexOfForm(AForm);
  if I < 0 then
    Exit;
  FEntries[I].Caption := ACaption;
  FEntries[I].Modified := AModified;
  if (FEntries[I].Sheet <> nil) and
     (FEntries[I].Sheet.Caption <> TabText(FEntries[I])) then
    FEntries[I].Sheet.Caption := TabText(FEntries[I]);
  // ширина вкладки могла измениться: метка крестика на новое место
  if FHoverTab >= 0 then
    ShowHoverMark(FHoverTab);
end;

function TDocumentHost.Close(AForm: TForm): Boolean;
var
  I: Integer;
  Sheet: TTabSheet;
begin
  I := IndexOfForm(AForm);
  Result := True;
  if (I < 0) or (FEntries[I].Sheet = nil) then
    Exit;
  if Assigned(FEntries[I].CanClose) and not FEntries[I].CanClose() then
    Exit(False);
  Sheet := FEntries[I].Sheet;
  FEntries[I].Sheet := nil;
  ShowHoverMark(-1);
  AForm.Hide;
  AForm.Parent := FHolder;
  Sheet.Free;
end;

function TDocumentHost.IsOpen(AForm: TForm): Boolean;
var
  I: Integer;
begin
  I := IndexOfForm(AForm);
  Result := (I >= 0) and (FEntries[I].Sheet <> nil);
end;

function TDocumentHost.ActiveForm: TForm;
var
  I: Integer;
begin
  Result := nil;
  if FPages.ActivePage = nil then
    Exit;
  I := IndexOfSheet(FPages.ActivePage as TTabSheet);
  if I >= 0 then
    Result := FEntries[I].Form;
end;

function TDocumentHost.CloseZoneTab(X, Y: Integer): Integer;
// вкладка, у крестика которой курсор; -1 - курсор не над крестиком
var
  R: TRect;
begin
  Result := FPages.IndexOfTabAt(X, Y);
  if Result < 0 then
    Exit;
  R := FPages.TabRect(Result);
  if X < R.Right - CLOSE_CLICK_WIDTH then
    Result := -1;
end;

procedure TDocumentHost.ShowHoverMark(ATab: Integer);
var
  R: TRect;
begin
  FHoverTab := ATab;
  if ATab < 0 then
  begin
    FHoverMark.Visible := False;
    Exit;
  end;
  R := FPages.TabRect(ATab);
  FHoverMark.SetBounds(R.Right - CLOSE_CLICK_WIDTH, R.Top + CLOSE_HOVER_INSET,
    CLOSE_CLICK_WIDTH - CLOSE_HOVER_INSET, R.Bottom - R.Top - 2 * CLOSE_HOVER_INSET);
  FHoverMark.Visible := True;
  FHoverMark.BringToFront;
end;

procedure TDocumentHost.PagesMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Tab: Integer;
begin
  Tab := CloseZoneTab(X, Y);
  if Tab <> FHoverTab then
    ShowHoverMark(Tab);
end;

procedure TDocumentHost.PagesMouseLeave(Sender: TObject);
// курсор ушёл с полосы вкладок; на метку он мог просто перейти
var
  P: TPoint;
begin
  P := FHoverMark.ScreenToClient(Mouse.CursorPos);
  if not FHoverMark.Visible or not PtInRect(FHoverMark.ClientRect, P) then
    ShowHoverMark(-1);
end;

procedure TDocumentHost.HoverMarkMouseLeave(Sender: TObject);
var
  P: TPoint;
begin
  P := FPages.ScreenToClient(Mouse.CursorPos);
  if CloseZoneTab(P.X, P.Y) <> FHoverTab then
    ShowHoverMark(-1);
end;

procedure TDocumentHost.HoverMarkClick(Sender: TObject);
var
  I, Tab: Integer;
begin
  Tab := FHoverTab;
  ShowHoverMark(-1);
  if (Tab < 0) or (Tab >= FPages.PageCount) then
    Exit;
  I := IndexOfSheet(FPages.Pages[Tab]);
  if I >= 0 then
    Close(FEntries[I].Form);
end;

procedure TDocumentHost.PagesMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
// крестик - правый край вкладки; средняя кнопка закрывает вкладку целиком
var
  Tab, I: Integer;
  R: TRect;
begin
  Tab := FPages.IndexOfTabAt(X, Y);
  if Tab < 0 then
    Exit;
  R := FPages.TabRect(Tab);
  if not ((Button = mbMiddle) or
          ((Button = mbLeft) and (X >= R.Right - CLOSE_CLICK_WIDTH))) then
    Exit;
  I := IndexOfSheet(FPages.Pages[Tab]);
  if I >= 0 then
    Close(FEntries[I].Form);
end;

end.
