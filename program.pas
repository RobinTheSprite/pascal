program Hello;
var n, p, t, i : integer;
begin
  n := 10;
  p := 3;
  t := 1;
  if t > 0 then
  begin
    i := p;
    while i < n do
    begin
      i := i + p;
      writeln(i);
    end;
  end;
end.
