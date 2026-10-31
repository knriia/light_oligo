unit LasFunc;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Windows, Graphics;

const
// Все функции возвращают целочисленное значение
  LMC1_ERR_SUCCESS       = 0;  // Успех
  LMC1_ERR_EZCADRUN      = 1;  // Обнаружено, что EZCAD работает.
  LMC1_ERR_NOFINDCFGFILE = 2;  // EZCAD.CFG не найден
  LMC1_ERR_FAILEDOPEN    = 3;  // Не удалось открыть LMC1
  LMC1_ERR_NODEVICE      = 4;  // Нет допустимого устройства lmc1
  LMC1_ERR_HARDVER       = 5;  // ошибка версии lmc1
  LMC1_ERR_DEVCFG        = 6;  // Невозможно найти файл конфигурации устройства
  LMC1_ERR_STOPSIGNAL    = 7;  // Аварийный сигнал
  LMC1_ERR_USERSTOP      = 8;  // Остановка пользователя
  LMC1_ERR_UNKNOW        = 9;  // Неизвестная ошибка
  LMC1_ERR_OUTTIME       = 10; // Тайм-аут
  LMC1_ERR_NOINITIAL     = 11; // Не инициализировано
  LMC1_ERR_READFILE      = 12; // Ошибка чтения файла
  LMC1_ERR_OWENWNDNULL   = 13; // Окно пусто
  LMC1_ERR_NOFINDFONT    = 14; // Невозможно найти шрифт с указанным именем
  LMC1_ERR_PENNO         = 15; // Неправильный номер пера
  LMC1_ERR_NOTTEXT       = 16; // Объект с указанным именем не является текстовым объектом
  LMC1_ERR_SAVEFILE      = 17; // Не удалось сохранить файл
  LMC1_ERR_NOFINDENT     = 18; // Указанный объект не найден
  LMC1_ERR_STATUE        = 19; // Эта операция не может быть выполнена в текущем состоянии

const
  BARCODETYPE_39      = 0;
  BARCODETYPE_93      = 1;
  BARCODETYPE_128A    = 2;
  BARCODETYPE_128B    = 3;
  BARCODETYPE_128C    = 4;
  BARCODETYPE_128OPT  = 5;
  BARCODETYPE_EAN128A = 6;
  BARCODETYPE_EAN128B = 7;
  BARCODETYPE_EAN128C = 8;
  BARCODETYPE_EAN13   = 9;
  BARCODETYPE_EAN8    = 10;
  BARCODETYPE_UPCA    = 11;
  BARCODETYPE_UPCE    = 12;
  BARCODETYPE_25      = 13;
  BARCODETYPE_INTER25 = 14;
  BARCODETYPE_CODABAR = 15;
  BARCODETYPE_PDF417  = 16;
  BARCODETYPE_DATAMTX = 17;
  BARCODETYPE_USERDEF = 18;

  BARCODEATTRIB_REVERSE        = $0008;   // Реверс штрих-кода
  BARCODEATTRIB_HUMANREAD      = $1000;   // Отображение символов человеческого распознавания
  BARCODEATTRIB_CHECKNUM       = $0004;   // Требуется проверочный код
  BARCODEATTRIB_PDF417_SHORTMODE = $0040; // PDF417 — сокращенный режим
  BARCODEATTRIB_DATAMTX_DOTMODE  = $0080; // DataMtrix — точечный режим
  BARCODEATTRIB_CIRCLEMODE     = $0100;   // Настройте QR-код в режим круга

  DATAMTX_SIZEMODE_SMALLEST = 0;
  DATAMTX_SIZEMODE_10X10    = 1;
  DATAMTX_SIZEMODE_12X12    = 2;
  DATAMTX_SIZEMODE_14X14    = 3;
  DATAMTX_SIZEMODE_16X16    = 4;
  DATAMTX_SIZEMODE_18X18    = 5;
  DATAMTX_SIZEMODE_20X20    = 6;
  DATAMTX_SIZEMODE_22X22    = 7;
  DATAMTX_SIZEMODE_24X24    = 8;
  DATAMTX_SIZEMODE_26X26    = 9;
  DATAMTX_SIZEMODE_32X32    = 10;
  DATAMTX_SIZEMODE_36X36    = 11;
  DATAMTX_SIZEMODE_40X40    = 12;
  DATAMTX_SIZEMODE_44X44    = 13;
  DATAMTX_SIZEMODE_48X48    = 14;
  DATAMTX_SIZEMODE_52X52    = 15;
  DATAMTX_SIZEMODE_64X64    = 16;
  DATAMTX_SIZEMODE_72X72    = 17;
  DATAMTX_SIZEMODE_80X80    = 18;
  DATAMTX_SIZEMODE_88X88    = 19;
  DATAMTX_SIZEMODE_96X96    = 20;
  DATAMTX_SIZEMODE_104X104  = 21;
  DATAMTX_SIZEMODE_120X120  = 22;
  DATAMTX_SIZEMODE_132X132  = 23;
  DATAMTX_SIZEMODE_144X144  = 24;
  DATAMTX_SIZEMODE_8X18     = 25;
  DATAMTX_SIZEMODE_8X32     = 26;
  DATAMTX_SIZEMODE_12X26    = 27;
  DATAMTX_SIZEMODE_12X36    = 28;
  DATAMTX_SIZEMODE_16X36    = 29;
  DATAMTX_SIZEMODE_16X48    = 30;

const
  HATCHATTRIB_ALLCALC = $01;  // Все объекты вычисляются вместе как единое целое
  HATCHATTRIB_BIDIR   = $08;  // Двунаправленное заполнение
  HATCHATTRIB_EDGE    = $02;  // Идем один раз
  HATCHATTRIB_LOOP    = $10;  // Заполнение кольца


