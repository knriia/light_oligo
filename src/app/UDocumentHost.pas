unit UDocumentHost;
// Хост документов: полоса вкладок с крестиками. Формы создаются один раз и
// живут всё время; вкладка появляется, когда форму открывают, а закрытие
// вкладки только прячет форму (она переезжает в скрытый контейнер), поэтому
// состояние формы и работа в фоне (синтез, станция) вкладкой не прерываются.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls;

type
  // Можно ли закрыть вкладку (например, спросить о сохранении).
  TDocumentCanCloseEvent = function: Boolean of object;

  TDocumentEntry = record
    Form: TForm;
    Caption: string;
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
    procedure CloseTabClicked(Sender: TObject);
  public
    // APages - полоса вкладок; AHolder - невидимый контейнер для форм
    // без вкладки.
    constructor Create(APages: TPageControl; AHolder: TWinControl);
    // Запоминает форму и подпись её вкладки; форма уходит в контейнер.
    procedure Register(AForm: TForm; const ACaption: string;
      ACanClose: TDocumentCanCloseEvent);
    // Показывает вкладку формы (создаёт, если закрыта) и делает активной.
    procedure Open(AForm: TForm);
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
  FPages.Options := FPages.Options + [nboShowCloseButtons];
  FPages.OnCloseTabClicked := @CloseTabClicked;
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
    FEntries[I].Sheet.Caption := FEntries[I].Caption;
    FEntries[I].Sheet.PageControl := FPages;
    AForm.Parent := FEntries[I].Sheet;
    AForm.Align := alClient;
    AForm.Show;
  end;
  FPages.ActivePage := FEntries[I].Sheet;
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

procedure TDocumentHost.CloseTabClicked(Sender: TObject);
var
  I: Integer;
begin
  if not (Sender is TTabSheet) then
    Exit;
  I := IndexOfSheet(TTabSheet(Sender));
  if I >= 0 then
    Close(FEntries[I].Form);
end;

end.
