program Hello;
var I, J : integer;
begin
  I := 1;

  if I > 0 then
  begin
    I := 4;
    if I > 3 then
      J := 4;
  end
  else
    I := 6;

  writeln(I);
end.