// Определение атрибута типа шрифта
const
  FONTATB_JSF = $0001;  // JczSingle шрифт
  FONTATB_TTF = $0002;  // Шрифт TrueType
  FONTATB_DMF = $0004;  // Шрифт DotMatrix
  FONTATB_BCF = $0008;  // Шрифт штрих-кода


type
  Arr03Dbl = array [0..3] of Double;

type
  TMatrix = array of array of Byte; // массив точек 0 - пусто, остальное - точка

type
  TPoint = array [0..1] of double; // 0-x, 1-y

type
  TArrOfArrOfInt = array of array of Integer;

type
  TArrOfTPoint = Array of TPoint;
  pT = ^TArrOfTPoint;

type
  CBitmap = TBitmap;

{type  // Запись параметров лазера
  TLasPen = record
    nPenNo: Integer;          // номер пера, который нужно установить (0-255)
    nMarkLoop: Integer;       // количество обработок
    dMarkSpeed: Double;       // скорость маркировки мм/с
    dPowerRatio: Double;      // Процент мощности (0-100%)
    dCurrent: Double;         // Текущий A
    nFreq: Integer;           // частота Гц
    nQPulseWidth: Integer;    // ширина Q-импульса us
    nStartTC: Integer;        // Старт задержит нас
    nLaserOffTC: Integer;     // задержка выключения лазера
    nEndTC: Integer;          // завершим задержку
    nPolyTC: Integer;         // задержка угла
    dJumpSpeed: Double;       // Скорость прыжка мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние прыжка
    dEndComp: Double;         // компенсация конечной точки мм
    dAccDist: Double;         // Дистанция ускорения мм
    dPointTime: Double;       // задержка точки, мс
    bPulsePointMode: boolean; // Режим точки пульса
    nPulseNum: Integer;       // Количество точек пульса
    dFlySpeed: Double         // Скорость производственной линии
  end;      }

type  // Запись параметров лазера
  TLasPen2 = record
    nPenNo: Integer;          // номер пера, который нужно установить (0-255)
    nMarkLoop: Integer;       // количество обработок
    dMarkSpeed: Double;       // скорость маркировки мм/с
    dPowerRatio: Double;      // Процент мощности (0-100%)
    dCurrent: Double;         // Текущий A
    nFreq: Integer;           // частота Гц
    dQPulseWidth: Double;    // ширина Q-импульса us
    nStartTC: Integer;        // Старт задержит нас
    nLaserOffTC: Integer;     // задержка выключения лазера
    nEndTC: Integer;          // завершим задержку
    nPolyTC: Integer;         // задержка угла
    dJumpSpeed: Double;       // Скорость прыжка мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние прыжка
    dPointTime: Double;       // задержка точки, мс
    nSpiWave: Integer;        // выбрать тип волны SPI
    bWobbleMode: boolean;     // Режим воблинга
    dWobbleDiameter: Double;  // Диаметр воблинга
    dWobbleDist: Double;      // Дистанция воблинга
  end;

// Запись шрифта
type
  lmc1_FontRecord = record
      szFontName: array[0..255] of Char;  // Имя шрифта
      dwFontAttrib: DWORD;                // Атрибуты шрифта
  end;

type
  plmc1_FontRecord = ^lmc1_FontRecord;

// Инициализируем карту управления lmc1
// Входные параметры: strEzCadPath Путь выполнения программного обеспечения EzCad.
// bTestMode = TRUE указывает на тестовый режим
// bTestMode = FALSE указывает на нормальный режим
// hOwenWnd представляет собой объект родительского окна, если необходимо прекратить маркировку, система перехватит сообщение из этого окна.
function  lmc1_Initial(strEzCadPath: WideString;   // рабочий каталог ezcad
    bTestMode: boolean;  // Это тестовый режим?
    hOwenWnd: THandle    // родительское окно
    ): Integer; stdcall;

function  lmc1_Initial2(strEzCadPath: WideString;   // рабочий каталог ezcad
    bTestMode: boolean;  // Это тестовый режим?
    hOwenWnd: THandle    // родительское окно
    ): Integer; stdcall;


// Закрываем карту управления lmc1
function lmc1_Close: Integer; stdcall;


// Загружаем файл ezd и очищаем все объекты в базе данных
// Входные параметры: strFileName имя файла EzCad
function lmc1_LoadEzdFile(strFileName: WideString): Integer; stdcall;


// Маркируем все данные в текущей базе данных
// Входные параметры: bFlyMark = TRUE включает  маркировку на лету bFlyMark = FALSE выключает
function lmc1_Mark(bFlyMark: boolean): Integer; stdcall;


// Маркируем указанный объект в текущей базе данных
// Входные параметры: strEntName Имя указанного объекта, который будет обработан
function lmc1_MarkEntity(strEntName: WideString): Integer; stdcall;


// Маркируем указанный объект в текущей базе данных в режиме на лету
// Входные параметры: strEntName Имя указанного объекта для маркировки на лету
function lmc1_MarkEntityFly(strEntName: WideString): Integer; stdcall;


// Читаем входной порт lmc1
// Входные параметры: чтение данных входного порта
function lmc1_ReadPort (var data: WORD): Integer; stdcall;


// Записываем выходной порт lmc1
// Входные параметры: данные выходного порта для записи
function lmc1_WritePort(data: WORD): Integer; stdcall;


// Получаем изображения предварительного просмотра всех данных в текущей базе данных
// Входные параметры: THandle, в каком окне отображается изображение предварительного просмотра
//         nBMPWIDTH ширина изображения предварительного просмотра
//         nBMPHEIGHT высота изображения предварительного просмотра
//
// Для сохранения именования, CBitmap является определённым как класс TBitmap в данном переводе.

  function lmc1_GetPrevBitmap(THandle: THandle;
      nBMPWIDTH,
      nBMPHEIGHT: Integer
      ): CBitmap; stdcall;


