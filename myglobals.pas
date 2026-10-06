unit MyGlobals;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, JwaTlHelp32, JwaPsApi, StrUtils, Grids, LasFunc, Dilutor;

type
  TCell = record
    Col: Integer;
    Row: Integer;
  end;

type
  TSliceStruc = record  // запись слайсинга слоя
    LayerCount: Integer; // номер слоя
    Col: Integer;        //кол-во колонок
    Row: Integer;        //кол-во строк
    Letter: String;      //буква нуклеотида слоя
    NumOfChar: Integer;  //число букв в слое
    MatrixFile: String;  //путь к файлу матрицы
    EZDFile: String;     //путь к файлу EZD
  end;

  type
   TArrSliceStruc = array of TSliceStruc;

type
  TOlig = String;

type
  TSymbolSet = array of Char;

type
  TOligoArr = array of array of TOlig;

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

Function RemoveFileExt(Const aFileName: String): String;
Function SendMsgToProc(aProcName: String;
                       aKeyCode: Integer): boolean;
Function SendMsgToProcWithMod(aProcName: String;
                              aKeyCode: Integer;
                              aModifier: Integer): boolean;
Function GetHWNDByExeName(const ExeName: string): HWND;
Function GetProcessHandle(const AProcessName: string): THandle;
Procedure NumerateGrid(aSG: TStringGrid);
Procedure CopyMatrix(aDonorMatrix: TMatrix;
                     var aAcceptorMatrix: TMatrix);
Function AutoCenterBiasMatrix(aMatrix: TMatrix;
                              aStep: Double;
                              aGStep: Double;
                              aGroup: Integer): TPoint;
Function GenerateOligSeq(aLength: Integer): TOlig;
Procedure CreateMatrixLayerFromOligoArr(var aOligoArr: TOligoArr;
                                        var aSymbolSet: TSymbolSet;
                                        var aMatrixLayer: TMatrix;
                                        var maxLetter: TOlig;
                                        var maxCount: Integer);
Function StringToOlig(aStr: String): TOlig;
Function SaveMatrixAsFile(aMatrix: TMatrix;
                          aFName: String): boolean;
Procedure FindUniqueSymbols(anOlig: TOlig;
                            var aSymbolSet: TSymbolSet);
procedure SaveSliceStatistics(aDir: String;
                              const aTable: array of TSliceStruc; aFileType: word=0);
Function ReadMatrixFromFile(const filename: string;
                            var aMatrix: TMatrix): Boolean;
Function LoadSliceFile(var aSliceTable: TArrSliceStruc; aSliceFile: String): integer;
Function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String): integer;
Function AlphabetNum(anLetter: String): Integer;
Function ReadOligsFromCSVFile(var anOligoArr: TOligoArr; aFileName: String; aSeparator: String=';'): Boolean;

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
  MyPumpSt: array of TPump;          // Шприцевая станция

  MyOper: TOperRec;
  MyBlockName: String;
  Alphabet: array of String;         // Здесь хранится массив названий протоколов A,T,G,C,Greed...
  MySynthProt: Array of TLayerProt;  // массив записей в протоколе под каждую букву
  IsStarted: Boolean=false;          // Состояние работы потока. Если надо остановить синтез.

implementation
uses UMain;


{WinAPI функции}

function RemoveFileExt(const aFileName: String): String;
//Удаление расширения в имени файла
var
  DotPos: Integer;
begin
  // Находим позицию последней точки в имени файла
  DotPos:=LastDelimiter('.', aFileName);

  // Если точка найдена, возвращаем строку до точки, иначе возвращаем оригинальное имя
  if DotPos > 0 then
    Result:=Copy(aFileName, 1, DotPos-1)
  else
    Result:=aFileName;
end;

function GetHWNDByExeName(const ExeName: string): HWND;
// определение дескриптора главного окна программы по его ExeName
var
  hSnapshot: THandle;
  pe32: TProcessEntry32;
  ProcessID: DWORD;
  hWndTemp: HWND;
  ProcessIDCheck: DWORD;
  ProcessFound: Boolean;
