%option noyywrap
%option prefix="pascal"

%{
    #include <iostream>
    #include <string>
    #include <vector>

    #include "pascal.tab.hpp"

    struct Symbol
    {
      char name;
      int value;
    };

    int symbolEnd = 0;

    std::vector<Symbol> symbols;

    void findSymbol(std::string symbol);

%}

%%
program                               {return PROGRAM;}
begin                                 {return BEGIN_BLOCK;}
end                                   {return END_BLOCK;}
var                                   {return VAR;}
integer                               {return INTEGER;}
if                                    {return IF;}
then                                  {return THEN;}
else                                  {return ELSE;}
while                                 {return WHILE;}
do                                    {return DO;}
[a-zA-Z]+                             {findSymbol(yytext); pascallval.sval = yytext; return IDENTIFIER;}
[0-9]+                                {pascallval.ival = atoi(yytext); return NUM;}
"."                                   {return PERIOD;}
":="                                  {return ASSIGN;}
"*"                                   {return MULT;}
"/"                                   {return DIV;}
"+"                                   {return PLUS;}
"-"                                   {return MINUS;}
";"                                   {return SEMICOLON;}
":"                                   {return COLON;}
"("                                   {return LEFT_PAREN;}
")"                                   {return RIGHT_PAREN;}
","                                   {return COMMA;}
">"                                   {return GREATER_THAN;}
"<"                                   {return LESS_THAN;}
[ \t\n]                               {}
.                                     {std::cout << "Uknown character " << yytext << std::endl;}
%%

void findSymbol(std::string symbol)
{
  if (symbol.size() > 1)
  {
    return;
  }

  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol[0])
    {
      return;
    }
  }

  symbols.push_back({symbol[0], 0});
  return;
}