// Получаем изображение предварительного просмотра данных указанного объекта в текущей базе данных
// Входные параметры: strEntName указывает имя объекта
//         THandle, в каком окне отображается изображение предварительного просмотра
//         nBMPWIDTH ширина изображения предварительного просмотра
//         nBMPHEIGHT высота изображения предварительного просмотра
function  lmc1_GetPrevBitmapByName(strEntName: WideString;
    THandle: THandle;
    nBMPWIDTH,
    nBMPHEIGHT: Integer
    ): CBitmap; stdcall;


// Вызов диалогового окна настройки параметров устройства
function lmc1_SetDevCfg: Integer; stdcall;


// Устанавливаем текущие параметры заполнения.
//Если при добавлении нового объекта в базу включено заполнение, то для заполнения будет использоваться этот параметр.

function lmc1_SetHatchParam(bEnableContour: boolean;        // включаем сам контур
    bEnableHatch1: Integer;     // Включаем заполнение 1
    nPenNo1: Integer;           // заполняем перо
    nHatchAttrib1: Integer;     // заполняем атрибуты
    dHatchEdgeDist1: Double;    // заполняем поле строки
    dHatchLineDist1: Double;    // заполняем межстрочный интервал
    dHatchStartOffset1: Double; // Начальное расстояние смещения линии заполнения
    dHatchEndOffset1: Double;   // Расстояние конечного смещения линии заполнения
    dHatchAngle1: Double;       // Угол линии штриховки (значение в радианах)
    bEnableHatch2: Integer;     // Включаем заполнение 2
    nPenNo2: Integer;           // заполняем перо
    nHatchAttrib2: Integer;     // заполняем атрибуты
    dHatchEdgeDist2: Double;    // заполняем поле строки
    dHatchLineDist2: Double;    // заполняем межстрочный интервал
    dHatchStartOffset2: Double; // Начальное расстояние смещения линии заполнения
    dHatchEndOffset2: Double;   // Расстояние конечного смещения линии заполнения
    dHatchAngle2: Double        // Угол линии штриховки (значение в радианах)
    ): Integer; stdcall;


// Установим текущие параметры шрифта.Этот параметр шрифта будет использоваться, если вы захотите добавить новый текстовый объект в базу данных.
function lmc1_SetFontParam(strFontName: WideString;   // имя шрифта
    dCharHeight: Double;      // Высота символа
    dCharWidth: Double;       // ширина символа
    dCharAngle: Double;       // Угол наклона символа
    dCharSpace: Double;       // Межсимвольный интервал
    dLineSpace: Double;       // межстрочный интервал
    bEqualCharWidth: boolean  // Режим одинаковой ширины символов
    ): Integer; stdcall;


{// Получаем параметры обработки, соответствующие указанному номеру пера
function lmc1_GetPenParam(nPenNo: Integer;   // номер пера, который нужно установить (0-255)
    var nMarkLoop: Integer;       // количество обработок
    var dMarkSpeed: Double;       // количество маркировок мм/с
    var dPowerRatio: Double;      // Процент мощности (0-100%)
    var dCurrent: Double;         // Текущий A
    var nFreq: Integer;           // частота Гц
    var nQPulseWidth: Integer;    // ширина Q-импульса us
    var nStartTC: Integer;        // Старт задержит нас
    var nLaserOffTC: Integer;     // задержка выключения лазера
    var nEndTC: Integer;          // завершим задержку
    var nPolyTC: Integer;         // задержка угла
    var dJumpSpeed: Double;       // Скорость прыжка мм/с
    var nJumpPosTC: Integer;      // задержка позиции перехода
    var nJumpDistTC: Integer;     // задержка на расстояние прыжка
    var dEndComp: Double;         // компенсация конечной точки мм
    var dAccDist: Double;         // Дистанция ускорения мм
    var dPointTime: Double;       // задержка точки, мс
    var bPulsePointMode: boolean; // Режим точки пульса
    var nPulseNum: Integer;       // Количество точек пульса
    var dFlySpeed: Double         // Скорость производственной линии
    ): Integer; stdcall; }

// Получаем параметры обработки, соответствующие указанному номеру пера
function lmc1_GetPenParam2(nPenNo: Integer;   // номер пера, который нужно установить (0-255)
    var nMarkLoop: Integer;       // количество обработок
    var dMarkSpeed: Double;       // количество маркировок мм/с
    var dPowerRatio: Double;      // Процент мощности (0-100%)
    var dCurrent: Double;         // Текущий A
    var nFreq: Integer;           // частота Гц
    var dQPulseWidth: Double;    // ширина Q-импульса us
    var nStartTC: Integer;        // Старт задержит нас
    var nLaserOffTC: Integer;     // задержка выключения лазера
    var nEndTC: Integer;          // завершим задержку
    var nPolyTC: Integer;         // задержка угла
    var dJumpSpeed: Double;       // Скорость прыжка мм/с
    var nJumpPosTC: Integer;      // задержка позиции перехода
    var nJumpDistTC: Integer;     // задержка на расстояние прыжка
    var dPointTime: Double;       // задержка точки, мс
    var nSpiWave: Integer;        // выбрать тип волны SPI
    var bWobbleMode: boolean;     // Режим воблинга
    var dWobbleDiameter: Double;  // Диаметр воблинга
    var dWobbleDist: Double       // Дистанция воблинга
    ): Integer; stdcall;

