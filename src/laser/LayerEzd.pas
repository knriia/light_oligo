unit LayerEzd;
// EZD-файлы слоёв: по матрице каждого слоя - точки маркировки - EZD-файл.
// Сама запись EZD идёт через TEzdWriter, чтобы логику можно было проверить
// без MarkEzd.dll.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, MatrixTypes, MarkGeometry, OligoSlices, LaserPen;

type
  // Запись EZD-файлов. Open - один раз перед записью, Close - после.
  // Параметры пера записываются в каждый файл: с ними пойдёт маркировка.
  TEzdWriter = class
  public
    function Open(out AErrorText: string): Boolean; virtual; abstract;
    function SavePoints(const AEzdFile, AEntityName: string;
      const APoints: TArrOfTPoint; const APen: TLaserPen;
      out AErrorText: string): Boolean; virtual; abstract;
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
  const AEzdDir: string; const AGeometry: TMarkGeometry; const APen: TLaserPen;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;

// EZD целиком: EZD-файлы всех слоёв в AEzdDir, а в ASliceDir - таблица
// Slices.lays и параметры, с которыми созданы EZD: геометрия (geometry.ini)
// и перо лазера (laser.ini). Пути к EZD в Slices.lays - относительно
// ASliceDir. Всё это пишется, только если созданы EZD всех слоёв.
function CreateSliceEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir, ASliceDir: string; const AGeometry: TMarkGeometry;
  const APen: TLaserPen;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;

implementation

uses
  OligoMatrix;

function LayerEzdFileName(const ALayer: TSliceLayer): string;
begin
  Result := ChangeFileExt(ExtractFileName(ALayer.MatrixFile), '.ezd');
end;

function CreateLayerEzdFiles(AWriter: TEzdWriter; const ATable: TSliceLayers;
  const AEzdDir: string; const AGeometry: TMarkGeometry; const APen: TLaserPen;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;
var
  i: Integer;
  Matrix: TMatrix;
  Points: array of TArrOfTPoint;
  Reasons: array of string;
  EzdFile, Reason, Failed, FitError: string;
  AllPoints: TArrOfTPoint;
  n, k: Integer;
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
  AllPoints := nil;
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
        // точки всех слоёв вместе - это весь массив на подложке
        n := Length(AllPoints);
        SetLength(AllPoints, n + Length(Points[i]));
        for k := 0 to High(Points[i]) do
          AllPoints[n + k] := Points[i][k];
      end;
    end;
  end;
  if not CheckArrayFitsSubstrate(AllPoints, AGeometry, FitError) then
  begin
    AErrorText := 'EZD-файлы не созданы: ' + FitError;
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
          'Layer' + IntToStr(AResult[i].LayerNumber), Points[i], APen, Reason) then
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
  const APen: TLaserPen;
  out AResult: TSliceLayers; out AErrorText: string): Boolean;
begin
  Result := CreateLayerEzdFiles(AWriter, ATable, AEzdDir, AGeometry, APen,
    AResult, AErrorText);
  if not Result then
  begin
    AErrorText := AErrorText + LineEnding + LineEnding +
      'Таблица слоёв для синтеза (Slices.lays) не записана.';
    Exit;
  end;
  Result := SaveSliceStatistics(ASliceDir, AResult, SLICES_EZD_FILE,
    AErrorText) and SaveMarkGeometry(IncludeTrailingPathDelimiter(ASliceDir) +
    GEOMETRY_FILE, AGeometry, AErrorText) and
    SaveLaserPen(IncludeTrailingPathDelimiter(ASliceDir) + LASER_PEN_FILE,
    APen, AErrorText);
end;

end.
