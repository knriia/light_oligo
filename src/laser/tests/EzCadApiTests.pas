unit EzCadApiTests;
// Объявления функций MarkEzd.dll должны совпадать с DLL по соглашению о
// вызовах: после вызова указатель стека должен вернуться на место.
// DLL использует cdecl; с stdcall стек после каждого вызова сдвигался.

{$mode objfpc}{$H+}
{$asmmode intel}
{$codepage utf8}

interface

uses
  Windows, Classes, SysUtils, fpcunit, testregistry, EzCadApi;

type
  // При подключении DLL может показать окно с заголовком - полным путём
  // к exe; его, как и программа, закрывает фоновый поток.
  TDllMessageCloser = class(TThread)
  protected
    procedure Execute; override;
  end;

  TEzCadApiTests = class(TTestCase)
  published
    procedure LoadEzdFileKeepsStack;
    procedure SaveEntLibToFileKeepsStack;
    procedure InitialAndCloseKeepStack;
  end;

implementation

const
  MISSING_FILE = 'C:\light_oligo_no_such_dir\x.ezd';

procedure TDllMessageCloser.Execute;
var
  Title: string;
  Wnd: HWND;
begin
  Title := ParamStr(0);
  while not Terminated do
  begin
    Wnd := FindWindow(nil, PChar(Title));
    if Wnd <> 0 then
      PostMessage(Wnd, WM_CLOSE, 0, 0);
    Sleep(50);
  end;
end;

function StackPointer: PtrUInt; assembler; nostackframe;
// указатель стека в месте вызова (без адреса возврата)
asm
  lea eax, [esp + 4]
end;

procedure TEzCadApiTests.LoadEzdFileKeepsStack;
var
  FileName: WideString;
  Before, After: PtrUInt;
begin
  FileName := MISSING_FILE;
  Before := StackPointer;
  lmc1_LoadEzdFile(FileName);
  After := StackPointer;
  AssertEquals('сдвиг стека', 0, PtrInt(Before) - PtrInt(After));
end;

procedure TEzCadApiTests.SaveEntLibToFileKeepsStack;
var
  FileName: WideString;
  Before, After: PtrUInt;
begin
  FileName := MISSING_FILE;
  Before := StackPointer;
  lmc1_SaveEntLibToFile(FileName);
  After := StackPointer;
  AssertEquals('сдвиг стека', 0, PtrInt(Before) - PtrInt(After));
end;

procedure TEzCadApiTests.InitialAndCloseKeepStack;
var
  Dir: WideString;
  Before, After: PtrUInt;
  Closer: TDllMessageCloser;
begin
  Dir := WideString(ExtractFilePath(ParamStr(0)));
  Closer := TDllMessageCloser.Create(False);
  try
    Before := StackPointer;
    lmc1_Initial2(Dir, True, 0);
    After := StackPointer;
    lmc1_Close;
  finally
    Closer.Terminate;
    Closer.WaitFor;
    Closer.Free;
  end;
  AssertEquals('сдвиг стека', 0, PtrInt(Before) - PtrInt(After));
end;

initialization
  RegisterTest(TEzCadApiTests);

end.
