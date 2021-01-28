bison -d pascal.y
flex pascal.l
g++ pascal.tab.c lex.pascal.c -o pascal -lfl
./pascal < program.pas