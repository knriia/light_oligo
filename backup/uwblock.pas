unit UWBlock;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons,
  ExtCtrls, MyGlobals;

type

  { TForm6 }

  TForm6 = class(TForm)
    BB_Ok: TBitBtn;
    BB_Cancel: TBitBtn;
    LE_String: TLabeledEdit;
    procedure BB_OkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form6: TForm6;

implementation
uses UMain;
{$R *.lfm}

{ TForm6 }

procedure TForm6.FormCreate(Sender: TObject);
begin
  Form6.Caption:=MyInterface.ReadString('AddBlock','Form6','AddBlock');
  LE_String.EditLabel.Caption:=MyInterface.ReadString('AddBlock','LE_String','Add BlockName');
  BB_Cancel.Caption:=MyInterface.ReadString('AddBlock','BB_Cancel','Cancel');
  BB_Ok.Caption:=MyInterface.ReadString('AddBlock','BB_Ok','OK');

  LE_String.Text:=MyIni.ReadString('Program','LE_String','BlockName');
end;

procedure TForm6.BB_OkClick(Sender: TObject);
begin
   MyBlockName:=LE_String.Text;
   ModalResult:=mrOk;
end;


end.