// Устанавливаем параметры обработки, соответствующие указанному номеру пера
{function lmc1_SetPenParam(nPenNo: Integer;   // номер пера, который нужно установить (0-255)
    nMarkLoop: Integer;       // Количество раз обработки
    dMarkSpeed: Double;       // время маркировки мм/с
    dPowerRatio: Double;      // процент мощности (0-100%)
    dCurrent: Double;         // ток A
    nFreq: Integer;           // частота Гц
    nQPulseWidth: Integer;    // ширина Q-импульса us
    nStartTC: Integer;        // Старт задержит нас
    nLaserOffTC: Integer;     // задержка выключения лазера
    nEndTC: Integer;          // завершим задержку
    nPolyTC: Integer;         // Угловая задержка
    dJumpSpeed: Double;       // Скорость прыжка мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние прыжка нас
    dEndComp: Double;         // компенсация конечной точки, мм
    dAccDist: Double;         // Дистанция ускорения мм
    dPointTime: Double;       // задержка точки, мс
    bPulsePointMode: boolean; // Режим точки пульса
    nPulseNum: Integer;       // Количество точек пульса
    dFlySpeed: Double         // Скорость производственной линии
    ): Integer; stdcall;     }

// Устанавливаем параметры обработки, соответствующие указанному номеру пера
function lmc1_SetPenParam2(nPenNo: Integer;   // номер пера, который нужно установить (0-255)
    nMarkLoop: Integer;       // Количество раз обработки
    dMarkSpeed: Double;       // время маркировки мм/с
    dPowerRatio: Double;      // процент мощности (0-100%)
    dCurrent: Double;         // ток A
    nFreq: Integer;           // частота Гц
    dQPulseWidth: Double;    // ширина Q-импульса us
    nStartTC: Integer;        // Старт задержит нас
    nLaserOffTC: Integer;     // задержка выключения лазера
    nEndTC: Integer;          // завершим задержку
    nPolyTC: Integer;         // Угловая задержка
    dJumpSpeed: Double;       // Скорость прыжка мм/с
    nJumpPosTC: Integer;      // задержка позиции перехода
    nJumpDistTC: Integer;     // задержка на расстояние прыжка нас
    dPointTime: Double;       // задержка точки, мс               //
    nSpiWave: Integer;        // выбрать тип волны SPI
    bWobbleMode: boolean;     // Режим воблинга                    //
    dWobbleDiameter: Double;  // Диаметр воблинга                    //
    dWobbleDist: Double       // Дистанция воблинга                    //
    ): Integer; stdcall;

//Очистить все данные в библиотеке объектов
function lmc1_ClearEntLib: Integer; stdcall;


// Значение цифр в выравнивании
// 6 --- 5 --- 4
// |           |
// |           |
// 7     8     3
// |           |
// |           |
// 0 --- 1 --- 2
// Добавляем новый текст в базу данных
function lmc1_AddTextToLib(pStr: WideString;   // строка, которую нужно добавить
    pEntName: WideString;      // имя строкового объекта
    dPosX: Double;             // координата X базовой точки нижнего левого угла строки
    dPosY: Double;             // Координата y базовой точки нижнего левого угла строки
    dPosZ: Double;             // координата z строкового объекта
    nAlign: Integer;           // выравнивание 0-8
    dTextRotateAngle: Double;  // Значение угла поворота строки вокруг базовой точки (радикальное значение)
    nPenNo: Integer;           // Параметры обработки, используемые объектом
    bHatchText: boolean        // Заполнять ли текстовый объект
    ): Integer; stdcall;


// Добавляем указанный файл в базу данных
// Поддерживаемые файлы: ezd, dxf, dst, plt, ai, bmp, jpg, tga, png, gif, tiff и т.д.
function lmc1_AddFileToLib(pFileName: WideString;   // имя файла
    pEntName: WideString;    // имя строкового объекта
    dPosX: Double;           // X-координата базовой точки нижнего угла файла
    dPosY: Double;           // координата Y базовой точки в левом нижнем угле файла
    dPosZ: Double;           // координата z файла
    nAlign: Integer;         // выравнивание 0-8
    dRatio: Double;          // коэффициент масштабирования файла
    nPenNo: Integer;         // Параметры обработки, используемые объектом
    bHatchFile: boolean      // Заполнять ли файловый объект. Если это ezd-файл или растровый файл, этот параметр недействителен.
    ): Integer; stdcall;


// Добавляем группу точек в базу данных
function lmc1_AddPointToLib(ptBuf: pT;   // указатель на линейный массив точек
    ptNum: integer;                      // число точек в массиве
    pEntName: WideString;                // название группы точек в базе
    nPenNo: Integer                      // номер пера
    ): Integer; stdcall;


// Добавляем кривую в базу данных
  // Для параметра ptBuf[][2] используем указатель на Double, предполагая, что данные организованы последовательно.
function lmc1_AddCurveToLib(ptBuf: PDouble;   // массив вершин кривой
    ptNum: Integer;       // Количество вершин кривой
    pEntName: WideString; // имя объекта кривой
    nPenNo: Integer;      // Номер пера, используемый объектом кривой
    bHatch: Integer       // Заполнена ли кривая
    ): Integer; stdcall;



