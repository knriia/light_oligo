unit AppState;
// Общее состояние приложения: текущая матрица, массив олигов, таблица слоёв,
// протоколы синтеза и флаги работы

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, EzCadApi, OligoArray, OligoSlices, SynthesisProtocol;

type
  TCell = record
    Col: Integer;
    Row: Integer;
  end;

Function AlphabetNum(anLetter: String): Integer;

var
  GlobalI: Integer=0;              // глобальный итератор, сколько раз будет таймер EzCADer пытаться убить предупреждения, прежде чем остановиться
  TmrCloserStr: String='';
  EditedCell: TCell;                 // координаты редактируемой ячейки (строка, столбец)
  myStep, myGStep, mySpotR: Double;  // шаг между точками, между группами точек и радиус точек (для отображения) в мм
  myGroup: Integer;                  // группировка точек
  BiasX, BiasY: Double;              // смещение массива по X и Y (для центрирования)
  MyMatrix: TMatrix;                 // матрица точек
  MyOligoArr: TOligoArr;             // массив олигов
  ArrOfSpots: TArrOfTPoint;          // линейный массив маркируемых точек
  SliceTable: TArrSliceStruc;        // массив записей о слайсах
  MyLasPen: TLasPen2;                // Запись с параметрами маркера

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