begin
  Result := 0;
  ProcessFound := False;
  ProcessID := 0;

  // Шаг 1: Сначала находим PID процесса по имени исполняемого файла
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot <> INVALID_HANDLE_VALUE then
  try
    pe32.dwSize := SizeOf(TProcessEntry32);
    if Process32First(hSnapshot, pe32) then
    begin
      repeat
        if LowerCase(ExtractFileName(pe32.szExeFile)) = LowerCase(ExeName) then
        begin
          ProcessID := pe32.th32ProcessID;
          ProcessFound := True;
          Break;
        end;
      until not Process32Next(hSnapshot, pe32);
    end;
  finally
    CloseHandle(hSnapshot);
  end;

  if not ProcessFound then Exit;

  // Шаг 2: Находим главное окно процесса
  hWndTemp := FindWindow(nil, nil);
  while hWndTemp <> 0 do
  begin
    GetWindowThreadProcessId(hWndTemp, @ProcessIDCheck);
    if ProcessIDCheck = ProcessID then
    begin
      // Проверяем, что это главное окно (не дочернее) и оно видимо
      if (GetWindow(hWndTemp, GW_OWNER) = 0) and IsWindowVisible(hWndTemp) then
      begin
        Result := hWndTemp;
        Break;
      end;
    end;
    hWndTemp := GetWindow(hWndTemp, GW_HWNDNEXT);
  end;
end;

function GetProcessHandle(const AProcessName: string): THandle;
// получить дескриптор процесса
var
  ProcessIDs: array[0..1023] of DWORD;
  Count, I: DWORD;
  ProcessHandle: THandle;
  ProcessName: array[0..MAX_PATH] of Char;
begin
  Result := 0;
  if EnumProcesses(ProcessIDs, SizeOf(ProcessIDs), Count) then
  begin
    for I := 0 to Count div SizeOf(DWORD) - 1 do
    begin
      ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessIDs[I]);
      if ProcessHandle <> 0 then
      begin
        if GetModuleFileNameEx(ProcessHandle, 0, ProcessName, SizeOf(ProcessName) div SizeOf(Char)) > 0 then
        begin
          if AnsiContainsStr(ProcessName, AProcessName) then
          begin
            Result := ProcessHandle;
            Break;
          end;
        end;
        CloseHandle(ProcessHandle);
      end;
    end;
  end;
end;

function SendMsgToProc(aProcName: String; aKeyCode: Integer): boolean;
// послать команду нажатия клавиши приложению по его ExeName
var
  WinH: HWND;
  Input: TInput; // Массив для нажатия и отпускания клавиши
  pI: PInput;
begin
  WinH:=GetHWNDByExeName(aProcName);
  if WinH <> 0 then
  begin
    SetForegroundWindow(WinH);

    // Настройка нажатия клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));
    Result := True;
  end
  else
  begin
    // Обработка ошибки, если окно не найдено
    //Caption:='0';
    Result := False;
  end;
end;

function SendMsgToProcWithMod(aProcName: String; aKeyCode: Integer; aModifier: Integer): boolean;
// послать команду нажатия клавиши вместе с модификатором приложению по его ExeName
var
  WinH: HWND;
  Input: TInput; // Запись для нажатия и отпускания клавиши
  pI: PInput;
begin
  WinH:=GetHWNDByExeName(aProcName);
  if WinH <> 0 then
  begin
    SetForegroundWindow(WinH);

    // Настройка нажатия модификатора Alt или Shift
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aModifier;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши модификатора
    SendInput(1, pI, SizeOf(TInput));

    // Настройка нажатия клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := 0;
    pI:=@Input;
    // Отправка нажатия клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aKeyCode;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));

    // Настройка отпускания клавиши модификатора
    Input._Type := INPUT_KEYBOARD;
    Input.ki.wVk := aModifier;
    Input.ki.dwFlags := KEYEVENTF_KEYUP; // Отпускание клавиши
    pI:=@Input;
    // Отправка отпускания клавиши
    SendInput(1, pI, SizeOf(TInput));

    Result := True;
  end
  else
  begin
    // Обработка ошибки, если окно не найдено
    //Caption:='0';
    Result := False;
  end;
