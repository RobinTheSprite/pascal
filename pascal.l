%option noyywrap
%option prefix="pascal"

%{
    #include "pascal.tab.h"

    struct Symbol
    {
      char name;
      int value;
    };

    #define symbolLength 100
    int symbolEnd = 0;

    struct Symbol symbols[symbolLength];

    void findSymbol(char * symbol);

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
.                                     {printf("Uknown character %s\n", yytext);}
%%

void findSymbol(char * symbol)
{
  if (symbol[1] != 0)
  {
    return;
  }

  for (int i = 0; i < symbolEnd && i < symbolLength; ++i)
  {
    if (symbols[i].name == symbol[0])
    {
      return;
    }
  }

  symbols[symbolEnd].name = symbol[0];
  ++symbolEnd;
  return;
}