unit UEzdProgressForm;
// Окно хода создания EZD-файлов: строка этапа и полоса прогресса. Окно
// без .lfm, показывается не модально; пока оно открыто, главное окно
// заблокировано, а сообщения обрабатываются в Report, чтобы приложение
// не выглядело зависшим.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls;

type

  { TEzdProgressForm }

  TEzdProgressForm = class(TForm)
  private
    FStage: TLabel;
    FBar: TProgressBar;
    FLockedForm: TForm;
  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Показывает окно и блокирует главное окно до Free.
    procedure Open;
    // ACurrent из ATotal шагов выполнено; AStage - текст над полосой.
    // Подходит как TEzdProgressEvent.
    procedure Report(ACurrent, ATotal: Integer; const AStage: string);
  end;

implementation

{ TEzdProgressForm }

constructor TEzdProgressForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Создание EZD-файлов';
  BorderStyle := bsDialog;
  BorderIcons := [];
  Position := poMainFormCenter;
  // окно того же владельца, что и сообщения MarkEzd.dll (MainFormHandle):
  // сообщение, показанное позже, лежит поверх окна прогресса
  if Assigned(Application.MainForm) then
    PopupParent := Application.MainForm;
  ClientWidth := 420;
  ClientHeight := 76;

  FStage := TLabel.Create(Self);
  FStage.Parent := Self;
  FStage.SetBounds(12, 10, ClientWidth - 24, 20);
  FStage.AutoSize := False;

  FBar := TProgressBar.Create(Self);
  FBar.Parent := Self;
  FBar.SetBounds(12, 38, ClientWidth - 24, 24);
  FBar.Min := 0;
  FBar.Max := 1;
end;

destructor TEzdProgressForm.Destroy;
begin
  Hide;
  if Assigned(FLockedForm) then
  begin
    FLockedForm.Enabled := True;
    FLockedForm.SetFocus;
  end;
  inherited Destroy;
end;

procedure TEzdProgressForm.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FLockedForm) then
    FLockedForm := nil;
end;

procedure TEzdProgressForm.Open;
begin
  if Assigned(Application.MainForm) and Application.MainForm.Enabled then
  begin
    FLockedForm := Application.MainForm;
    FLockedForm.FreeNotification(Self);
    FLockedForm.Enabled := False;
  end;
  Show;
  Update;
  Application.ProcessMessages;
end;

procedure TEzdProgressForm.Report(ACurrent, ATotal: Integer;
  const AStage: string);
begin
  if ATotal < 1 then
    ATotal := 1;
  FBar.Max := ATotal;
  FBar.Position := ACurrent;
  FStage.Caption := AStage;
  Update;
  Application.ProcessMessages;
end;

end.