end;


{Display}

procedure NumerateGrid(aSG: TStringGrid);
// нумерация строк и стобцов StringGrid [i,0] и [0,i]
var
  i: integer;
begin
  for i:=1 to aSG.ColCount-1 do
  begin
    aSG.Cells[i,0]:=IntToStr(i);
  end;
    for i:=1 to aSG.RowCount-1 do
  begin
    aSG.Cells[0,i]:=IntToStr(i);
  end;
end;


{Matrix}

procedure CopyMatrix(aDonorMatrix: TMatrix; var aAcceptorMatrix: TMatrix);
// копирование матрицы донора в матрицу акцептора
var
  i,j: integer;
begin
  // устанавливаем размеры матрицы
  SetLength(aAcceptorMatrix, Length(ADonorMatrix));
  for i:=0 to Length(ADonorMatrix)-1 do
    SetLength(aAcceptorMatrix[i], Length(aDonorMatrix[i]));

  // копируем элементы из донор-матрицы в акцептор-матрицу
  for i:=0 to High(ADonorMatrix) do
  begin
   for j:=0 to High(ADonorMatrix[i]) do
     aAcceptorMatrix[i][j]:=aDonorMatrix[i][j];
  end;
 end;

function AutoCenterBiasMatrix(aMatrix: TMatrix; aStep: Double; aGStep: Double;
  aGroup: Integer): TPoint;
// Определение смещения для центрирования матрицы с учетом шага, группировки и шага группы
var
  BX, BY: Double;
begin
  if aGroup<>0 then
    begin
      BY:=-(-High(aMatrix)*aStep-aGStep*(High(aMatrix) div aGroup))/2;
      BX:=(-High(aMatrix[High(aMatrix)])*aStep-aGStep*(High(aMatrix[High(aMatrix)]) div aGroup))/2;
    end
  else
    begin
      BY:=-(-High(aMatrix)*aStep)/2;
      BX:=(-High(aMatrix[High(aMatrix)])*aStep)/2;
    end;
  Result[0]:=BX;
  Result[1]:=BY;
end;

function SaveMatrixAsFile(aMatrix: TMatrix; aFName: String): boolean;
// Сохраняем матрицу слоя в файл
var
  i,j: integer;
  f: TextFile;
  Col, Row: Integer;
  TmpS: String;
begin
try
  AssignFile(f, aFName);
  {$I-}
  Rewrite(f);
  {$I+}
  Result:=false;
  Row:=Length(aMatrix);
  if Row<>0 then
  begin
    Col:=Length(aMatrix[Row-1]);
    tmpS:=IntToStr(Col)+' '+IntToStr(Row);
    WriteLN(f,TmpS);
    for i:=0 to Length(aMatrix)-1 do
    begin
      TmpS:='';
      for j:=0 to Length(aMAtrix[i])-1 do
      begin
        TmpS:=TmpS+' '+IntToStr(aMatrix[i][j]);
      end;
      WriteLN(f,TmpS);
    end;
    Result:=true;
  end;
finally
  CloseFile(f);
end;
end;

function ReadMatrixFromFile(const filename: string;
  var aMatrix: TMatrix): Boolean;
// Чтение матрицы из файла
// В первой строке файла должно быть указано количество столбцов и строк
var
  f: TextFile;
  i, j, Nx, Ny: Integer;
    ch: Char;
