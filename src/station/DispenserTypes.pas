unit DispenserTypes;

{$mode objfpc}{$H+}

interface

type
  TDispenserOperationKind = (dokFill, dokEmpty, dokAspirate, dokDispense);
  TDispenserOperationOwner = (dooNone, dooManual, dooProtocol);
  TDispenserValveType = (dvtUnknown, dvtDistributive, dvtNonDistributive);

implementation

end.
