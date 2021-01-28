%option noyywrap
%option prefix="pascal"

%{
		#include <stdio.h>
    #include "pascal.tab.h"
%}

%%
program                               {return PROGRAM;}
begin                                 {return BEGIN_BLOCK;}
end                                   {return END_BLOCK;}
var                                   {return VAR;}
[a-zA-Z]+                             {pascallval.sval = yytext; return IDENTIFIER;}
[0-9]+                                {pascallval.ival = atoi(yytext); return NUM;}
"."                                   {return PERIOD;}
":="                                  {return ASSIGN;}
";"                                   {return SEMICOLON;}
"("                                   {return LEFT_PAREN;}
")"                                   {return RIGHT_PAREN;}
","                                   {return COMMA;}
">"                                   {return GREATER_THAN;}
"<"                                   {return LESS_THAN;}
[ \t\n]                               {}
.                                     {printf("Unknown character %c\n", *yytext);}
%%