begin
  Result := False;
    try
      // Открываем файл для чтения
      AssignFile(f, filename);
      Reset(f);
      try
       if not Eof(f) then
        // Читаем первую строку с размерами
       begin
         Nx:=0;
         while not Eof(f) and not Eoln(f) do
          begin
            Read(f, ch);
            if ch = ' ' then Break; // Конец первого числа
            if (ch >= '0') and (ch <= '9') then
              Nx := Nx * 10 + (Ord(ch) - Ord('0'));
          end;

         // Читаем второе число (Ny)
         Ny := 0;
         while not Eof(f) and not Eoln(f) do
           begin
            Read(f, ch);
            if (ch >= '0') and (ch <= '9') then
              Ny := Ny * 10 + (Ord(ch) - Ord('0'));
           end;

         ReadLn(f); // Переходим к следующей строке

         // Устанавливаем размеры массива
         SetLength(aMatrix, Nx);
         for i := 0 to (Nx - 1) do
            SetLength(aMatrix[i], Ny);

       // Читаем данные матрицы
       for i :=0 to (Nx - 1) do
         begin
           if Eof(f) then
             Exit;  // Недостаточно строк в файле
           for j := 0 to (Ny - 1) do
           begin
             if Eof(f) then
               Exit; // Недостаточно чисел в строке
               Read(f, aMatrix[i][j]);
           end;
             ReadLn(f); // Переходим к следующей строке
             Result := True; // Успешное чтение
         end;
       end;
       finally
          CloseFile(f);
        end;

    except
      on E: Exception do
      begin
       // Обрабатываем возможные ошибки
       Result := False;
      end;
    end;
end;


{OLIGS}


function GenerateOligSeq(aLength: Integer): TOlig;
// генерируем олиг с рандомной последовательностью ATGC длиной aLength
var
  i: integer;
  Olig: TOlig;
  tmpCh: Byte;
begin
  SetLength(Olig,aLength);
  for i:=1 to High(Olig) do
  begin
    tmpCh:=Random(4);
    case tmpCh of
    0: Olig[i]:='A';
    1: Olig[i]:='T';
    2: Olig[i]:='G';
    3: Olig[i]:='C';
    end;
  end;
  Result:=Olig;
end;

procedure CreateMatrixLayerFromOligoArr(
  var aOligoArr: TOligoArr; // массив олигов для создания слоя матрицы, после создания из него удаляется буква слоя
  var aSymbolSet: TSymbolSet; // буквы в массиве
  var aMatrixLayer: TMatrix; // создаваемый слой матрицы
  var maxLetter: TOlig; // буква создаваемого слоя матрицы
  var maxCount: Integer // количество букв в слое
  );
  //Создание матрицы слоя. В слое ищется наиболее частая буква. Из нее создается матрица. В массиве она удаляется
var
  i, j, k: Integer;
  tmpS: String;
  lastCh: Char;
  letterCount: array of Integer;
  lastLetters: array of TOlig;
  maxIndex: Integer;