//Добавляем штрих-код в базу данных
function lmc1_AddBarCodeTolib(pStr: WideString;   // String
    pEntName: WideString;        // имя строкового объекта
    dPosX: Double;               // X-координата базовой точки левого нижнего угла штрих-кода
    dPosY: Double;               // координата Y базовой точки левого нижнего угла штрих-кода
    dPosZ: Double;               // Координата z штрих-кода
    nAlign: Integer;             // выравнивание 0-8
    nPenNo: Integer;
    bHatchText: Integer;
    nBarcodeType: Integer;       // тип штрих-кода
    wBarCodeAttrib: Word;        // Атрибуты штрих-кода
    dHeight: Double;             // Высота всего штрих-кода
    dNarrowWidth: Double;        // Самая узкая ширина модуля
    dBarWidthScale: Arr03Dbl;    // коэффициент ширины полосы (по сравнению с самой узкой шириной модуля)
    dSpaceWidthScale:  Arr03Dbl; // коэффициент ширины пространства (по сравнению с самой узкой шириной модуля)
    dMidCharSpaceScale: Double;  // соотношение интервалов между символами (по сравнению с самой узкой шириной модуля)
    dQuietLeftScale: Double;     // соотношение ширины левого пустого штрих-кода (по сравнению с шириной самого узкого модуля)
    dQuietMidScale: Double;      // соотношение ширины пробелов в штрих-коде (по сравнению с шириной самого узкого модуля)
    dQuietRightScale: Double;    // соотношение ширины правого пробела штрих-кода (по сравнению с шириной самого узкого модуля)
    dQuietTopScale: Double;      // соотношение ширины пустого штрих-кода (по сравнению с шириной самого узкого модуля)
    dQuietBottomScale: Double;   // соотношение ширины пустого пространства под штрих-кодом (по сравнению с шириной самого узкого модуля)
    nRow: Integer;               // Количество строк QR-кода
    nCol: Integer;               // количество столбцов QR-кода
    nCheckLevel: Integer;        // pdf417 уровень исправления ошибок 0-8
    nSizeMode: Integer;          // Режим размера DataMatrix 0-30
    dTextHeight: Double;         // Высота шрифта символов человеческого распознавания
    dTextWidth: Double;          // Ширина шрифта символов распознавания человека
    dTextOffsetX: Double;        // смещение направления X символов человеческого распознавания
    dTextOffsetY: Double;        // смещение направления Y символов человеческого распознавания
    dTextSpace: Double;          // интервал между символами человеческого распознавания
    dDiameter: Double;
    pTextFontName: WideString    // имя текстового шрифта
    ): Integer; stdcall;


// Изменяем текст указанного текстового объекта в текущей базе данных
// Входные параметры:	strTextName  Имя текстового объекта, содержимое которого необходимо изменить
//            strTextNew   новое текстовое содержимое
function lmc1_ChangeTextByName(strTextName: WideString; strTextNew: WideString): Integer; stdcall;


// Устанавливаем параметры преобразования вращения
// Входные параметры: координата x центра вращения dCenterX
//           координата y центра вращения dCenterY
//           угол поворота dRotateAng (значение в радианах)
procedure lmc1_SetRotateParam(dCenterX, dCenterY, dRotateAng: Double); stdcall;


/////////////////////////////////////////////////////
// Расширенные функции оси


// Перемещаем расширенную ось в указанную координатную позицию
// Входные параметры: axis расширенная ось 0 = ось 0 1 = ось 1
//         GoalPos положение координаты
function lmc1_AxisMoveTo(axis: Integer; GoalPos: Double): Integer; stdcall;


// Расширенное начало координат оси
// Входные параметры: расширенная ось 0 = ось 0 1 = ось 1
function lmc1_AxisCorrectOrigin(axis: Integer): Integer; stdcall;


// Получаем текущие координаты расширенной оси
// Входные параметры: расширенная ось 0 = ось 0 1 = ось 1
function lmc1_GetAxisCoor(axis: Integer): Double; stdcall;


// Расширенная ось перемещается в указанную позицию координат импульса
// Входные параметры: расширенная ось 0 = ось 0 1 = ось 1
//           координата импульса nGoalPos
function lmc1_AxisMoveToPulse(axis, nGoalPos: Integer): Integer; stdcall;


// Получаем текущие координаты импульса расширенной оси
// Входные параметры: расширенная ось 0 = ось 0 1 = ось 1
function lmc1_GetAxisCoorPulse(axis: Integer): Integer; stdcall;


// Сброс координат расширенной оси
// Входные параметры: bEnAxis0 = Включить ось 0 bEnAxis1 = Включить ось 1
function lmc1_Reset(bEnAxis0, bEnAxis1: boolean): Double; stdcall;


// Получаем параметр шрифта, который поддерживается PC системой
function lmc1_GetFontRecord(nFontIndex: integer; // серийный номер шрифта
    szFontName: WideString;                      // название шрифта
    dwFontAttrib: Word): Integer; stdcall;       // атрибуты шрифта (Truetype, Dotmatrix и т.п.)


// Получаем все параметры шрифта, поддерживаемые текущей системой
// Входные параметры: указатель на массив типа lmc1_FontRecord
// nFontNum количество шрифтов
// Возвращаем параметры: массив записей шрифтов lmc1_FontRecord
function lmc1_GetAllFontRecord(p: plmc1_FontRecord; var nFontNum: Integer): Integer; stdcall;


// Сохраняем все объекты текущей базы данных в указанный файл ezd
// Входные параметры: strFileName имя файла ezd
function lmc1_SaveEntLibToFile(strFileName: WideString): Integer; stdcall;


// Получаем максимальные и минимальные координаты указанного объекта.
// Если pEntName = NIL, то это означает чтение максимальных и минимальных координат всех объектов в базе данных.
function lmc1_GetEntSize(pEntName: WideString;   // имя строкового объекта
    var dMinx, dMiny, dMaxx, dMaxy, dZ: Double
    ): Integer; stdcall;


// Перемещаем относительные координаты указанного объекта
function lmc1_MoveEnt(pEntName: WideString;   // имя строкового объекта
    dMovex, dMovey: Double
    ): Integer; stdcall;


// Масштабируем указанный объект, масштабируем координаты центра (dCenx, dCeny)
//     dScaleX = коэффициент масштабирования в направлении X
//     dScaleY = коэффициент масштабирования в направлении Y
function lmc1_ScaleEnt(pEntName: WideString;   // имя строкового объекта
    dCenx, dCeny, dScaleX, dScaleY: Double
    ): Integer; stdcall;


