program LightOligo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, tachartlazaruspkg, lazcontrols, UMainForm, EzCadApi, UMatrixForm,
  UOligoArrayForm, MyGlobals, ULayerChartForm, ULaserPenForm, UProtocolBlockForm,
  UProtocolOperationForm, SynthesisThread
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TMatrixForm, MatrixForm);
  Application.CreateForm(TOligoArrayForm, OligoArrayForm);
  Application.CreateForm(TLayerChartForm, LayerChartForm);
  Application.CreateForm(TLaserPenForm, LaserPenForm);
  Application.CreateForm(TProtocolBlockForm, ProtocolBlockForm);
  Application.CreateForm(TProtocolOperationForm, ProtocolOperationForm);
  Application.Run;
end.