begin
  // Инициализация массива для подсчета вхождений каждой буквы
  SetLength(letterCount, Length(aSymbolSet));
  SetLength(lastLetters, Length(aSymbolSet));

   // Обнуляем счетчики
  for k := Low(letterCount) to High(letterCount) do
    letterCount[k] := 0;

  // Подсчет последних букв и их вхождений
  for i:=0 to Length(aOligoArr)-1 do
  begin
    for j:=0 to Length(aOligoArr[i])-1 do
    begin
      tmpS:=aOligoArr[i,j]; // скопировал олиг для анализа
      if Length(tmpS)<>0 then
      lastCh:=tmpS[Length(tmpS)] //скопировал последнюю букву
      else lastCh:=' ';

      for k:=0 to Length(aSymbolSet)-1 do
      begin
        if lastCh=aSymbolSet[k] then
        begin
          lastLetters[k]:=lastCh;
          Inc(letterCount[k]);
        end;
      end;
    end;
  end;

  // Находим букву с максимальным количеством вхождений
  maxCount:= 0;
  maxIndex:= -1;
  for k:=0 to Length(letterCount)-1 do
  begin
    if letterCount[k] > maxCount then
    begin
      maxCount:= letterCount[k];
      maxIndex:= k;
    end;
  end;
  // Если найдена буква с максимальным количеством вхождений
  if maxIndex <> -1 then
  begin
    maxLetter:= lastLetters[maxIndex];


    // Создание матрицы
    SetLength(aMatrixLayer, Length(aOligoArr)); // Размер матрицы равен размеру aOligoArr
    for i:=0 to Length(aOligoArr)-1 do
    begin
      SetLength(aMatrixlayer[i],Length(aOligoArr[i]));
      for j := 0 to Length(aOligoArr[i])-1 do
      begin
        tmpS:=aOligoArr[i,j]; // скопировал олиг для анализа
        if Length(tmpS)<>0 then
        lastCh:=tmpS[Length(tmpS)] //скопировал последнюю букву
        else lastCh:=' ';
        if lastCh = maxLetter then
          begin
            aMatrixLayer[i][j]:=1;
            if Length(aOligoArr[i,j]) > 0 then
            Delete(aOligoArr[i][j],Length(aOligoArr[i][j]),1); // сразу удаляем эту последнюю букву из олига
          end
        else
          aMatrixLayer[i][j]:=0;
      end;
    end;
  end;
end;

function StringToOlig(aStr: String): TOlig;
// Строку переводим в UpperCase
begin
  Result:=UpperCase(aStr);
end;

procedure FindUniqueSymbols(anOlig: TOlig; var aSymbolSet: TSymbolSet);
// Находятся символы в anOlig и добавляются в массив aSymbolSet.
var
  i, j: Integer;
  found: Boolean;
  begin
    for i := 1 to Length(anOlig) do
    begin
      found := False;
      // Проверяем, есть ли символ уже в массиве
      for j := Low(aSymbolSet) to High(aSymbolSet) do
      begin
        if aSymbolSet[j] = anOlig[i] then
        begin
          found := True;
          Break;
        end;
      end;

      // Если символ не найден, добавляем его в массив
      if not found then
      begin
        // Увеличиваем размер массива
        SetLength(aSymbolSet, Length(aSymbolSet) + 1);
        aSymbolSet[High(aSymbolSet)] := anOlig[i];
      end;
    end;
  end;

procedure SaveSliceStatistics(aDir: String;
  const aTable: array of TSliceStruc; aFileType: word=0);
// Сохранение статистики слайсинга
//aFileType=0 - txt, aFileType=1 ezd
var
   i: integer;
   s: String;
   f: TextFile;
   aFTStr: String;
begin
case aFileType of
0: aFTStr:='.txt';
1: aFTStr:='.lays';
end;

  if Length(aTable)<>0 then
  try
    AssignFile(f, aDir+'\Slices'+aFTStr);
    {$I-}
    Rewrite(f);
    {$I+}
    case aFileType of
    0: s:='Layer'+#9+'Letter'+#9+'NumOfLetters'+#9+'Filepath';
    1: s:='Layer'+#9+'Letter'+#9+'Filepath';
    end;
    WriteLN(f,S);

    for i:=0 to Length(aTable)-1 do
     case aFileType of
      0: begin
          s:=IntToStr(aTable[i].LayerCount)+
          #9+aTable[i].Letter+
          #9+IntToStr(aTable[i].NumOfChar)+
          #9+aTable[i].MatrixFile;
          WriteLN(f,S);
         end;
      1: begin
          s:=IntToStr(aTable[i].LayerCount)+
          #9+aTable[i].Letter+
          #9+aTable[i].EZDFile;
          WriteLN(f,S);
         end;
    end;
  finally
    CloseFile(f);
  end;
end;

function LoadSliceFile(var aSliceTable: TArrSliceStruc;
  aSliceFile: String): integer;