// Отразить указанный объект, координаты центра зеркала (dCenx, dCeny)
//     bMirrorX = TRUE Зеркало в направлении X
//     bMirrorY = TRUE Зеркало в направлении Y
function lmc1_MirrorEnt(pEntName: WideString;  // имя строкового объекта
    dCenx, dCeny: Double;
    bMirrorX, bMirrorY: boolean
    ): Integer; stdcall;


// Поворот указанного объекта, координаты центра вращения (dCenx, dCeny)
// dAngle = угол поворота (против часовой стрелки положителен, единица измерения – градус)
function lmc1_RotateEnt(pEntName: WideString;  // имя строкового объекта
    dCenx, dCeny, dAngle: Double
    ): Integer; stdcall;


function lmc1_RedLightMark: Integer; stdcall;


// Получаем общее количество объектов
// Выходные параметры: общее количество объектов
function lmc1_GetEntityCount: Integer; stdcall;


// Получаем имя объекта указанного серийного номера
// Входные параметры: nEntityIndex указывает серийный номер объекта
//               (диапазон: 0 - (lmc1_GetEntityCount()-1))
// Выходной параметр: имя объекта szEntName
function lmc1_GetEntityName(nEntityIndex: Integer; var szEntName: array of Char): Integer; stdcall;


// Получаем идентификационный номер клиента собаки
function lmc1_GetClientId: Word; stdcall;


// Получаем текст указанного объекта
function lmc1_GetTextByName(strTextName: WideString; var strText: array of Char): Integer; stdcall;



  {МОИ ФУНКЦИИ И ПРОЦЕДУРЫ}

// Добавить точку в линейный массив маркиратора
function AddPointToLinearArray(const aPoint: TPoint;
  var aLinearArray: TArrOfTPoint): Integer;

// конвертировать матрицу точек в линейный массив маркиратора
Function ConvertMatrixToLinearArray(const aMatrix: TMatrix; // конвертируемая матрица
    var aLinearArray: TArrOfTPoint;                       // линейный массив для записи матрицы
    const aStep: Double;                                  // шаг между точками в мм (одинаковый для X и Y)
    const aGroup: integer=0;                              // по скольким точкам группировать
    const aGroupStep: Double=0;                            // шаг между группами (в дополнение к шагу между точками)
    const aBiasX: Double=0;                                // смещение линейного массива по X
    const aBiasY: Double=0                                // смещение линейного массива по Y
    ): Integer;                                           // 0, если получилось, иначе 1000









implementation





Function lmc1_Initial(strEzCadPath: WideString;
    bTestMode: boolean;
    hOwenWnd: THandle): Integer; stdcall;                                       external 'MarkEzd.dll' name 'lmc1_Initial';
Function lmc1_Initial2(strEzCadPath: WideString;
    bTestMode: boolean;
    hOwenWnd: THandle): Integer; stdcall;                                       external 'MarkEzd.dll' name 'lmc1_Initial2';
Function lmc1_Close: Integer; stdcall;                                          external 'MarkEzd.dll' name 'lmc1_Close';
Function lmc1_LoadEzdFile(strFileName: WideString): Integer; stdcall;           external 'MarkEzd.dll' name 'lmc1_LoadEzdFile';
Function lmc1_Mark(bFlyMark: boolean): Integer; stdcall;                        external 'MarkEzd.dll' name 'lmc1_Mark';
Function lmc1_MarkEntity(strEntName: WideString): Integer; stdcall;             external 'MarkEzd.dll' name 'lmc1_MarkEntity';
Function lmc1_MarkEntityFly(strEntName: WideString): Integer; stdcall;          external 'MarkEzd.dll' name 'lmc1_MarkEntityFly';
Function lmc1_ReadPort(var data: WORD): Integer; stdcall;                       external 'MarkEzd.dll' name 'lmc1_ReadPort';
Function lmc1_WritePort(data: WORD): Integer; stdcall;                          external 'MarkEzd.dll' name 'lmc1_WritePort';
Function lmc1_GetPrevBitmap(THandle: THandle;
    nBMPWIDTH, nBMPHEIGHT: Integer): CBitmap; stdcall;                          external 'MarkEzd.dll' name 'lmc1_GetPrevBitmap';
Function lmc1_GetPrevBitmapByName(strEntName: WideString;
    THandle: THandle; nBMPWIDTH, nBMPHEIGHT: Integer): CBitmap; stdcall;        external 'MarkEzd.dll' name 'lmc1_GetPrevBitmapByName';
Function lmc1_SetDevCfg: Integer; stdcall;                                      external 'MarkEzd.dll' name 'lmc1_SetDevCfg';
Function lmc1_SetHatchParam(bEnableContour: boolean;
    bEnableHatch1: Integer; nPenNo1: Integer; nHatchAttrib1: Integer;
    dHatchEdgeDist1: Double; dHatchLineDist1: Double;
    dHatchStartOffset1: Double; dHatchEndOffset1: Double; dHatchAngle1: Double;
    bEnableHatch2: Integer; nPenNo2: Integer; nHatchAttrib2: Integer;
    dHatchEdgeDist2: Double; dHatchLineDist2: Double;
    dHatchStartOffset2: Double; dHatchEndOffset2: Double;
    dHatchAngle2: Double): Integer; stdcall;                                    external 'MarkEzd.dll' name 'lmc1_SetHatchParam';
