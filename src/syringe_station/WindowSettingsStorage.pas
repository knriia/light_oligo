unit WindowSettingsStorage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, IniFiles;

type
  TWindowSettingsStorage = class
  private
    FFileName: string;
    FSection: string;
  public
    constructor Create(const AFileName: string = ''; const ASection: string = '');
    procedure Load(ADefaultWidth, ADefaultHeight: Integer;
      out AWidth, AHeight: Integer);
    function Save(AWidth, AHeight: Integer): Boolean;
    function LoadLastPort: string;
    function SaveLastPort(const APortName: string): Boolean;
    function LoadLastAutomationFile: string;
    function SaveLastAutomationFile(const AFileName: string): Boolean;
    property FileName: string read FFileName;
  end;

implementation

const
  WINDOW_SECTION = 'ConfigurationWindow';

constructor TWindowSettingsStorage.Create(const AFileName: string;
  const ASection: string);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    FFileName := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) +
      'syringe_pump.ini'
  else
    FFileName := AFileName;
  if Trim(ASection) = '' then
    FSection := WINDOW_SECTION
  else
    FSection := ASection;
end;

procedure TWindowSettingsStorage.Load(ADefaultWidth, ADefaultHeight: Integer;
  out AWidth, AHeight: Integer);
var
  Ini: TIniFile;
begin
  AWidth := ADefaultWidth;
  AHeight := ADefaultHeight;

  try
    if not FileExists(FFileName) then
      Exit;

    Ini := TIniFile.Create(FFileName);
    try
      AWidth := Ini.ReadInteger(FSection, 'Width', ADefaultWidth);
      AHeight := Ini.ReadInteger(FSection, 'Height', ADefaultHeight);
    finally
      Ini.Free;
    end;
  except
    AWidth := ADefaultWidth;
    AHeight := ADefaultHeight;
  end;
end;

function TWindowSettingsStorage.Save(AWidth, AHeight: Integer): Boolean;
var
  Ini: TIniFile;
  Directory: string;
begin
  Result := False;
  try
    Directory := ExtractFileDir(FFileName);
    if (Directory <> '') and not DirectoryExists(Directory) then
      ForceDirectories(Directory);

    Ini := TIniFile.Create(FFileName);
    try
      Ini.WriteInteger(FSection, 'Width', AWidth);
      Ini.WriteInteger(FSection, 'Height', AHeight);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function TWindowSettingsStorage.LoadLastPort: string;
var
  Ini: TIniFile;
begin
  Result := '';
  try
    if not FileExists(FFileName) then
      Exit;

    Ini := TIniFile.Create(FFileName);
    try
      Result := Trim(Ini.ReadString(FSection, 'LastPort', ''));
    finally
      Ini.Free;
    end;
  except
    Result := '';
  end;
end;

function TWindowSettingsStorage.SaveLastPort(const APortName: string): Boolean;
var
  Ini: TIniFile;
  Directory: string;
begin
  Result := False;
  try
    Directory := ExtractFileDir(FFileName);
    if (Directory <> '') and not DirectoryExists(Directory) then
      ForceDirectories(Directory);

    Ini := TIniFile.Create(FFileName);
    try
      Ini.WriteString(FSection, 'LastPort', Trim(APortName));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function TWindowSettingsStorage.LoadLastAutomationFile: string;
var
  Ini: TIniFile;
begin
  Result := '';
  try
    if not FileExists(FFileName) then
      Exit;

    Ini := TIniFile.Create(FFileName);
    try
      Result := Trim(Ini.ReadString(FSection, 'LastAutomationFile', ''));
    finally
      Ini.Free;
    end;
  except
    Result := '';
  end;
end;

function TWindowSettingsStorage.SaveLastAutomationFile(
  const AFileName: string): Boolean;
var
  Ini: TIniFile;
  Directory: string;
begin
  Result := False;
  try
    Directory := ExtractFileDir(FFileName);
    if (Directory <> '') and not DirectoryExists(Directory) then
      ForceDirectories(Directory);

    Ini := TIniFile.Create(FFileName);
    try
      Ini.WriteString(FSection, 'LastAutomationFile', Trim(AFileName));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

end.
