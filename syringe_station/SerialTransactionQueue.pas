unit SerialTransactionQueue;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils, SerialPort;

type
  TSerialTransaction = class
  private
    FCompletedEvent: TEvent;
    FSucceeded: Boolean;
    FErrorText: string;
    procedure Complete;
  protected
    procedure Succeed;
    procedure Fail(const AErrorText: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute(APort: TSerialPort); virtual; abstract;
    function WaitForCompletion: Boolean;
    property Succeeded: Boolean read FSucceeded;
    property ErrorText: string read FErrorText;
  end;

  TSerialTransactionQueue = class
  private
    FPort: TSerialPort;
    FTransactions: TList;
    FLock: TCriticalSection;
    FAvailableEvent: TEvent;
    FWorker: TThread;
    FStopping: Boolean;
    function TakeNext(out AShouldStop: Boolean): TSerialTransaction;
  public
    constructor Create(APort: TSerialPort);
    destructor Destroy; override;
    function Execute(ATransaction: TSerialTransaction): Boolean;
    function OpenPort(const APortName: string; ABaud: Integer;
      out AErrorText: string): Boolean;
    procedure ClosePort;
    function Write(const AData: AnsiString; out AErrorText: string): Boolean;
    function Exchange(const AData: AnsiString; out AResponse: AnsiString;
      out AErrorText: string; ATimeoutMs: Cardinal = 1000): Boolean;
    procedure ScanAvailablePorts(AList: TStrings);
    function IsConnected: Boolean;
    function PortName: string;
    function LastError: string;
  end;

implementation

type
  TSerialTransactionWorker = class(TThread)
  private
    FOwner: TSerialTransactionQueue;
    FPort: TSerialPort;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TSerialTransactionQueue; APort: TSerialPort);
  end;

  TOpenPortTransaction = class(TSerialTransaction)
  public
    PortName: string;
    Baud: Integer;
    procedure Execute(APort: TSerialPort); override;
  end;

  TClosePortTransaction = class(TSerialTransaction)
  public
    procedure Execute(APort: TSerialPort); override;
  end;

  TWriteTransaction = class(TSerialTransaction)
  public
    Data: AnsiString;
    procedure Execute(APort: TSerialPort); override;
  end;

  TExchangeTransaction = class(TSerialTransaction)
  public
    Data: AnsiString;
    Response: AnsiString;
    TimeoutMs: Cardinal;
    procedure Execute(APort: TSerialPort); override;
  end;

  TScanPortsTransaction = class(TSerialTransaction)
  public
    PortList: TStrings;
    procedure Execute(APort: TSerialPort); override;
  end;

  TConnectedTransaction = class(TSerialTransaction)
  public
    Value: Boolean;
    procedure Execute(APort: TSerialPort); override;
  end;

  TPortNameTransaction = class(TSerialTransaction)
  public
    Value: string;
    procedure Execute(APort: TSerialPort); override;
  end;

  TLastErrorTransaction = class(TSerialTransaction)
  public
    Value: string;
    procedure Execute(APort: TSerialPort); override;
  end;

constructor TSerialTransaction.Create;
begin
  inherited Create;
  FCompletedEvent := TEvent.Create(nil, True, False, '');
  FSucceeded := False;
  FErrorText := '';
end;

destructor TSerialTransaction.Destroy;
begin
  FCompletedEvent.Free;
  inherited Destroy;
end;

procedure TSerialTransaction.Complete;
begin
  FCompletedEvent.SetEvent;
end;

procedure TSerialTransaction.Succeed;
begin
  FSucceeded := True;
  FErrorText := '';
end;

procedure TSerialTransaction.Fail(const AErrorText: string);
begin
  FSucceeded := False;
  FErrorText := AErrorText;
end;

function TSerialTransaction.WaitForCompletion: Boolean;
begin
  FCompletedEvent.WaitFor(High(Cardinal));
  Result := FSucceeded;
end;

constructor TSerialTransactionWorker.Create(AOwner: TSerialTransactionQueue;
  APort: TSerialPort);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FPort := APort;
  Start;
end;

procedure TSerialTransactionWorker.Execute;
var
  Transaction: TSerialTransaction;
  ShouldStop: Boolean;
begin
  repeat
    Transaction := FOwner.TakeNext(ShouldStop);
    if Transaction = nil then
    begin
      if ShouldStop then
        Exit;
      FOwner.FAvailableEvent.WaitFor(High(Cardinal));
      Continue;
    end;

    try
      Transaction.Execute(FPort);
    except
      on E: Exception do
        Transaction.Fail(E.Message);
    end;
    Transaction.Complete;
  until False;
end;

constructor TSerialTransactionQueue.Create(APort: TSerialPort);
begin
  inherited Create;
  FPort := APort;
  FTransactions := TList.Create;
  FLock := TCriticalSection.Create;
  FAvailableEvent := TEvent.Create(nil, False, False, '');
  FStopping := False;
  FWorker := TSerialTransactionWorker.Create(Self, FPort);
end;

destructor TSerialTransactionQueue.Destroy;
begin
  FLock.Acquire;
  try
    FStopping := True;
    FAvailableEvent.SetEvent;
  finally
    FLock.Release;
  end;

  FWorker.WaitFor;
  FWorker.Free;
  FAvailableEvent.Free;
  FLock.Free;
  FTransactions.Free;
  inherited Destroy;