Function lmc1_SetFontParam(strFontName: WideString; dCharHeight: Double;
    dCharWidth: Double; dCharAngle: Double; dCharSpace: Double;
    dLineSpace: Double; bEqualCharWidth: boolean): Integer; stdcall;            external 'MarkEzd.dll' name 'lmc1_SetFontParam';
{Function lmc1_GetPenParam(nPenNo: Integer; var nMarkLoop: Integer;
    var dMarkSpeed: Double; var dPowerRatio: Double; var dCurrent: Double;
    var nFreq: Integer; var nQPulseWidth: Integer; var nStartTC: Integer;
    var nLaserOffTC: Integer; var nEndTC: Integer; var nPolyTC: Integer;
    var dJumpSpeed: Double; var nJumpPosTC: Integer; var nJumpDistTC: Integer;
    var dEndComp: Double; var dAccDist: Double; var dPointTime: Double;
    var bPulsePointMode: boolean; var nPulseNum: Integer;
    var dFlySpeed: Double): Integer; stdcall;                                   external 'MarkEzd.dll' name 'lmc1_GetPenParam';}
Function lmc1_GetPenParam2(nPenNo: Integer; var nMarkLoop: Integer;
    var dMarkSpeed: Double; var dPowerRatio: Double; var dCurrent: Double;
    var nFreq: Integer; var dQPulseWidth: Double; var nStartTC: Integer;
    var nLaserOffTC: Integer; var nEndTC: Integer; var nPolyTC: Integer;
    var dJumpSpeed: Double; var nJumpPosTC: Integer; var nJumpDistTC: Integer;
    var dPointTime: Double; var nSpiWave: Integer; var bWobbleMode: boolean;
    var dWobbleDiameter: Double; var dWobbleDist: Double ): Integer; stdcall;   external 'MarkEzd.dll' name 'lmc1_GetPenParam2';
{Function lmc1_SetPenParam(nPenNo: Integer; nMarkLoop: Integer;
    dMarkSpeed: Double; dPowerRatio: Double; dCurrent: Double; nFreq: Integer;
    nQPulseWidth: Integer; nStartTC: Integer; nLaserOffTC: Integer;
    nEndTC: Integer; nPolyTC: Integer; dJumpSpeed: Double;
    nJumpPosTC: Integer; nJumpDistTC: Integer; dEndComp: Double;
    dAccDist: Double; dPointTime: Double; bPulsePointMode: boolean;
    nPulseNum: Integer; dFlySpeed: Double): Integer; stdcall;                   external 'MarkEzd.dll' name 'lmc1_SetPenParam';}
Function lmc1_SetPenParam2(nPenNo: Integer;
    nMarkLoop: Integer;
    dMarkSpeed: Double;
    dPowerRatio: Double;
    dCurrent: Double;
    nFreq: Integer;
    dQPulseWidth: Double;
    nStartTC: Integer;
    nLaserOffTC: Integer;
    nEndTC: Integer;
    nPolyTC: Integer;
    dJumpSpeed: Double;
    nJumpPosTC: Integer;
    nJumpDistTC: Integer;
    dPointTime: Double;//
    nSpiWave: Integer;
    bWobbleMode: boolean;//
    dWobbleDiameter: Double;//
    dWobbleDist: Double): Integer; stdcall;                                 external 'MarkEzd.dll' name 'lmc1_SetPenParam2';
Function lmc1_ClearEntLib: Integer; stdcall;                                    external 'MarkEzd.dll' name 'lmc1_ClearEntLib';
Function lmc1_AddTextToLib(pStr: WideString; pEntName: WideString;
    dPosX: Double; dPosY: Double; dPosZ: Double; nAlign: Integer;
    dTextRotateAngle: Double; nPenNo: Integer; bHatchText: boolean
    ): Integer; stdcall;                                                        external 'MarkEzd.dll' name 'lmc1_AddTextToLib';
Function lmc1_AddFileToLib(pFileName: WideString; pEntName: WideString;
    dPosX: Double; dPosY: Double; dPosZ: Double; nAlign: Integer;
    dRatio: Double; nPenNo: Integer; bHatchFile: boolean): Integer; stdcall;    external 'MarkEzd.dll' name 'lmc1_AddFileToLib';
Function lmc1_AddPointToLib(ptBuf: pT; ptNum: integer;
    pEntName: WideString; nPenNo: Integer): Integer; stdcall;                   external 'MarkEzd.dll';
Function lmc1_AddCurveToLib(ptBuf: PDouble; ptNum: Integer; pEntName: WideString;
    nPenNo: Integer; bHatch: Integer): Integer; stdcall;                        external 'MarkEzd.dll' name 'lmc1_AddCurveToLib';
Function lmc1_AddBarCodeTolib(pStr: WideString; pEntName: WideString;
    dPosX: Double; dPosY: Double; dPosZ: Double; nAlign: Integer;
    nPenNo: Integer; bHatchText: Integer; nBarcodeType: Integer;
    wBarCodeAttrib: Word; dHeight: Double; dNarrowWidth: Double;
    dBarWidthScale: Arr03Dbl; dSpaceWidthScale:  Arr03Dbl;
    dMidCharSpaceScale: Double; dQuietLeftScale: Double;
    dQuietMidScale: Double; dQuietRightScale: Double;
    dQuietTopScale: Double; dQuietBottomScale: Double;
    nRow: Integer; nCol: Integer; nCheckLevel: Integer;
    nSizeMode: Integer; dTextHeight: Double; dTextWidth: Double;
    dTextOffsetX: Double; dTextOffsetY: Double; dTextSpace: Double;
    dDiameter: Double; pTextFontName: WideString): Integer; stdcall;            external 'MarkEzd.dll' name 'lmc1_AddBarCodeTolib';
Function lmc1_ChangeTextByName(strTextName: WideString;
    strTextNew: WideString): Integer; stdcall;                                  external 'MarkEzd.dll' name 'lmc1_ChangeTextByName';
