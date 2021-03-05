program Hello;
var n, p, t, i : integer;
begin
  n := 10;
  p := 3;
  t := 1;
  if t > 0 then
  begin
    i := p + p;
    while i < n do
    begin
      if i > 6 then
      begin
        writeln(i);
      end;
      i := i + p;
    end;
  end;
end.
