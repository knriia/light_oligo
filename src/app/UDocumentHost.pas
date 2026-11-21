unit UDocumentHost;
// Хост документов: полоса вкладок с крестиками. Формы создаются один раз и
// живут всё время; вкладка появляется, когда форму открывают, а закрытие
// вкладки только прячет форму (она переезжает в скрытый контейнер), поэтому
// состояние формы и работа в фоне (синтез, станция) вкладкой не прерываются.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls;

const
  CLOSE_MARK = '×';
  CLOSE_CLICK_WIDTH = 22; // ширина зоны крестика у правого края вкладки, px

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
    function IndexOfForm(AForm: TForm): Integer;
    function IndexOfSheet(ASheet: TTabSheet): Integer;
    function TabText(const AEntry: TDocumentEntry): string;
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