Procedure lmc1_SetRotateParam(dCenterX, dCenterY, dRotateAng: Double); stdcall; external 'MarkEzd.dll' name 'lmc1_SetRotateParam';
Function lmc1_AxisMoveTo(axis: Integer; GoalPos: Double): Integer; stdcall;     external 'MarkEzd.dll' name 'lmc1_AxisMoveTo';
Function lmc1_AxisCorrectOrigin(axis: Integer): Integer; stdcall;               external 'MarkEzd.dll' name 'lmc1_AxisCorrectOrigin';
Function lmc1_GetAxisCoor(axis: Integer): Double; stdcall;                      external 'MarkEzd.dll' name 'lmc1_GetAxisCoor';
Function lmc1_AxisMoveToPulse(axis, nGoalPos: Integer): Integer; stdcall;       external 'MarkEzd.dll' name 'lmc1_AxisMoveToPulse';
Function lmc1_GetAxisCoorPulse(axis: Integer): Integer; stdcall;                external 'MarkEzd.dll' name 'lmc1_GetAxisCoorPulse';
Function lmc1_Reset(bEnAxis0, bEnAxis1: boolean): Double; stdcall;              external 'MarkEzd.dll' name 'lmc1_Reset';
Function lmc1_GetFontRecord(nFontIndex: integer; szFontName: WideString;
    dwFontAttrib: Word): Integer; stdcall;                                      external 'MarkEzd.dll' name 'lmc1_GetFontRecord';
Function lmc1_GetAllFontRecord(p: plmc1_FontRecord;
    var nFontNum: Integer): Integer; stdcall;                                   external 'MarkEzd.dll' name 'lmc1_GetAllFontRecord';
Function lmc1_SaveEntLibToFile(strFileName: WideString): Integer; stdcall;      external 'MarkEzd.dll' name 'lmc1_SaveEntLibToFile';
Function lmc1_GetEntSize(pEntName: WideString; var dMinx, dMiny,
    dMaxx, dMaxy, dZ: Double): Integer; stdcall;                                external 'MarkEzd.dll' name 'lmc1_GetEntSize';
Function lmc1_MoveEnt(pEntName: WideString;
    dMovex, dMovey: Double): Integer; stdcall;                                  external 'MarkEzd.dll' name 'lmc1_MoveEnt';
Function lmc1_ScaleEnt(pEntName: WideString;
    dCenx, dCeny, dScaleX, dScaleY: Double): Integer; stdcall;                  external 'MarkEzd.dll' name 'lmc1_ScaleEnt';
Function lmc1_MirrorEnt(pEntName: WideString; dCenx, dCeny: Double;
    bMirrorX, bMirrorY: boolean): Integer; stdcall;                             external 'MarkEzd.dll' name 'lmc1_MirrorEnt';
Function lmc1_RotateEnt(pEntName: WideString;
    dCenx, dCeny, dAngle: Double): Integer; stdcall;                            external 'MarkEzd.dll' name 'lmc1_RotateEnt';
Function lmc1_RedLightMark: Integer; stdcall;                                   external 'MarkEzd.dll' name 'lmc1_RedLightMark';
Function lmc1_GetEntityCount: Integer; stdcall;                                 external 'MarkEzd.dll' name 'lmc1_GetEntityCount';
Function lmc1_GetEntityName(nEntityIndex: Integer;
    var szEntName: array of Char): Integer; stdcall;                            external 'MarkEzd.dll' name 'lmc1_GetEntityName';
Function lmc1_GetClientId: Word; stdcall;                                       external 'MarkEzd.dll' name 'lmc1_GetClientId';
Function lmc1_GetTextByName(strTextName: WideString;
    var strText: array of Char):Integer; stdcall;                               external 'MarkEzd.dll' name 'lmc1_GetTextByName';

//добавляем в конец массива точку
function AddPointToLinearArray(const aPoint: TPoint;
  var aLinearArray: TArrOfTPoint): Integer;
begin
  try
    SetLength(aLinearArray, Length(aLinearArray)+1);
    aLinearArray[Length(aLinearArray)-1][0]:=aPoint[0];
    aLinearArray[Length(aLinearArray)-1][1]:=aPoint[1];
    Result:=0;
  except
    Result:=2000;
  end;
end;


function ConvertMatrixToLinearArray(const aMatrix: TMatrix; // конвертируемая матрица
    var aLinearArray: TArrOfTPoint;                       // линейный массив для записи матрицы
    const aStep: Double;                                  // шаг между точками в мм (одинаковый для X и Y)
    const aGroup: integer=0;                              // по скольким точкам группировать
    const aGroupStep: Double=0;                            // шаг между группами (в дополнение к шагу между точками)
    const aBiasX: Double=0;                                // смещение массива по X
    const aBiasY: Double=0                                // смещение массива по Y
    ): Integer;                                           // 0, если получилось, иначе 1000
var
   p: TPoint;
   i,j: integer;
begin
  try
  // очищаем линейный массив
  SetLength(aLinearArray,0);

  for i:=0 to High(aMatrix) do
  begin
    for j:=0 to High(aMatrix[i]) do
    begin
      if aMatrix[i,j]<>0 then
       begin
          if aGroup=0 then
           begin
            p[0]:=j*aStep+aBiasX;
            p[1]:=-i*aStep+aBiasY;
            AddPointToLinearArray(p,aLinearArray);
           end
          else
          begin
            p[0]:=j*aStep+aGroupStep*(j div aGroup)+aBiasX;
            p[1]:=-i*aStep-aGroupStep*(i div aGroup)+aBiasY;
            AddPointToLinearArray(p,aLinearArray);
          end;
       end;
    end;
  end;
    Result:=0;
  except
    Result:=1000;
  end;
end;

end.
