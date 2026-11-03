unit LayerEzd;
// EZD-файлы слоёв: по матрице каждого слоя - точки маркировки - EZD-файл.
// Сама запись EZD идёт через TEzdWriter, чтобы логику можно было проверить
// без MarkEzd.dll.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes, MarkGeometry, OligoSlices;

type
  // Запись EZD-файлов. Open - один раз перед записью, Close - после.
  TEzdWriter = class
  public
    function Open(out AErrorText: string): Boolean; virtual; abstract;
    function SavePoints(const AEzdFile, AEntityName: string;
      const APoints: TArrOfTPoint; out AErrorText: string): Boolean; virtual; abstract;
    procedure Close; virtual; abstract;
  end;

// Имя EZD-файла слоя: как у файла матрицы, но с расширением .ezd
function LayerEzdFileName(const ALayer: TSliceLayer): string;

// Создаёт EZD-файл для каждого слоя таблицы в папке AEzdDir.
// Если пятна точек выходят за край подложки, ни одного файла не создаётся.
// AResult - копия таблицы, EZDFile заполнен только у записанных слоёв.
// True - записаны все слои. Иначе в AErrorText список слоёв с причинами:
// неполный набор слоёв для синтеза использовать нельзя.
function CreateLayerEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir: string; const AGeometry: TMarkGeometry;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;

// EZD целиком: EZD-файлы всех слоёв в AEzdDir, таблица Slices.lays и
// геометрия, с которой они созданы (geometry.ini), в ASliceDir (пути к EZD
// в Slices.lays - относительно ASliceDir). Slices.lays и geometry.ini
// пишутся, только если созданы EZD всех слоёв.
function CreateSliceEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir, ASliceDir: string; const AGeometry: TMarkGeometry;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;

implementation

uses
  OligoMatrix;

function LayerEzdFileName(const ALayer: TSliceLayer): string;
begin
  Result := ChangeFileExt(ExtractFileName(ALayer.MatrixFile), '.ezd');
end;

function CreateLayerEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir: string; const AGeometry: TMarkGeometry;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;
var
  i: Integer;
  Matrix: TMatrix;
  Points: array of TArrOfTPoint;
  Reasons: array of string;
  EzdFile, Reason, Failed: string;
  Overflow, LayerOverflow: Double;
begin
  AResult := Copy(ATable);
  for i := 0 to High(AResult) do
    AResult[i].EZDFile := '';

  // точки всех слоёв считаем заранее: если массив не помещается на
  // подложку, ни одного файла не создаём
  Points := nil;
  Reasons := nil;
  SetLength(Points, Length(AResult));
  SetLength(Reasons, Length(AResult));
  Overflow := -1e300;
  for i := 0 to High(AResult) do
  begin
    Matrix := nil;
    if not ReadMatrixFromFile(AResult[i].MatrixFile, Matrix) then
      Reasons[i] := 'не удалось прочитать матрицу слоя'
    else
    begin
      Points[i] := MatrixToMarkPoints(Matrix, AGeometry);
      if Length(Points[i]) = 0 then
        Reasons[i] := 'в матрице слоя нет точек'
      else
      begin
        LayerOverflow := SubstrateOverflow(Points[i], AGeometry);
        if LayerOverflow > Overflow then
          Overflow := LayerOverflow;
      end;
    end;
  end;
  if Overflow > 1e-9 then
  begin
    AErrorText := Format('Массив не помещается на подложку диаметром %s мм: ' +
      'пятна выходят за край на %s мм.' + LineEnding +
      'Измените шаг, смещение или диаметр подложки в параметрах геометрии.',
      [FormatFloat('0.###', AGeometry.SubstrateDiameter),
       FormatFloat('0.###', Overflow)]);
    Exit(False);
  end;

  if not AWriter.Open(Reason) then
  begin
    AErrorText := 'Не удалось подключиться к MarkEzd.dll: ' + Reason;
    Exit(False);
  end;

  Failed := '';
  try
    for i := 0 to High(AResult) do
    begin
      Reason := Reasons[i];
      if Reason = '' then
      begin
        EzdFile := IncludeTrailingPathDelimiter(AEzdDir) +
          LayerEzdFileName(AResult[i]);
        if AWriter.SavePoints(EzdFile,
          'Layer' + IntToStr(AResult[i].LayerNumber), Points[i], Reason) then
        begin
          AResult[i].EZDFile := EzdFile;
          Continue;
        end;
      end;
      Failed := Failed + LineEnding +
        ExtractFileName(AResult[i].MatrixFile) + ': ' + Reason;
    end;
  finally
    AWriter.Close;
  end;

  Result := Failed = '';
  if Result then
    AErrorText := ''
  else
    AErrorText := 'EZD-файлы созданы не для всех слоёв:' + Failed;
end;

function CreateSliceEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir, ASliceDir: string; const AGeometry: TMarkGeometry;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;
begin
  Result := CreateLayerEzdFiles(AWriter, ATable, AEzdDir, AGeometry, AResult,
    AErrorText);
  if not Result then
  begin
    AErrorText := AErrorText + LineEnding + LineEnding +
      'Таблица слоёв для синтеза (Slices.lays) не записана.';
    Exit;
  end;
  Result := SaveSliceStatistics(ASliceDir, AResult, SLICES_EZD_FILE,
    AErrorText) and SaveMarkGeometry(IncludeTrailingPathDelimiter(ASliceDir) +
    GEOMETRY_FILE, AGeometry, AErrorText);
end;

end.