var
  F: TextFile;
  S: String;
  Parts: TStringArray;
begin
  if FileExists(aSliceFile) then
  begin
    try
      AssignFile(F,aSliceFile);
      Reset(F);
      SetLength(aSliceTable,0);
      ReadLN(F,S); //просто считываем первую строку с заголовками
      while not EOF(F) do
      begin
        ReadLN(F,S);
          // Разделяем входную строку по символу табуляции
        Parts:=S.Split(#9); // #9 - символ табуляции
          // Проверяем, что строка содержит 3 части
        if Length(Parts) <> 3 then
        begin
          Result:=-1;
          Exit;
        end
        else
        SetLength(aSliceTable, Length(aSliceTable)+1); //увеличиваем размер на 1
        TryStrToInt(Parts[0], aSliceTable[High(aSliceTable)].LayerCount);
        aSliceTable[High(aSliceTable)].Letter:=trim(Parts[1]);
        aSliceTable[High(aSliceTable)].EZDFile:=trim(Parts[2]);
      end;
      Result:=0;
    finally
      CloseFile(F);
    end;
  end;
end;

function ParceProtocolFile(var aProt: TLayerProt; aProtFile: String): integer;
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
      Form1.Memo1.Lines.Add('Загрузка протокола из файла: '+aProtFile);
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
                        Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' Block='+
                                              aProt[High(aProt)].StrParam);
                       end;
             'Pause':  begin
                        aProt[High(aProt)].Func:=dPause;
                        if TryStrToInt(SubParts[1],i)
                        then  aProt[High(aProt)].IntParam:=i;
                        Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' Pause='+
                                              IntToStr(aProt[High(aProt)].IntParam));
                      end;

             'Vacuum': begin
                        aProt[High(aProt)].Func:=dVac;
                        aProt[High(aProt)].BoolParam:=StrToBool(SubParts[1]);
                        Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' Vacuum='+
                                              BoolToStr(aProt[High(aProt)].BoolParam));
                       end;
             'Comment':begin
                        aProt[High(aProt)].Func:=dName;
                        aProt[High(aProt)].StrParam:=trim(SubParts[1]);
                        Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' Comment='+
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

               Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' Laser='+IntToStr(aProt[High(aProt)].IntParam)+
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

               Form1.Memo1.Lines.Add(IntToStr(High(aProt)+1)+' SyrSt='+aProt[High(aProt)].StrParam+'; V='+
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
      Form1.Memo1.Lines.Add('Протокол успешно загружен!'+#10#13);
    finally
      CloseFile(F);
    end;
  end;
end;

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

function ReadOligsFromCSVFile(var anOligoArr: TOligoArr; aFileName: String;
  aSeparator: String=';'): Boolean;
//Чтение массива олигов из CSV файла
var
  tmpArr: TOligoArr;
  S: String;
  Parts: TStringArray;
  i,j: integer;
  F: TextFile;
begin
    try
      Result:=false;
      Setlength(tmpArr,0);
      AssignFile(F, aFileName);
      Reset(F);
      while not EOF(F) do
      begin
        ReadLN(F,S);
        Parts:=S.Split(aSeparator);
        if Length(Parts)<>0 then
        begin
          SetLength(tmpArr,Length(tmpArr)+1);
          i:=Length(tmpArr)-1;
          SetLength(tmpArr[i], Length(Parts));
          for j:=0 to Length(Parts)-1 do
          begin
            tmpArr[i,j]:=StringToOlig(Parts[j]);
          end;
        end;
      end;
      SetLength(anOligoArr,Length(tmpArr));
      begin
        for i:=0 to High(tmpArr) do
        begin
          SetLength(anOligoArr[i], Length(tmpArr[i]));
          for j:=0 to High(tmpArr[i]) do
          begin
            anOligoArr[i,j]:=tmpArr[i,j];
          end;
        end;
      end;
      Result:=true;
    finally
      CloseFile(F);
    end;
end;


end.

