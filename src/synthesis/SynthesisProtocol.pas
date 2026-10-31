unit SynthesisProtocol;
// Протокол синтеза для одной буквы: типы операций и разбор файла .pro

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TDev = (dName, dSyrSt, dVac, dlaser, dPause);

type
  TOperRec = record // строчка записи в протоколе
    Func: TDev;   // тип устройств/записей
    StrParam: String; // строковый параметр
    IntParam: Integer; // Целочисленный параметр
    FloatParam: Double; // параметр числа с плав. запятой
    BoolParam: Boolean; // булевый параметр
  end;

  type
    TLayerProt = array of TOperRec; // протокол (последовательность строк) для буквы

Function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String; aLog: TStrings): integer;

implementation

function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String; aLog: TStrings): integer;
// загрузка файла протокола одной буквы в массив TLayerProt
var
  F: TextFile;
  S: String;
  Parts: TStringArray;
  SubParts: TStringArray;
  d: Double;
  i: integer;
//  SubSubP: TStringArray;
begin
  if FileExists(aProtFile) then
  begin
    try
      AssignFile(F,aProtFile);
      Reset(F);
      aLog.Add('Загрузка протокола из файла: '+aProtFile);
      while not EOF(F) do
      begin
        ReadLN(F,S);
        SetLength(Parts,0);
        Parts:=S.Split(';');
        case Length(Parts)of
        2: begin // все операторы кроме лазера и дозаторов
             SubParts:=trim(Parts[0]).Split('=');
             if Length(SubParts)=0 then // если строка не содержит =, зачит ошибка
             begin
               Result:=-2;
               Exit;  //прерываем цикл
             end;
             // Если всё ок, то увеличиваем массив протокола на 1 и парсим по операторам
             SetLength(aProt,Length(aProt)+1);
             case trim(SubParts[0]) of {dName, dSyrSt, dVac, dlaser, dPause}
             'Block':  begin
                        aProt[High(aProt)].Func:=dName;
                        aProt[High(aProt)].StrParam:=SubParts[1];
                        aLog.Add(IntToStr(High(aProt)+1)+' Block='+
                                              aProt[High(aProt)].StrParam);
                       end;
             'Pause':  begin
                        aProt[High(aProt)].Func:=dPause;
                        if TryStrToInt(SubParts[1],i)
                        then  aProt[High(aProt)].IntParam:=i;
                        aLog.Add(IntToStr(High(aProt)+1)+' Pause='+
                                              IntToStr(aProt[High(aProt)].IntParam));
                      end;

             'Vacuum': begin
                        aProt[High(aProt)].Func:=dVac;
                        aProt[High(aProt)].BoolParam:=StrToBool(SubParts[1]);
                        aLog.Add(IntToStr(High(aProt)+1)+' Vacuum='+
                                              BoolToStr(aProt[High(aProt)].BoolParam));
                       end;
             'Comment':begin
                        aProt[High(aProt)].Func:=dName;
                        aProt[High(aProt)].StrParam:=trim(SubParts[1]);
                        aLog.Add(IntToStr(High(aProt)+1)+' Comment='+
                                              aProt[High(aProt)].StrParam);
                       end;
           end;
        end;
        3: begin // лазер
             for i:=0 to High(SubParts) do  // сначала обнулим все подстроки
               SetLength(SubParts[i],0);
             SetLength(SubParts,0);

             SubParts:=trim(Parts[0]).Split('=');
             if Length(SubParts)=0 then // если строка не содержит =, зачит ошибка
             begin
               Result:=-3;
               Exit;  //прерываем цикл
             end;
             if trim(SubParts[0])='Laser' then
             begin
               SetLength(aProt,Length(aProt)+1);
               aProt[High(aProt)].Func:=dLaser; // записали, что это лазер
               if TryStrToInt(trim(SubParts[1]),i) then aProt[High(aProt)].IntParam:=i;

               SubParts:=trim(Parts[1]).Split('='); // в этой части хранится время на слой;
               if TryStrToFloat(trim(SubParts[1]),d) then aProt[High(aProt)].FloatParam:=d;

               aLog.Add(IntToStr(High(aProt)+1)+' Laser='+IntToStr(aProt[High(aProt)].IntParam)+
                                       '; time='+FloatToStr(aProt[High(aProt)].FloatParam)+';');
             end
             else
             begin
               Result:=-3;
               Exit;
             end;
           end;
        4: begin // Шприцевой дозатор
             for i:=0 to High(SubParts) do
               SetLength(SubParts[i],0);
             SetLength(SubParts,0);
             SubParts:=trim(Parts[0]).Split('=');
             if Length(SubParts)=0 then // если строка не содержит =, зачит ошибка
             begin
               Result:=-3;
               Exit;  //прерываем цикл
             end;
             if trim(SubParts[0])='SyrSt' then
             begin
               SetLength(aProt,Length(aProt)+1);
               aProt[High(aProt)].Func:=dSyrSt; // записали, что это шприц
               aProt[High(aProt)].StrParam:=(SubParts[1]); // записали метку шприца/шприцов

               SubParts:=trim(Parts[1]).Split('='); // в этой части хранится объем, это Double;
               if TryStrToFloat(trim(SubParts[1]),d) then aProt[High(aProt)].FloatParam:=d;

               SubParts:=trim(Parts[2]).Split('='); // в этой части хранится скорость, это integer;
               if TryStrToInt(trim(SubParts[1]),i) then aProt[High(aProt)].IntParam:=i;

               aLog.Add(IntToStr(High(aProt)+1)+' SyrSt='+aProt[High(aProt)].StrParam+'; V='+
                                     FloatToStr(aProt[High(aProt)].FloatParam)+'; S='+
                                     IntToStr(aProt[High(aProt)].IntParam)+';');
             end
             else
             begin
               Result:=-3;
               Exit;
             end;
        end;

        else begin // если операторов не 1 и не 3, то это неправильная запись
                Result:=-1;
                Exit;
              end;
        end;

      end;
      Result:=0;
      aLog.Add('Протокол успешно загружен!'+#10#13);
    finally
      CloseFile(F);
    end;
  end;
end;

end.
