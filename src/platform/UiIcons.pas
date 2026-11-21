unit UiIcons;
// Единый набор значков в TImageList. Файлы лежат в
// <папка exe>\icons\<размер>\<имя>.png (размеры 16, 24, 32; набор взят
// из Lazarus: Tango, общественное достояние, и значки FTurtle).
// Индекс значка получают по имени (IconIndex), а не по номеру.

{$mode ObjFPC}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Controls, UiIconNames;

// Создаёт список значков размера ASize; значки идут в порядке ICON_ALL.
// Нет файла, битый файл или PNG не того размера - исключение, чтобы
// пропажа значка не прошла молча.
function CreateIconList(AOwner: TComponent; ASize: Integer;
  const AIconsRoot: string = ''): TImageList;

// Список для экрана с APpi, размер выбирает IconSizeForPpi.
function CreateIconListForPpi(AOwner: TComponent; APpi: Integer;
  const AIconsRoot: string = ''): TImageList;

implementation

uses
  Graphics, UiTheme;

function CreateIconList(AOwner: TComponent; ASize: Integer;
  const AIconsRoot: string): TImageList;
var
  I: Integer;
  Png: TPortableNetworkGraphic;
  Dir, FileName: string;
begin
  Dir := IconsDir(ASize, AIconsRoot);
  Result := TImageList.Create(AOwner);
  try
    Result.Width := ASize;
    Result.Height := ASize;
    for I := Low(ICON_ALL) to High(ICON_ALL) do
    begin
      FileName := Dir + ICON_ALL[I] + '.png';
      Png := TPortableNetworkGraphic.Create;
      try
        Png.LoadFromFile(FileName);
        if (Png.Width <> ASize) or (Png.Height <> ASize) then
          raise EInvalidGraphic.CreateFmt(
            'Значок %s: размер %dx%d, ожидался %dx%d',
            [FileName, Png.Width, Png.Height, ASize, ASize]);
        if Result.Add(Png, nil) <> I - Low(ICON_ALL) then
          raise EInvalidGraphic.CreateFmt('Значок %s не добавлен в список',
            [FileName]);
      finally
        Png.Free;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CreateIconListForPpi(AOwner: TComponent; APpi: Integer;
  const AIconsRoot: string): TImageList;
begin
  Result := CreateIconList(AOwner, IconSizeForPpi(APpi), AIconsRoot);
end;

end.
