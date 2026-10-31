unit SynthesisProtocol;
// Протокол синтеза для одной буквы: операции в том виде, в каком их
// выполняет поток синтеза, и загрузка файла .pro (формат - ProtocolFormat).

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ProtocolFormat;

type
  TDev = (dName, dSyrSt, dVac, dlaser, dPause);

type
  TOperRec = record // строчка записи в протоколе
    Func: TDev;   // тип устройств/записей
    StrParam: String; // строковый параметр
    IntParam: Integer; // Целочисленный параметр
    FloatParam: Double; // параметр числа с плав. запятой
    BoolParam: Boolean; // булевый параметр
    Syringe: TSyringeStep; // параметры подачи из шприцевой станции (dSyrSt)
  end;

  type
    TLayerProt = array of TOperRec; // протокол (последовательность строк) для буквы

// Загружает файл протокола и добавляет его операции в aProt.
// Возвращает 0 при успехе; подробности ошибки пишутся в aLog.
Function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String; aLog: TStrings): integer;

implementation

function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String; aLog: TStrings): integer;
var
  Lines: TStringList;
  Document: TProtocolDocument;
  ErrorText: String;
  b, s: Integer;
  Step: TProtocolStep;
  Rec: TOperRec;

  procedure AddRec(const ARec: TOperRec; const ALogText: String);
  begin
    SetLength(aProt, Length(aProt)+1);
    aProt[High(aProt)]:=ARec;
    aLog.Add(IntToStr(High(aProt)+1)+' '+ALogText);
  end;

begin
  Result:=-1;
  if not FileExists(aProtFile) then
  begin
    aLog.Add('Файл протокола не найден: '+aProtFile);
    Exit;
  end;

  Lines:=TStringList.Create;
  try
    Lines.LoadFromFile(aProtFile);
    aLog.Add('Загрузка протокола из файла: '+aProtFile);
    if not ParseProtocolText(Lines.Text, Document, ErrorText) then
    begin
      aLog.Add('Ошибка в протоколе: '+ErrorText);
      Result:=-2;
      Exit;
    end;
  finally
    Lines.Free;
  end;

  for b:=0 to High(Document) do
  begin
    Rec:=Default(TOperRec);
    Rec.Func:=dName;
    Rec.StrParam:=Document[b].Name;
    AddRec(Rec, 'Block='+Rec.StrParam);

    for s:=0 to High(Document[b].Steps) do
    begin
      Step:=Document[b].Steps[s];
      Rec:=Default(TOperRec);
      case Step.Kind of
        pskComment:
          begin
            Rec.Func:=dName;
            Rec.StrParam:=Step.Text;
            AddRec(Rec, 'Comment='+Rec.StrParam);
          end;
        pskPause:
          begin
            Rec.Func:=dPause;
            Rec.IntParam:=Step.IntValue;
            AddRec(Rec, 'Pause='+IntToStr(Rec.IntParam));
          end;
        pskVacuum:
          begin
            Rec.Func:=dVac;
            Rec.BoolParam:=Step.BoolValue;
            AddRec(Rec, 'Vacuum='+BoolToStr(Rec.BoolParam));
          end;
        pskLaser:
          begin
            Rec.Func:=dLaser;
            Rec.IntParam:=Step.IntValue;
            Rec.FloatParam:=Step.FloatValue;
            AddRec(Rec, 'Laser='+IntToStr(Rec.IntParam)+
                        '; time='+FloatToStr(Rec.FloatParam)+';');
          end;
        pskSyringe:
          begin
            Rec.Func:=dSyrSt;
            Rec.StrParam:=Step.Syringe.Dispensers;
            Rec.Syringe:=Step.Syringe;
            AddRec(Rec, SyringeStepSummary(Rec.Syringe));
          end;
      end;
    end;
  end;

  Result:=0;
  aLog.Add('Протокол успешно загружен!'+#10#13);
end;

end.
