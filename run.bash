bison -d pascal.y -o pascal.tab.cpp --defines=pascal.tab.hpp
flex -o lex.pascal.cpp pascal.l
g++ -Wall -std=c++11 pascal.tab.cpp lex.pascal.cpp -o pascal -lfl
./pascal < program.pas