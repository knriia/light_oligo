unit Lmc1Results;
// Текст результата вызова функций MarkEzd.dll (lmc1_*) для журнала.

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

// Строка вида "<функция> -> <код> <описание>".
function Lmc1ResultText(const AFunName: string; ARez: Integer): string;

implementation

function Lmc1ResultText(const AFunName: string; ARez: Integer): string;
var
  Description: string;
begin
  case ARez of
    0:  Description := 'Успех!';
    1:  Description := 'работает EZCAD';
    2:  Description := 'EZCAD.CFG не найден';
    3:  Description := 'не удалось открыть LMC1';
    4:  Description := 'нет допустимого устройства LMC1';
    5:  Description := 'ошибка версии LMC1';
    6:  Description := 'Невозможно найти файл конфигурации устройства';
    7:  Description := 'Аварийный сигнал';
    8:  Description := 'Остановка пользователя';
    9:  Description := 'Неизвестная ошибка';
    10: Description := 'Тайм-аут';
    11: Description := 'Не инициализировано';
    12: Description := 'Ошибка чтения файла';
    13: Description := 'Пустое окно';
    14: Description := 'Невозможно найти шрифт с указанным именем';
    15: Description := 'Неправильный номер пера';
    16: Description := 'Объект с указанным именем не является текстовым объектом';
    17: Description := 'Не удалось сохранить файл';
    18: Description := 'Указанный объект не найден';
    19: Description := 'Эта операция не может быть выполнена в текущем состоянии';
    21: Description := 'Режим TestMode';
  else
    Description := 'ХЗ';
  end;
  Result := AFunName + ' -> ' + IntToStr(ARez) + ' ' + Description;
end;

end.
