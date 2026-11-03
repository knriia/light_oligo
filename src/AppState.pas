unit AppState;
// Общее состояние приложения: текущая матрица, массив олигов, таблица слоёв,
// протоколы синтеза и флаги работы

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, OligoSlices, SynthesisProtocol;

Function AlphabetNum(anLetter: String): Integer;

var
  SliceTable: TSliceLayers;        // массив записей о слайсах

  MyOper: TOperRec;
  MyBlockName: String;
  Alphabet: array of String;         // Здесь хранится массив названий протоколов A,T,G,C,Greed...
  MySynthProt: Array of TLayerProt;  // массив записей в протоколе под каждую букву
  IsStarted: Boolean=false;          // Состояние работы потока. Если надо остановить синтез.

implementation


function AlphabetNum(anLetter: String): Integer;
// функция возвращает номер буквы из массива Alphabet. Если такой буквы нет, то -1
var
  i: integer;
begin
  Result:=-1;
  for i:=0 to Length(Alphabet)-1 do
    begin
      if anLetter=Alphabet[i] then
         begin
           Result:=i;
           Exit;
         end;
    end;
end;


end.
