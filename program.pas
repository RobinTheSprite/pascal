program Hello;
var I : integer;
begin
  I := 1;
  while I < 10 do
  begin
    writeln(I);
    I := I + 1;
    if I > 5 then
      writeln(5);
  end;
end.
