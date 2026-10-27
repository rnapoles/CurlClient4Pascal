{ Http.Defines.inc - common compiler settings for Delphi 12+ and FPC 3.2.2+ }
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
{$IFDEF FPC}
  {$MODESWITCH UNICODESTRINGS}  // make "string" = UnicodeString, like Delphi
{$ENDIF}
{$IFDEF FPC}
  {$WARN 4104 OFF} // implicit string conversion (RTL Exception/Format take AnsiString)
  {$WARN 4105 OFF}
  {$WARN 5093 OFF} // function result not initialized (dynamic arrays)
{$ENDIF}