end;

function TSerialTransactionQueue.TakeNext(
  out AShouldStop: Boolean): TSerialTransaction;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FTransactions.Count > 0 then
    begin
      Result := TSerialTransaction(FTransactions[0]);
      FTransactions.Delete(0);
      AShouldStop := False;
    end
    else
      AShouldStop := FStopping;
  finally
    FLock.Release;
  end;
end;

function TSerialTransactionQueue.Execute(
  ATransaction: TSerialTransaction): Boolean;
var
  IsQueued: Boolean;
begin
  Result := False;
  if ATransaction = nil then
    Exit;

  IsQueued := False;
  FLock.Acquire;
  try
    if not FStopping then
    begin
      FTransactions.Add(ATransaction);
      FAvailableEvent.SetEvent;
      IsQueued := True;
    end;
  finally
    FLock.Release;
  end;

  if not IsQueued then
  begin
    ATransaction.Fail('Очередь COM-порта остановлена.');
    ATransaction.Complete;
    Exit;
  end;

  Result := ATransaction.WaitForCompletion;
end;

function TSerialTransactionQueue.OpenPort(const APortName: string;
  ABaud: Integer; out AErrorText: string): Boolean;
var
  Transaction: TOpenPortTransaction;
begin
  Transaction := TOpenPortTransaction.Create;
  try
    Transaction.PortName := APortName;
    Transaction.Baud := ABaud;
    Result := Execute(Transaction);
    AErrorText := Transaction.ErrorText;
  finally
    Transaction.Free;
  end;
end;

procedure TSerialTransactionQueue.ClosePort;
var
  Transaction: TClosePortTransaction;
begin
  Transaction := TClosePortTransaction.Create;
  try
    Execute(Transaction);
  finally
    Transaction.Free;
  end;
end;

function TSerialTransactionQueue.Write(const AData: AnsiString;
  out AErrorText: string): Boolean;
var
  Transaction: TWriteTransaction;
begin
  Transaction := TWriteTransaction.Create;
  try
    Transaction.Data := AData;
    Result := Execute(Transaction);
    AErrorText := Transaction.ErrorText;
  finally
    Transaction.Free;
  end;
end;

function TSerialTransactionQueue.Exchange(const AData: AnsiString;
  out AResponse: AnsiString; out AErrorText: string;
  ATimeoutMs: Cardinal): Boolean;
var
  Transaction: TExchangeTransaction;
begin
  AResponse := '';
  Transaction := TExchangeTransaction.Create;
  try
    Transaction.Data := AData;
    Transaction.TimeoutMs := ATimeoutMs;
    Result := Execute(Transaction);
    AResponse := Transaction.Response;
    AErrorText := Transaction.ErrorText;
  finally
    Transaction.Free;
  end;
end;

procedure TSerialTransactionQueue.ScanAvailablePorts(AList: TStrings);
var
  Transaction: TScanPortsTransaction;
begin
  if AList = nil then
    Exit;
  Transaction := TScanPortsTransaction.Create;
  try
    Transaction.PortList := AList;
    Execute(Transaction);
  finally
    Transaction.Free;
  end;
end;

function TSerialTransactionQueue.IsConnected: Boolean;
var
  Transaction: TConnectedTransaction;
begin
  Transaction := TConnectedTransaction.Create;
  try
    Execute(Transaction);
    Result := Transaction.Value;
  finally
    Transaction.Free;
  end;
end;

function TSerialTransactionQueue.PortName: string;
var
  Transaction: TPortNameTransaction;
begin
  Transaction := TPortNameTransaction.Create;
  try
    Execute(Transaction);
    Result := Transaction.Value;
  finally
    Transaction.Free;
  end;
end;

function TSerialTransactionQueue.LastError: string;
var
  Transaction: TLastErrorTransaction;
begin
  Transaction := TLastErrorTransaction.Create;
  try
    Execute(Transaction);
    Result := Transaction.Value;
  finally
    Transaction.Free;
  end;
end;

procedure TOpenPortTransaction.Execute(APort: TSerialPort);
begin
  if APort.Open(PortName, Baud) then
    Succeed
  else
    Fail(APort.LastError);
end;

procedure TClosePortTransaction.Execute(APort: TSerialPort);
begin
  APort.Close;
  Succeed;
end;

procedure TWriteTransaction.Execute(APort: TSerialPort);
begin
  if APort.Write(Data) then
    Succeed
  else
    Fail(APort.LastError);
end;

procedure TExchangeTransaction.Execute(APort: TSerialPort);
begin
  APort.ClearInputBuffer;
  if not APort.Write(Data) then
  begin
    Fail(APort.LastError);
    Exit;
  end;
  if not APort.ReadResponse(Response, TimeoutMs) then
  begin
    Fail(APort.LastError);
    Exit;
  end;
  Succeed;
end;

procedure TScanPortsTransaction.Execute(APort: TSerialPort);
begin
  APort.ScanAvailablePorts(PortList);
  Succeed;
end;

procedure TConnectedTransaction.Execute(APort: TSerialPort);
begin
  Value := APort.Connected;
  Succeed;
end;

procedure TPortNameTransaction.Execute(APort: TSerialPort);
begin
  Value := APort.PortName;
  Succeed;
end;

procedure TLastErrorTransaction.Execute(APort: TSerialPort);
begin
  Value := APort.LastError;
  Succeed;
end;

end.
